#!/bin/bash

PN="${BASH_SOURCE[0]##*/}"
PD="${BASH_SOURCE[0]%/*}"

source "${PD}/../lib/die"

limit="90"
check_path="/var/log"

function usage() {
	cat <<EOF
Usage: ${PN} [Options] <PATH#prefix%suffix> [<PATH> ...]
  -h           : show this help message
  -p <NUM>     : limit <NUM> percentage of disk usage, default: ${limit}
  -f <PATH>    : check <PATH> disk usage with 'df' command, default: ${check_path}
  -t           : test mode, show file path instead of remove

remove one file in <PATH> if disk usage too high
EOF
	[ $# -gt 0 ] && { echo ; die "$@" ; } || exit 0
}

type getopt ls df >/dev/null || exit $?

opt="$(getopt -o hp:f:t -- "$@")" || usage "Parse options failed"

eval set -- "${opt}"
while true ; do
	case "${1}" in
	-h) usage ; shift ;;
	-p) limit="${2}" ; shift 2 ;;
	-f) check_path="${2}" ; shift 2 ;;
	-t) testmode="1" ; shift ;;
	--) shift ; break ;;
	*) echo "Internal error!" ; exit 1 ;;
	esac
done

(($# < 1)) && usage "Invalid parameters"

[ "$(id -u)" -ne 0 ] && die "Please use root to run this script"

curper="$(df "${check_path}" | tail -n 1 | awk '{print $5}')"
cur="${curper%%%}"
if [ "${curper}" != "${cur}" ] && [ "${cur}" -ge "${limit}" ] ; then
	for i in $@ ; do
		prefix="$(sed -n '/#/ s/^.*#\([^%]\+\).*$/\1/p' <<<"${i}")"
		suffix="$(sed -n '/%/ s/^.*%\([^#]\+\).*$/\1/p' <<<"${i}")"
		path="$(sed 's/[#%].*$//' <<<"${i}")"
		file="$(ls -1t ${path}${prefix}*${suffix} | tail -n 1)"
		if [ "${testmode}" ] ; then
			echo "${file}"
		else
			rm -f "${file}"
		fi
	done
fi

