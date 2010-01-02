#!/bin/bash
#=====================================================================
# necessary initialization variable
#---------------------------------------------------------------------
# KDSQL_DBPATH
#=====================================================================
# usable function
#---------------------------------------------------------------------
# sqlite
#=====================================================================
# global variable
#---------------------------------------------------------------------
# TMPDIR
# KDSQL_CMDTMP
# KDSQL_RETRY_MAXTIMES (-1: unlimited, 0: no retry)
# KDSQL_RETRY_INTERVAL
# KDSQL_SEP
#=====================================================================

if ! type sqlite >/dev/null 2>&1 ; then

if [ -z "${BASH_SOURCE}" ] ; then
	echo "KDSQL.sh need to run in bash" >&2
	exit 1
fi

dir="$(readlink -f "${BASH_SOURCE[0]}")"
dir="$(dirname "${dir}")"
source "${dir}/layout.sh" || exit 1
unset dir

true ${TMPDIR:=/tmp}
true ${KDSQL_CMDTMP:=${TMPDIR}/KDSQL_CMDTMP_$$.tmp}
true ${KDSQL_RETRY_MAXTIMES:=-1}
true ${KDSQL_RETRY_INTERVAL:=2}
true ${KDSQL_SEP:=" <!> "}

_KD_sqlite="$(type -P sqlite3)"
if [ -z "${_KD_sqlite}" ]  ; then
	eerror "Can't find necessary program 'sqlite3'"
	exit 1
fi

function sqlite() {
	local retrymax="${KDSQL_RETRY_MAXTIMES}"
	local retry=0
	local retval

	if [ -z "${KDSQL_DBPATH}" ] ; then
		eerror 'Empty ${KDSQL_DBPATH}'
		return 1
	fi

	while true ; do
		${_KD_sqlite} -list -separator "${KDSQL_SEP}" "${KDSQL_DBPATH}" "$@" 2>"${KDSQL_CMDTMP}"
		retval=$?
		if ((retval == 0)) ; then
			rm -f "${KDSQL_CMDTMP}"
			return 0
		fi

		(( (retrymax >= 0) && (retry >= retrymax) )) && return ${retval}
		((retry++))

		if [ -f "${KDSQL_CMDTMP}" ] ; then
			if [ "$(grep "SQL error: database is locked" "${KDSQL_CMDTMP}")" ] ; then
				if ((retry <= 1)) ; then
					einfo "SQL error: database is locked"
				elif ((retry == 2)) ; then
					einfo "locked retry: ${retry}"
				else
					tput cuu 1
					einfo "locked retry: ${retry}"
				fi
			else
				error "$(cat "${KDSQL_CMDTMP}")"
				rm -f "${KDSQL_CMDTMP}"
				return ${retval}
			fi
			rm -f "${KDSQL_CMDTMP}"
		fi

		sleep "${KDSQL_RETRY_INTERVAL}"
	done
}


fi

