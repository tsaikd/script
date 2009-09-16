#!/bin/bash -v

function usage() {
	cat <<EOF
$0 <Build Type> <Project Dir> [Archive file1] [Archive file2]...
EOF
}

build_type="${1}"
shift
proj_dir="${1}"
shift
proj_tar="${JOB_NAME}-${BUILD_NUMBER}"

pushd "${proj_dir}" &>/dev/null || exit 1
case "${build_type}" in
qt4)
	qmake && make debug && make release || exit 1
	;;
*)
	echo "Build Type not support ('${build_type}')"
	exit 1
	;;
esac
popd &>/dev/null

mkdir -p "tmp/${proj_tar}/"
for i in "$@" ; do
	cp -a "${i}" "tmp/${proj_tar}/" || exit 1
done

pushd "tmp" &>/dev/null || exit 1
7z a -m0=lzma -mx=9 -mfb=273 -md=32m "..\${proj_tar}.7z" "${proj_tar}"
popd &>/dev/null

