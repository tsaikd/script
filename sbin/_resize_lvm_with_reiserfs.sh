#!/bin/bash

PN="${BASH_SOURCE[0]##*/}"
PD="${BASH_SOURCE[0]%/*}"

source "${PD}/../lib/common" || exit 1
source "${PD}/../lib/layout.sh" || exit 1
source "${PD}/../lib/convsize.sh" || exit 1
source "${PD}/../lib/kdread" || exit 1

function usage() {
	cat <<EOF
Usage: ${PN} <OPTIONS> <Dir|Dev Path>
  -h | --help    : show this help message
  -q | --quiet   : only show necessary message
  -L <SIZE>      : target size, SIZE format: '[+-]<NUM>[BbKkMmGgTt]'
EOF
	[ $# -gt 0 ] && { echo ; die "$@" ; } || exit 0
}

type getopt cat grep awk bc vgs lvs lvchange lvresize resize_reiserfs >/dev/null || exit $?

opt="$(getopt -o hqL: -- "$@")" || usage "Parse options failed"

eval set -- "${opt}"
while true ; do
	case "${1}" in
	-h|--help) usage ;;
	-q|--quiet) set_quiet 1 ; shift ;;
	-L) LSIZE="${2}" ; shift 2 ;;
	--) shift ; break ;;
	*) die "Internal error!" ;;
	esac
done

MNT_PATH="$(readlink -f "${1}")" ; shift

[ "$#" -gt 0 ] && usage "Invalid parameters"


# automatically call on_exit function when exit program
function on_exit() {
	return
}

trap on_exit EXIT

# ========================================================================
# Script start from here:

DEV_PATH=""

if [ -b "${MNT_PATH}" ] ; then
	DEV_PATH="${MNT_PATH}"
	MNT_PATH="$(mount | grep "^${DEV_PATH} " | awk '{print $3}')"
elif [ -d "${MNT_PATH}" ] ; then
	DEV_PATH="$(df "${MNT_PATH}" | awk '{if(NR==2){print $1}}')"
fi

if [ ! -b "${DEV_PATH}" ] ; then
	die "Device path (${DEV_PATH}) is not exists!"
fi

if [ -z "${LSIZE}" ] ; then
	usage "Please set size"
fi

if [ "$(grep "^/dev/mapper/" <<<"${DEV_PATH}")" ] ; then
	VG="$(sed 's/\/dev\/mapper\/\([^-]\+\)-/\1\//' <<<"${DEV_PATH}")"
	LV="$(awk -F '/' '{print $2}' <<<"${VG}")"
	VG="$(awk -F '/' '{print $1}' <<<"${VG}")"
elif [ "$(grep -E "^/dev/dm-[0-9]+" <<<"${DEV_PATH}")" ] ; then
	name="$(dmsetup info "${DEV_PATH}" | grep "^Name:" | awk '{print $2}')"
	VG="$(cut -d- -f1 <<<"${name}")"
	LV="$(cut -d- -f2- <<<"${name}")"
elif [ "$(grep "^/dev/" <<<"${DEV_PATH}")" ] ; then
	LV="$(awk -F '/' '{print $4}' <<<"${DEV_PATH}")"
	VG="$(awk -F '/' '{print $3}' <<<"${DEV_PATH}")"
else
	LV=""
	VG=""
fi

if [ -z "${LV}" ] || [ -z "${VG}" ] ; then
	die "Can't parse device path '${DEV_PATH}' for VG, LV"
fi

if [ -z "${MNT_PATH}" ] ; then
	MNT_PATH="$(mount | grep "^/dev/mapper/${VG}-${LV} " | awk '{print $3}')"
fi

LV_SIZE="$(lvs "${VG}/${LV}" --noheadings --units b --nosuffix 2>/dev/null)" \
	|| die "Can't find LVM device at ${DEV_PATH}"
LV_SIZE="$(echo "${LV_SIZE}" | awk '{print $4}')"

TAR_SIZE="$(msize "${LSIZE}")"

if [ "${TAR_SIZE:0:1}" == "+" ] ; then
	LSIZE="$((LV_SIZE + TAR_SIZE))"
elif [ "${TAR_SIZE:0:1}" == "-" ] ; then
	LSIZE="$((LV_SIZE + TAR_SIZE))"
elif [ "${TAR_SIZE}" -ne "${LV_SIZE}" ] ; then
	LSIZE="${TAR_SIZE}"
else
	einfo "No need to resize: ${DEV_PATH} ($(hsize "${TAR_SIZE}"))"
	exit
fi

if ((LSIZE < 1)) ; then
	die "Invalid size: '${LSIZE}'"
fi

VG_INFO="$(vgs "${VG}" --noheadings --units b --nosuffix)"
VG_FREE="$(echo "${VG_INFO}" | awk '{print $7}')"
CH_SIZE="$((LSIZE - LV_SIZE))"

if ((CH_SIZE > 0)) ; then
	if ((CH_SIZE > VG_FREE)) ; then
		eerror "Not enough space"
		eerror "Need: ${CH_SIZE} ($(hsize "${CH_SIZE}"))"
		eerror "Rest: ${VG_FREE} ($(hsize "${VG_FREE}"))"
		exit 1
	fi
elif ((CH_SIZE < 0)) ; then
	if [ "${MNT_PATH}" ] ; then
		LV_FREE="$(df -kP "${DEV_PATH}" | awk '{if(NR==2){print $4}}')k"
		LV_FREE="$(msize "${LV_FREE}")"

		if ((-CH_SIZE > LV_FREE)) ; then
			eerror "Can't reduce so much size"
			eerror "Need: ${CH_SIZE} ($(hsize "${CH_SIZE}"))"
			eerror "Rest: ${LV_FREE} ($(hsize "${LV_FREE}"))"
			exit 1
		fi
	fi

	if [ "$(fuser -m "${DEV_PATH}" 2>&1)" ] ; then
		eerror "Don't support for reducing size on-line"
		eerror "Please close all applications that using '${DEV_PATH}'"
		eerror "Tips: Use 'fuser -muv \"${DEV_PATH}\"' to check all process"
		exit 1
	fi
else
	eerror "Something bad occured"
	eerror "Please contact to tsaikd<tsaikd@gmail.com>"
	exit 1
fi

einfo "Device information:"
einfo "    Device path: '${DEV_PATH}'"
einfo "    Mount path: '${MNT_PATH}'"
einfo "    LVM group: ${VG}"
einfo "    LVM volume: ${LV}"
einfo "    LVM group free size: '$(hsize ${VG_FREE})'"
einfo ""
einfo "Changed information:"
einfo "    LVM volume size from '$(hsize ${LV_SIZE})' to '$(hsize ${LSIZE})' ($(hsize ${CH_SIZE}))"
einfo ""
kdread "Are you sure ?" 2 "Yes" "No"
if [ $? -ne 1 ] ; then
	ewarn "User canceld"
	exit
fi

if ((CH_SIZE < 0)) ; then
	if [ "${MNT_PATH}" ] ; then
		umount "${MNT_PATH}" || die "umount failed"
	fi

	resize_reiserfs -s "${TAR_SIZE}" "${DEV_PATH}" || die "resize_reiserfs failed"
	lvchange -a n "${VG}/${LV}" || die "lvchange failed"
	lvresize -L "${TAR_SIZE}B" "${VG}/${LV}" || die "lvresize failed"
	lvchange -a y "${VG}/${LV}" || die "lvchange failed"
	resize_reiserfs "${DEV_PATH}" || die "resize_reiserfs failed"

	if [ "${MNT_PATH}" ] ; then
		mount "${DEV_PATH}" "${MNT_PATH}" || die "mount failed"
	fi
else
	lvresize -L "${TAR_SIZE}B" "${VG}/${LV}" || die "lvresize failed"
	lvchange -a y "${VG}/${LV}" || die "lvchange failed"
	resize_reiserfs "${DEV_PATH}" || die "resize_reiserfs failed"
fi

