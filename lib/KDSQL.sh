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

PN="${BASH_SOURCE[0]##*/}"
PD="${BASH_SOURCE[0]%/*}"

source "${PD}/common" || exit 1
source "${PD}/layout.sh" || exit 1

true ${TMPDIR:=/tmp}
true ${KDSQL_CMDTMP:=${TMPDIR}/KDSQL_CMDTMP_$$.tmp}
true ${KDSQL_RETRY_MAXTIMES:=-1}
true ${KDSQL_RETRY_INTERVAL:=2}
true ${KDSQL_SEP:=" <!> "}

neccmd sqlite3

_KD_sqlite="$(type -P sqlite3)"

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


poparg
fi # ! type sqlite

