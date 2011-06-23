#!/bin/bash
export LANG=C
PN="${BASH_SOURCE[0]##*/}"
PD="${BASH_SOURCE[0]%/*}"

source "${PD}/lib/env_ccache"
source "${PD}/lib/common"

function usage() {
	cat <<EOF
Usage: ${PN} [Options] <Build Type> [Archive file1] [Archive file2]...

Options:
  -h       : Show this help message
  -d <DIR> : Set working directory
  -r       : Rebuild project
  --debug  : Build only debug mode (ignore release mode)

Options for ant: (*: means the option can set more than once)
  -f <FILE>     : Ant build XML file
  -t <TAGRET>  *: Build target

Options for qtgenmake: (*: means the option can set more than once)
  -P            : Only generate .pro file
  -i <FILE>    *: Include other .pri in project file
  -D <DEFINE>  *: Append other defines to project
  --compiler-prefix <PREFIX>
                : Set compiler prefix, useful for cross compile
  --static      : Build with static link
  --lib         : Build project as library
  --lib32       : Link Library Path /usr/lib32 instead of /usr/lib
  --pch <FILE>  : Set pre-compile header for project

Build Type:
  ant       : Apache Ant
  qt4       : Qt Version 4
  qtgenmake : Qt generate project file automatically
EOF
	[ $# -gt 0 ] && { echo ; die "$@" ; } || exit 0
}

neccmd getopt cat sed make 7z

(($# == 0)) && usage "Invalid parameters"
opt="$(getopt -o hd:rPi:D:t:f: -l compiler-prefix: -l static -l debug -l lib -l lib32 -l pch: -- "$@")"
(($? != 0)) && usage "Parse options failed"

eval set -- "${opt}"
while true ; do
	case "${1}" in
	-h) usage ; shift ;;
	-d) proj_dir="$(readlink -f "${2}")" ; shift 2 ;;
	-r) rebuild=1 ; shift ;;
	-P) buildproj=1 ; shift ;;
	-i) buildinc=("${buildinc[@]}" "${2}") ; shift 2 ;;
	-D) builddef=("${builddef[@]}" "${2}") ; shift 2 ;;
	-f) ant_xml="${2}" ; shift 2 ;;
	-t) ant_target=("${ant_target[@]}" "${2}") ; shift 2 ;;
	--debug) debug=1 ; shift ;;
	--compiler-prefix) comprefix="${2}" ; shift 2 ;;
	--static) buildstatic=1 ; linkopt="${linkopt} -static" ; shift ;;
	--lib) buildlib=1 ; shift ;;
	--lib32) buildlib32=1 ; shift ;;
	--pch) buildpch="${2}" ; shift 2 ;;
	--) shift ; break ;;
	*) echo "Internal error!" ; exit 1 ;;
	esac
done

build_type="${1}" ; shift
true ${proj_dir:=${PWD}}
true ${JOB_NAME:=${proj_dir##*/}}
if [ -z "${BUILD_NUMBER}" ] ; then
	BUILD_NUMBER=0
	while [ -f "${JOB_NAME}-${BUILD_NUMBER}.7z" ] \
		|| [ -d "tmp/${JOB_NAME}-${BUILD_NUMBER}" ] ; do
		true $((BUILD_NUMBER++))
	done
fi
proj_tar="${JOB_NAME}-${BUILD_NUMBER}"

pushd "${proj_dir}" &>/dev/null || exit 1
while true ; do
	case "${build_type}" in
	ant)
		neccmd ant
		cp -f "${PD}/conf/hudson_tomcat.xml" ./
		if [ -f "${PD}/conf/hudson_tomcat.conf" ] ; then
			source "${PD}/conf/hudson_tomcat.conf"
		fi
		true ${ant_xml:=build.xml}
		if [ -z "$(grep -i "<import file=\"hudson_tomcat.xml\"/>" "${ant_xml}")" ] ; then
			sed -i 's|</project>|\n\t<import file="hudson_tomcat.xml"/>\n</project>|i' "${ant_xml}"
		fi
		ant -f "${ant_xml}" ${ant_target[@]}
		;;
	qt4)
		neccmd qmake g++
		qmake -Wall || exit 1
		make qmake || exit 1
		[ "${rebuild}" == "1" ] && make clean
		make debug || exit 1
		if [ "${debug}" != "1" ] ; then
			make release || exit 1
		fi
		;;
	qtgenmake)
		neccmd qmake g++
		qmake -project || exit 1
		proj_file="${PWD##*/}.pro"
		[ ! -f "${proj_file}" ] && \
			proj_file="$(ls -1 *.pro 2>/dev/null | head -n 1)"
		[ ! -f "${proj_file}" ] && die "no project file found"
		proj_name="${proj_file%.pro}"
		for i in "${buildinc[@]}" ; do
			echo "include(${i})" >> "${proj_file}"
		done
		for i in "${builddef[@]}" ; do
			echo "DEFINES *= ${i}" >> "${proj_file}"
		done
		if [ "${buildlib}" == "1" ] ; then
			echo "TEMPLATE = lib" >> "${proj_file}"
			if [ "${buildstatic}" == "1" ] ; then
				echo "CONFIG *= staticlib" >> "${proj_file}"
			else
				echo "CONFIG *= dll" >> "${proj_file}"
			fi
		fi
		if [ "${comprefix}" ] ; then
			echo "OS *= ${comprefix%%-}" >> "${proj_file}"
		fi
		if [ "${buildpch}" ] ; then
			echo "PRECOMPILED_HEADER *= ${buildpch}" >> "${proj_file}"
		fi
		cat >> "${proj_file}" <<EOF
QT -= core gui

isEmpty(OS) {
	win32	{ OS = win32 }
	unix	{ OS = unix  }
	mac		{ OS = mac   }
	isEmpty(OS) { OS = unknown }
}

unix {
	QMAKE_CFLAGS *= -fsigned-char
	QMAKE_CXXFLAGS *= -fsigned-char
}
QMAKE_LFLAGS *= ${linkopt}

CONFIG *= debug_and_release warn_on
CONFIG(debug, debug|release) {
	TARGET		= ${proj_name}d
	BUILD		= debug
	CONFIG		*= debug
	CONFIG		-= release
	DEFINES		*= DEBUG
	DEFINES		-= NDEBUG
	DEFINES		-= QT_NO_DEBUG_OUTPUT
} else {
	TARGET		= ${proj_name}
	BUILD		= release
	CONFIG		-= debug
	CONFIG		*= release
	DEFINES		-= DEBUG
	DEFINES		*= NDEBUG
	DEFINES		*= QT_NO_DEBUG_OUTPUT
}

isEmpty(OBJECTS_DIR)    { OBJECTS_DIR   = tmp/\$\${OS}/\$\${BUILD} }
isEmpty(MOC_DIR)        { MOC_DIR       = tmp/\$\${OS}/\$\${BUILD} }
isEmpty(RCC_DIR)        { RCC_DIR       = tmp/\$\${OS}/\$\${BUILD} }
isEmpty(DESTDIR)		{ DESTDIR		= tmp/\$\${OS} }
message(\$\$_PRO_FILE_)
EOF
		[ "${buildproj}" == "1" ] && break
		qmake -Wall || exit 1
		make qmake || exit 1
		if [ "${comprefix}" ] ; then
			sed -i -r "
				s|^(CC\s*=\s)(.*)$|\1${comprefix}\2|;
				s|^(CXX\s*=\s)(.*)$|\1${comprefix}\2|;
				s|^(LINK\s*=\s)(.*)$|\1${comprefix}\2|;
				s|^(AR\s*=\s)(.*)$|\1${comprefix}\2|;
			" Makefile.Debug
			sed -i -r "
				s|^(CC\s*=\s)(.*)$|\1${comprefix}\2|;
				s|^(CXX\s*=\s)(.*)$|\1${comprefix}\2|;
				s|^(LINK\s*=\s)(.*)$|\1${comprefix}\2|;
				s|^(AR\s*=\s)(.*)$|\1${comprefix}\2|;
			" Makefile.Release
		fi
		if [ "${buildlib32}" == "1" ] ; then
			[ ! -d "/usr/lib32" ] && die "Force link lib32 but not exists /usr/lib32"
			sed -i -r "
				s|/usr/lib|/usr/lib32|;
			" Makefile.Debug
			sed -i -r "
				s|/usr/lib|/usr/lib32|;
			" Makefile.Release
		fi
		[ "${rebuild}" == "1" ] && make clean
		make debug || exit 1
		if [ "${debug}" != "1" ] ; then
			make release || exit 1
		fi
		;;
	*)
		usage "Build Type not support ('${build_type}')"
		;;
	esac
	break
done
popd &>/dev/null

if [ $# -gt 0 ] ; then
	mkdir -p "tmp/${proj_tar}/"
	for i in "$@" ; do
		cp -a "${i}" "tmp/${proj_tar}/" || exit 1
	done

	pushd "tmp" &>/dev/null || exit 1
	7z a -m0=lzma -mx=9 -mfb=273 -md=32m "../${proj_tar}.7z" "${proj_tar}"
	popd &>/dev/null
fi

