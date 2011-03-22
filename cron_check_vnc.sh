#!/bin/bash

PN="${BASH_SOURCE[0]##*/}"
PD="${BASH_SOURCE[0]%/*}"

source "${PD}/lib/die"

function usage() {
	cat <<EOF
Usage: ${PN} [Options] <vnc port> :<vnc display> [--] [vncserver options]
  -h       : show this help message

Example:
  cron_check_vnc.sh 5901 :1 -- -geometry 1280x1024
EOF
	[ $# -gt 0 ] && { echo ; die "$@" ; } || exit 0
}

type getopt cat awk cut vncserver >/dev/null || exit $?

(($# == 0)) && usage "Invalid parameters"
opt="$(getopt -o h -- "$@")" || usage "Parse options failed"

eval set -- "${opt}"
while true ; do
	case "${1}" in
	-h) usage ; shift ;;
	--) shift ; break ;;
	*) echo "Internal error!" ; exit 1 ;;
	esac
done

(($# < 2)) && usage "Invalid parameters"

[ -z "${HOME}" ] && die "env 'HOME' not yet set"

if [ -z "${USER}" ] ; then
	type whoami && export USER="$(whoami)"
fi

vncport="${1}" && shift
[ -z "${vncport}" ] && usage "vnc port not yet set"

vncdisplay="${1}" && shift
[ -z "${vncdisplay}" ] && usage "vnc display not yet set"

vncdir="${HOME}/.vnc"
[ ! -d "${vncdir}" ] && die "vnc dir not found ('${vncdir}')"

vncpid="$(netstat -tlnp 2>&1 | grep ":${vncport}\\>" | awk '{print $7}' | cut -d'/' -f1)"
if [ -z "${vncpid}" ] ; then
	echo "vnc not running on the port in this machine" >&2
	vncserver "${vncdisplay}" "$@"
	exit $?
fi

vncpfile="$(grep -l "\\<${vncpid}\\>" "${vncdir}/"*.pid 2>/dev/null)"
[ -z "${vncpfile}" ] && die "vnc port (${vncport}) is running by others"

