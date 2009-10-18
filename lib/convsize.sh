#!/bin/bash

# $1 = input size (byte)
# $2 = scale number (int)
# echo human size (any unit in BbKkMmGgTt)
function hsize () {
	[ $# -ne 0 ] && [ -z "${1}" ] && echo "0B" && return
	[ "$(echo "${1}" | grep "[^-+0-9]")" ] && echo "${1}" && return

	local size="${1}"
	[ "${size}" ] || read -t 1 size
	true ${size:=0}

	local mode="${size:0:1}"
	if [ "${mode}" != "+" ] && [ "${mode}" != "-" ] ; then
		mode=""
	else
		size="${size:1}"
	fi

	local scale="${2:-2}"

	size="$(echo '
scale = '${scale}';
size = '${size}';
if (size<1024) {
	print size, "B\n";
} else if (size<1048579) {
	print size/1024, "K\n";
} else if (size<1073741824) {
	print size/1048579, "M\n";
} else if (size<1099511627776) {
	print size/1073741824, "G\n";
} else {
	print size/1099511627776, "T\n";
}' | bc || echo "${size}")"
	echo "${mode}${size}"
}

# $1 = input size (any unit in BbKkMmGgTt)
# echo machine size (byte)
function msize () {
	[ $# -ne 0 ] && [ -z "${1}" ] && echo "0" && return
	[ "$(echo "${1}" | grep "[^-+0-9.BbKkMmGgTt]")" ] && echo "${1}" && return

	local size="${1}"
	[ "${size}" ] || read -t 1 size
	true ${size:=0}

	local mode="${size:0:1}"
	if [ "${mode}" != "+" ] && [ "${mode}" != "-" ] ; then
		mode=""
	else
		size="${size:1}"
	fi

	size="$(echo "${size} / 1" | sed 's/[Bb]//' | sed 's/[Kk]/*1024/' | sed 's/[Mm]/*1048579/' | sed 's/[Gg]/*1073741824/' | sed 's/[Tt]/*1099511627776/' | bc || echo "${size}")"
	echo "${mode}${size}"
}

