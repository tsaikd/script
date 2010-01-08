#!/bin/bash
#=====================================================================
# usable function
#---------------------------------------------------------------------
# kdtmpfile
# kdtmpremove
#=====================================================================
# global variable
#---------------------------------------------------------------------
# KDTMP_NUM
# KDTMP_FILES[]
#=====================================================================

if ! type kdtmpfile >/dev/null 2>&1 ; then

export KDTMP_NUM=0
unset KDTMP_FILES

# if $1 then set temp file path to variable $1
# else show a temp file path to stdout
#
# note:
#   first mode will save temp file path in KDTMP_FILES
#
# options:
#   -d set temp directory
#   -p set prefix of tempfile instead of auto detect
#   -s set suffix of tempfile instead of 'tmp'
#   -m set mode instead of 0600
#   -n do not create tempfile automatically
function kdtmpfile() {
	local tmpdir="${TMPDIR:-/tmp}"
	local prefix="${BASH_SOURCE[1]##*/}"
	local suffix="tmp"
	local mode="0600"
	local create="1"
	local j=${KDTMP_NUM}

	local i="$(getopt -s bash "d:p:s:m:n" "$@")" || exit 1
	eval set -- "${i}"
	for i ; do
		case ${i} in
		--) shift && break ;;
		-d) tmpdir="${2}" && shift 2 ;;
		-p) prefix="${2}" && shift 2 ;;
		-s) suffix="${2}" && shift 2 ;;
		-m) mode="${2}" && shift 2 ;;
		-n) create="0" && shift ;;
		esac
	done

	i="${tmpdir}/${prefix}.$$.${j}.${suffix}"
	while [ -e "${i}" ] ; do
		((j++))
		i="${tmpdir}/${prefix}.$$.${j}.${suffix}"
	done

	if ((create==1)) ; then
		touch "${i}"
		chmod "${mode}" "${i}"
	fi

	if [ "${1}" ] ; then
		eval ${1}=\"${i}\"
		KDTMP_FILES[$((KDTMP_NUM++))]="${i}"
	else
		echo "${i}"
	fi
}

# remove all created tmp files
# return 0 if remove some files success
# return 1 if no file need to remove
# return 2 if remove some files failed
function kdtmpremove() {
	local i
	local ret=1

	for ((i=0 ; i<KDTMP_NUM ; i++)) ; do
		((ret == 1)) && ret=0
		if [ -f "${KDTMP_FILES[${i}]}" ] ; then
			rm -f "${KDTMP_FILES[${i}]}" || ret=2
		fi
	done

	KDTMP_NUM=0
	unset KDTMP_FILES
	return ${ret}
}


fi # ! type kdtmpfile

