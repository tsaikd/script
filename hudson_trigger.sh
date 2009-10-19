#!/bin/bash
export LANG=C
PN="${BASH_SOURCE[0]##*/}"
PD="${BASH_SOURCE[0]%/*}"

source "${PD}/lib/die"
source "${PD}/conf/hudson_trigger.conf"

[ "${hudson_url}" ] || die "Please set \$hudson_url in ${PD}/conf/hudson_trigger.conf"

function usage() {
	cat <<EOF
Usage: ${PN} [Options] <Project Name> <Token>

Options:
  -h        : Show this help message

Current Config:
  hudson_url: '${hudson_url}'
EOF
	[ $# -gt 0 ] && { echo ; die "$@" ; } || exit 0
}

type getopt cat wget >/dev/null || exit $?

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

proj_name="${1}" ; shift
token="${1}" ; shift

wget -q -O /dev/null \
	"${hudson_url}/job/${proj_name}/build" \
	--post-data="token=${token}"

