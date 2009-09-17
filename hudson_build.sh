#!/bin/bash
export LANG=C
PN="$(basename "${0}")"

function usage() {
	cat <<EOF
Usage: ${PN} [Options] <Build Type> [Archive file1] [Archive file2]...

Options:
  -h        : Show this help message
  -d <DIR>  : Set working directory

Build Type:
  qt4       : Qt Version 4
  qtgenmake : Qt generate project file automatically
EOF
	if [ $# -gt 0 ] ; then
		echo
		die "$@"
	else
		exit 0
	fi
}

function die() {
	echo "$@" >&2
	exit 1
}

function checknecprog() {
	local i
	for i in "$@" ; do
		[ "$(type -t "${i}")" ] || die "Necessary program '${i}' no found"
	done
}

checknecprog qmake make 7z

(($# == 0)) && usage "Invalid parameters"
opt="$(getopt -o hd: -- "$@")"
(($? != 0)) && usage "Parse options failed"

eval set -- "${opt}"
while true ; do
	case "${1}" in
	-h) usage ; shift ;;
	-d) proj_dir="$(readlink -f "${2}")" ; shift 2 ;;
	--) shift ; break ;;
	*) echo "Internal error!" ; exit 1 ;;
	esac
done

build_type="${1}" ; shift
true ${proj_dir:=${PWD}}
true ${JOB_NAME:=$(basename "${proj_dir}")}
if [ -z "${BUILD_NUMBER}" ] ; then
	BUILD_NUMBER=0
	while [ -f "${JOB_NAME}-${BUILD_NUMBER}.7z" ] \
		|| [ -d "tmp/${JOB_NAME}-${BUILD_NUMBER}" ] ; do
		true $((BUILD_NUMBER++))
	done
fi
proj_tar="${JOB_NAME}-${BUILD_NUMBER}"

pushd "${proj_dir}" &>/dev/null || exit 1
case "${build_type}" in
qt4)
	qmake && make debug && make release || exit 1
	;;
qtgenmake)
	qmake -project || exit 1
	proj_file="$(basename "${PWD}").pro"
	[ ! -f "${proj_file}" ] && \
		proj_file="$(ls -1 *.pro 2>/dev/null | head -n 1)"
	[ ! -f "${proj_file}" ] && die "no project file found"
	echo "CONFIG *= debug_and_release" >>"${proj_file}"
	qmake -Wall && make debug && make release || exit 1
	;;
*)
	usage "Build Type not support ('${build_type}')"
	;;
esac
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

