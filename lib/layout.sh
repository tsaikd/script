#!/bin/bash
#=====================================================================
# global variable
#---------------------------------------------------------------------
# C_N
# C_R
# C_G
# C_B
# C_H
# C_Y
#
# E_MSG_LV
# LAST_E_TYPE
#=====================================================================

if ! type set_quiet >/dev/null 2>&1 ; then

PD="${BASH_SOURCE[0]%/*}"
source "${PD}/common" || exit 1

neccmd tput

# $1 := Level number
#    0 : eerror ewarn einfo einfon ebegin [eend] vecho vechon (default)
#    1 : eerror ewarn [eend]
#    2 : eerror [eend]
#    3 :
function set_quiet() {
	local level="${1:-0}"

	case "${level}" in
	0|1|2|3) E_MSG_LV="${level}" ;;
	*) echo "Line ${BASH_LINENO} ${FUNCNAME}(): Invalid parameters" >&2 ;;
	esac

	return 0
}

# use global variable to speed up for tput system program
# and output without newline
#_TPUT_CUU1=
#_TPUT_CUD1=
#_TPUT_CUB1=
#_TPUT_CUF1=
#_TPUT_EL=
#_TPUT_LL=
#_TPUT_KD_CLH= # cursor to head of line and clear line
#_TPUT_KD_CLL= # cursor to last line of screen and clear line
#_TPUT_KD_CLL2= # cursor to up of last line of screen and clear line
function _tput() {
	case "${1}" in
	cols) ((${#COLUMNS})) && echo -ne "${COLUMNS}" && return $?
		COLUMNS="$(tput cols)"
		((${#COLUMNS})) || die "Not support tput cols"
		echo -ne "${COLUMNS}"
		;;
	lines) ((${#LINES})) && echo -ne "${LINES}" && return $?
		LINES="$(tput lines)"
		((${#LINES})) || die "Not support tput lines"
		echo -ne "${LINES}"
		;;
	cuu1) [ "${_TPUT_CUU1}" == "DISABLE" ] && return 1
		((${#_TPUT_CUU1})) && echo -ne "${_TPUT_CUU1}" && return $?
		_TPUT_CUU1="$(tput cuu1)"
		((${#_TPUT_CUU1})) || _TPUT_CUU1="$(_tput cuu 1)"
		((${#_TPUT_CUU1})) || ( ( [ "${TERM}" == "screen" ] || [ "${TERM}" == "xterm" ] ) && _TPUT_CUU1="\e[1A" )
		echo -ne "${_TPUT_CUU1}"
		((${#_TPUT_CUU1})) || _TPUT_CUU1="DISABLE"
		;;
	cud1) ((${#_TPUT_CUD1})) && echo -ne "${_TPUT_CUD1}" && return $?
		_TPUT_CUD1="$(tput cud1)"
		((${#_TPUT_CUD1})) || _TPUT_CUD1="$(_tput cud 1)"
		((${#_TPUT_CUD1})) || _TPUT_CUD1="\e[1B"
		echo -ne "${_TPUT_CUD1}"
		;;
	cub1) ((${#_TPUT_CUB1})) && echo -ne "${_TPUT_CUB1}" && return $?
		_TPUT_CUB1="$(tput cub1)"
		((${#_TPUT_CUB1})) || _TPUT_CUB1="$(_tput cub 1)"
		((${#_TPUT_CUB1})) || _TPUT_CUB1="\e[1D"
		echo -ne "${_TPUT_CUB1}"
		;;
	cuf1) ((${#_TPUT_CUF1})) && echo -ne "${_TPUT_CUF1}" && return $?
		_TPUT_CUF1="$(tput cuf1)"
		((${#_TPUT_CUF1})) || _TPUT_CUF1="$(_tput cuf 1)"
		((${#_TPUT_CUF1})) || _TPUT_CUF1="\e[1C"
		echo -ne "${_TPUT_CUF1}"
		;;
	el) [ "${_TPUT_EL}" == "DISABLE" ] && return 1
		((${#_TPUT_EL})) && echo -ne "${_TPUT_EL}" && return $?
		_TPUT_EL="$(tput el)"
		((${#_TPUT_EL})) || ( _TPUT_EL="DISABLE" ; die "Not support tput el" )
		echo -ne "${_TPUT_EL}"
		;;
	ll) ((${#_TPUT_LL})) && echo -ne "${_TPUT_LL}" && return $?
		_TPUT_LL="$(tput ll)"
		((${#_TPUT_LL})) || _TPUT_LL="$(_tput cup $(_tput lines) 0)"
		((${#_TPUT_LL})) || die "Not support tput ll"
		echo -ne "${_TPUT_LL}"
		;;
	kd_clh) ((${#_TPUT_KD_CLH})) && echo -ne "${_TPUT_KD_CLH}" && return $?
		_TPUT_KD_CLH="$(_tput cuu1)\n$(_tput el)"
		echo -ne "${_TPUT_KD_CLH}"
		;;
	kd_cll) ((${#_TPUT_KD_CLL})) && echo -ne "${_TPUT_KD_CLL}" && return $?
		_TPUT_KD_CLL="$(_tput ll)$(_tput el)"
		echo -ne "${_TPUT_KD_CLL}"
		;;
	kd_cll2) ((${#_TPUT_KD_CLL2})) && echo -ne "${_TPUT_KD_CLL2}" && return $?
		_TPUT_KD_CLL2="$(_tput kd_cll)$(_tput cuu1)$(_tput el)"
		echo -ne "${_TPUT_KD_CLL2}"
		;;
	*) tput $@ ;;
	esac
}
_tput kd_clh >/dev/null 2>&1

function set_colors() {
	C_N=$'\e[0m'
	C_R=$'\e[31;01m'
	C_G=$'\e[32;01m'
	C_B=$'\e[34;01m'
	C_H=$'\e[36;01m'
	C_Y=$'\e[33;01m'

	local cols=$(_tput cols)
	cols=$((cols - 7))

	ENDCOL="$(_tput cuu1)$(_tput cuf ${cols})"
	[ -z "${ENDCOL}" ] && ENDCOL=$'\e[A\e['${cols}'C'
	ENDCOL="${ENDCOL}$(_tput el)"

	return 0
}

function unset_colors() {
	unset C_N
	unset C_R
	unset C_G
	unset C_B
	unset C_H
	unset C_Y

	unset ENDCOL

	return 0
}

# Check last command is type n or not
# Example:
#   elastn && vecho
function elastn() {
	[[ "${LAST_E_TYPE}" == "n" ]]
}

# $1 := message level
# $2- = messages
function _vecho() {
	local level="${1:-0}"
	shift

	((E_MSG_LV <= level)) || return 0

	echo -e "$@"

	LAST_E_TYPE=""
	return 0
}

# $1 := message level
# $2- = messages
function _vechon() {
	local level="${1:-0}"
	shift

	((E_MSG_LV <= level)) || return 0

	echo -ne "$@"

	LAST_E_TYPE="n"
	return 0
}

function vecho() {
	_vecho 0 "$@"
}

function vechon() {
	_vechon 0 "$@"
}

function einfo() {
	elastn && _vecho 0 || _vechon 0 "$(_tput kd_clh)"
	_vecho 0 " ${C_G}*${C_N} $*"
}

function einfon() {
	elastn && _vecho 0 || _vechon 0 "$(_tput kd_clh)"
	_vechon 0 " ${C_G}*${C_N} $*"
}

function ewarn() {
	elastn && _vecho 1 || _vechon 1 "$(_tput kd_clh)"
	_vecho 1 " ${C_Y}*${C_N} $*"
}

function eerror() {
	elastn && _vecho 2 || _vechon 2 "$(_tput kd_clh)"
	_vecho 2 " ${C_R}*${C_N} $*"
}

function ebegin() {
	((E_MSG_LV == 0)) || return 0

	einfo "$@ ... "
}

function eend() {
	((E_MSG_LV <= 2)) || return 0

	local retval="${1:-0}"
	shift

	if [ "${retval}" -eq 0 ] ; then
		elastn && _vecho 0
		[ $# -gt 0 ] && einfo "$@"
		_vecho 0 "${ENDCOL} ${C_B}[ ${C_G}ok${C_B} ]${C_N}"
	else
		elastn && _vecho 2
		[ $# -gt 0 ] && eerror "$@"
		_vecho 2 "${ENDCOL} ${C_B}[ ${C_R}!!${C_B} ]${C_N}"
	fi

	return ${retval}
}

function einfo_cb() {
	((E_MSG_LV == 0)) || return 0

	_tput kd_cll2
	einfo "$@"
}

function einfon_cb() {
	((E_MSG_LV == 0)) || return 0

	_tput kd_cll2
	einfon "$@"
}

true "${E_MSG_LV:=0}"
true "${TERM:=screen}"
export TERM

if [ "${TERM}" == "screen" ] || [ "${TERM}" == "xterm" ] ; then
	true ${NOCOLOR:=no}
else
	true ${NOCOLOR:=yes}
fi
case "${NOCOLOR}" in
yes|true) unset_colors ;;
no|false) set_colors ;;
esac


poparg
fi

