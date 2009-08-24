#!/bin/bash

PN="$(basename "${0}")"
function usage() {
	cat <<EOF
Usage: ${PN} <UUID>
EOF
	if [ $# -gt 0 ] ; then
		echo
		echo "$@"
		exit 1
	else
		exit
	fi
}

vmstat="1"
function check_vmstat() {
	vmstat="${1}"
	case "${vmstat}" in
#	0) echo "vm is running" >&2 ;;
	1) echo "vm status unknown" >&2 ;;
	2) echo "vm not exists (${vmuuid})" >&2 ;;
	3) echo "vm not running in this machine" >&2 ;;
	esac
	if [ "${vmstat}" -eq 3 ] ; then
		VBoxManage startvm "${vmuuid}"
	fi
	exit "${vmstat}"
}

vmuuid="${1}" && shift
[ -z "${vmuuid}" ] && usage "VM UUID not yet set"

msg="$(VBoxManage list vms | grep "${vmuuid}")"
[ -z "${msg}" ] && check_vmstat "2"

msg="$(VBoxManage list runningvms | grep "${vmuuid}")"
[ -z "${msg}" ] && check_vmstat "3"

