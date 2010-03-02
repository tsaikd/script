#!/bin/bash

PN="${BASH_SOURCE[0]##*/}"
PD="${BASH_SOURCE[0]%/*}"

[ -r "${PD}/conf/${PN%.sh}.conf" ] && source "${PD}/conf/${PN%.sh}.conf"
source "${PD}/lib/die"

function usage() {
	cat <<EOF
Usage: ${PN} [Options]
  -h       : show this help message
EOF
	[ $# -gt 0 ] && { echo ; die "$@" ; } || exit 0
}

type getopt cat ping >/dev/null || exit $?

opt="$(getopt -o h -- "$@")" || usage "Parse options failed"

eval set -- "${opt}"
while true ; do
	case "${1}" in
	-h) usage ; shift ;;
	--) shift ; break ;;
	*) echo "Internal error!" ; exit 1 ;;
	esac
done

(($# > 0)) && usage "Invalid parameters"

[ "$(id -u)" -ne 0 ] && die "Please use root to run this script"

try=10

while ((try-- > 0)) ; do
	ping -c 1 -s 0 -w 5 168.95.1.1 >/dev/null 2>&1
	[ $? -eq 0 ] && exit 0
done

if [ -x "/etc/init.d/networking" ] ; then
	/etc/init.d/networking restart
else
	die "Not support OS for restart network"
fi

