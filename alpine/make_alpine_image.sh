#!/usr/bin/env bash
# derivated from https://github.com/docker/docker/blob/master/contrib/mkimage-alpine.sh
set -e
set -u

[ $(id -u) -eq 0 ] || {
	printf >&2 '%s requires root\n' "$0"
	exit 1
}

usage() {
	printf >&2 '%s: [-r release] [-m mirror] [-s]\n' "$0"
	exit 1
}

tmp() {
	TMP=$(mktemp -d ${TMPDIR:-/var/tmp}/alpine-docker-XXXXXXXXXX)
	ROOTFS=$(mktemp -d ${TMPDIR:-/var/tmp}/alpine-docker-rootfs-XXXXXXXXXX)
	trap "rm -rf $TMP $ROOTFS" EXIT TERM INT
}

apkv() {
	curl -sSL $REPO/$ARCH/APKINDEX.tar.gz | tar -Oxz |
		grep -a '^P:apk-tools-static$' -A1 | tail -n1 | cut -d: -f2
}

getapk() {
	curl -sSL $REPO/$ARCH/apk-tools-static-$(apkv).apk |
		tar -xz -C $TMP sbin/apk.static
}

mkbase() {
	$TMP/sbin/apk.static --repository $REPO --update-cache --allow-untrusted \
		--root $ROOTFS --initdb add alpine-base
}

conf() {
	printf '%s\n' $REPO > $ROOTFS/etc/apk/repositories
}

pack() {
	local id
	#id=$(tar --numeric-owner -C $ROOTFS -c . | docker import - ${HUB_USER}/alpine_armhf:$REL)
	#docker run -i -t ${HUB_USER}/alpine_armhf:${REL} printf 'alpine_armhf:%s with id=%s created!\n' $REL $id
    # Optimisations taken from https://github.com/armbuild/alpine/blob/master/edge/mkimage-alpine.sh
    tar --numeric-owner -C $ROOTFS -c . > rootfs.tar
    
    id=$(cat rootfs.tar | docker import - ${HUB_USER}/alpine_armhf:$REL)
    docker run -i -t ${HUB_USER}/alpine_armhf:${REL} printf 'alpine_armhf:%s with id=%s created!\n' $REL $id
	docker rm $(docker ps -l|tail -1|cut -f1 -d' ')
    for TAG in "${TAGS[@]}"
    do
        docker tag ${id} ${HUB_USER}/alpine_armhf:${TAG}
    done
}

save() {
	if [ $SAVE -eq 1 ]
	then
		tar --numeric-owner -C $ROOTFS -c . | xz > rootfs_${REL}.tar.xz
	fi
}

while getopts "hr:m:st:a:" opt; do
	case $opt in
		r)
			REL=$OPTARG
			;;
		m)
			MIRROR=$OPTARG
			;;
		s)
			SAVE=1
			;;
        t)
            TAGS_CSV=$OPTARG
            ;;
		*)
			usage
			;;
	esac
done

HUB_USER=${HUB_USER:-m3adow}
REL=${REL:-latest-stable}
TAGS_CSV=${TAGS_CSV:-${REL}}
MIRROR=${MIRROR:-http://nl.alpinelinux.org/alpine}
SAVE=${SAVE:-0}
REPO=$MIRROR/$REL/main
ARCH=${ARCH:-$(uname -m)}

# Bash arrays are better than nothing
TAGS=(${TAGS_CSV//,/ })

tmp
getapk
mkbase
conf
pack
save
