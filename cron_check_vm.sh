#!/bin/bash

PN="${BASH_SOURCE[0]##*/}"
PD="${BASH_SOURCE[0]%/*}"

[ -r "${PD}/conf/${PN%.sh}.conf" ] && source "${PD}/conf/${PN%.sh}.conf"
source "${PD}/lib/die"

function usage() {
	cat <<EOF
Usage: ${PN} [Options] <VM UUID>
  -h       : show this help message
  -l       : list all vms
  -r       : list running vms
EOF
	[ $# -gt 0 ] && { echo ; die "$@" ; } || exit 0
}

type getopt cat VBoxManage >/dev/null || exit $?

(($# == 0)) && usage "Invalid parameters"
opt="$(getopt -o hlr -- "$@")" || usage "Parse options failed"

eval set -- "${opt}"
while true ; do
	case "${1}" in
	-h) usage ; shift ;;
	-l) listvms=1 ; shift ;;
	-r) listrvms=1 ; shift ;;
	--) shift ; break ;;
	*) echo "Internal error!" ; exit 1 ;;
	esac
done

if [ "${listvms}" == 1 ] ; then
	VBoxManage list vms
	exit $?
fi

if [ "${listrvms}" == 1 ] ; then
	VBoxManage list runningvms
	exit $?
fi

(($# < 1)) && usage "Invalid parameters"

for vmuuid in "$@" ; do
	msg="$(VBoxManage list vms | grep "${vmuuid}")"
	[ -z "${msg}" ] && die "vm not exists (${vmuuid})"

	msg="$(VBoxManage list runningvms | grep "${vmuuid}")"
	if [ -z "${msg}" ] ; then
		echo "vm not running in this machine ('${vmuuid}')" >&2
		VBoxManage startvm "${vmuuid}"
		sleep 5
	fi
done

