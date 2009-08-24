#!/bin/bash

PN="$(basename "${0}")"
function usage() {
	cat <<EOF
Usage: ${PN} <vnc port>
EOF
	if [ $# -gt 0 ] ; then
		echo
		echo "$@"
		exit 1
	else
		exit
	fi
}

vncstat="1"
function check_vncstat() {
	vncstat="${1}"
	case "${vncstat}" in
#	0) echo "vnc is running" >&2 ;;
	1) echo "vnc status unknown" >&2 ;;
	2) echo "vnc port (${vncport}) is running by others" >&2 ;;
	3) echo "vnc not running on the port in this machine" >&2 ;;
	esac
	if [ "${vncstat}" -eq 3 ] ; then
		vncserver ":${vncport}"
	fi
	exit "${vncstat}"
}

vncport="${1}" && shift
[ -z "${vncport}" ] && usage "vnc port not yet set"

user="$(id -un)"
eval home="~${user}"
vncdir="${home}/.vnc"

vncpid="$(netstat -tlnp 2>&1 | grep ":${vncport} " | awk '{print $7}' | awk -F '/' '{print $1}')"
[ -z "${vncpid}" ] && check_vncstat "3"

[ ! -d "${vncdir}" ] && check_vncstat "2"
pushd "${vncdir}" &>/dev/null

vncpfile="$(grep -l "${vncpid}" *.pid 2>/dev/null)"
[ -z "${vncpfile}" ] && check_vncstat "2"

popd &>/dev/null

