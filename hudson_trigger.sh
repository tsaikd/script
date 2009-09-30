#!/bin/bash
export LANG=C
PN="$(basename "${0}")"
PD="$(readlink -f "${0}")" && PD="${PD%/*}"

function usage() {
	cat <<EOF
Usage: ${PN} [Options] <Project Name> <Token>

Options:
  -h        : Show this help message
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

checknecprog wget

(($# != 2)) && usage "Invalid parameters"
opt="$(getopt -o h -- "$@")"
(($? != 0)) && usage "Parse options failed"

eval set -- "${opt}"
while true ; do
	case "${1}" in
	-h) usage ; shift ;;
	--) shift ; break ;;
	*) echo "Internal error!" ; exit 1 ;;
	esac
done

source "${PD}/conf/hudson_trigger.conf"

[ -z "${hudson_url}" ] && die "Please set \$hudson_url in ${PD}/conf/hudson_trigger.conf"

proj_name="${1}" ; shift
token="${1}" ; shift

wget -q -O /dev/null \
	"${hudson_url}/job/${proj_name}/build" \
	--post-data="token=${token}"


