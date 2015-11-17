#!/usr/bin/env bash
# This is a wrapper script so the create_n_deploy script doesn't need to handle different script behaviours.
# In the end, c_n_d expects a "rootfs.tar.xz" file in its root dir.
set -e
set -u

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOTFS_TARGET_DIR="$(dirname ${__dir})"

usage(){
echo "There's no use in here."
}

tmp() {
    ROOTFS=$(mktemp -d /tmp/busybox-docker-rootfs-XXXXXXXXXX)
    trap "rm -rf $ROOTFS" EXIT TERM INT
}

while getopts "ha:o:r:" opt; do
    case $opt in
        a)  
            ARCH=$OPTARG
            ;; 
        o)
            OS=$OPTARG
            ;;
        r)
            REL=$OPTARG
            ;;
        *)  
            usage
            ;;  
    esac
done

ARCH=${ARCH:-armhf}
OS=${OS:-}

if [ -z ${OS} ]
then
    exit 1
fi

tmp

bash "${__dir}/mkimage-${OS}.sh" "${ROOTFS}" < /dev/null
tar --numeric-owner -C "${ROOTFS}" -c . | xz > "${ROOTFS_TARGET_DIR}/rootfs.tar.xz"
rm -rf "${ROOTFS}"
