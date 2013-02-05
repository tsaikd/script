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
  -h          : Show this help message
  -b <BRANCH> : Set branch name

Current Config:
  hudson_url: '${hudson_url}'
EOF
	[ $# -gt 0 ] && { echo ; die "$@" ; } || exit 0
}

type getopt cat wget >/dev/null || exit $?

(($# < 2)) && usage "Invalid parameters"
opt="$(getopt -o hb: -- "$@")"
(($? != 0)) && usage "Parse options failed"

eval set -- "${opt}"
while true ; do
	case "${1}" in
	-h) usage ; shift ;;
	-b) proj_branch="${2}" ; shift 2 ;;
	--) shift ; break ;;
	*) echo "Internal error!" ; exit 1 ;;
	esac
done

proj_name="${1}" ; shift
token="${1}" ; shift

if [ "${proj_branch}" ] ; then
	branch="$(git rev-parse "${proj_branch}")"
	opt_rev="&GIT_BUILD_BRANCH=${branch}"
	info_rev=" branch (${branch})"
	build_path="/buildWithParameters"
else
	branch=""
	opt_rev=""
	info_rev=""
	build_path="/build"
fi

wget -q -O /dev/null \
	"${hudson_url}/job/${proj_name}/${build_path}" \
	--post-data="token=${token}${opt_rev}"

page="$(wget -q -O - "${hudson_url}/job/${proj_name}/")"
num="$(grep -Eo -m 1 "#[1-9]+[0-9]*" <<<"${page}")"
if [ "${num}" ] ; then
	echo "trigger hudson project (${proj_name}) build (${num})${info_rev}"
fi

