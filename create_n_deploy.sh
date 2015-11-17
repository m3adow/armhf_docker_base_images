#!/usr/bin/env bash
set -e
set -u

# Set magic variable for working dir, thx kvz.io
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ $(id -u) -eq 0 ] || {
    printf >&2 '%s requires root\n' "$0"
        exit 1
}

usage() {
    printf >&2 '%s: [-a arch] [-d]\n' "$0"
    exit 1
}

mkimages() {
    cd "${__dir}"
    # Iterate over every directory excluding dirs starting with _ or .
    for OSDIR in $(find ${__dir} -maxdepth 1 -mindepth 1 -regextype posix-egrep -type d -regex '^\/?(\w+\/)*[^_.]\w+$')
    do
        OS=${OSDIR##*/}
        VERSIONFILE="${OSDIR}/Versionfile"
        if [ ! -f "${VERSIONFILE}" -o ! -r ${VERSIONFILE} -o ! -f "${OSDIR}/wrapper.sh" ]
        then
            echo "${OS}: Not all needed files accessible. Skipping."
            continue
        fi

        while read VERSIONLINE
        do
            REGEGGS='^#'
            [[ ${VERSIONLINE} =~ ${REGEGGS} ]] && continue
            REL=${VERSIONLINE%:*}
            TAGS_CSV=${VERSIONLINE##*:}
            MAIN_TAG=${TAGS_CSV%%,*}
            echo "### Processing '${VERSIONLINE}'."
            # bash "${OSDIR}/mkimage-${OS}.sh" -r "${REL}" -s </dev/null
            bash "${OSDIR}/wrapper.sh" -a ${ARCH} -o ${OS} -r ${REL} </dev/null

            mkdir -p "${OSDIR}/${MAIN_TAG}"
            [ -f "${__dir}/rootfs.tar.xz" ] && mv "${__dir}/rootfs.tar.xz" "${OSDIR}/${MAIN_TAG}"
            # Check for Default files
            for FILE in $(ls -1 "${__dir}/${SKEL_DIR}")
            do
                [ -f "${OSDIR}/${MAIN_TAG}/${FILE}" ] || {
                    cp --preserve=mode,ownership "${__dir}/${SKEL_DIR}/${FILE}" "${OSDIR}/${MAIN_TAG}/"
                    # substitute placeholders if existing
                    sed -i -e "s/%HUB_USER%/${HUB_USER}/g" \
                        -e "s/%REL%/${REL}/g" -e "s/%OS%/${OS}/g" \
                        -e "s/%MAIN_TAG%/${MAIN_TAG}/g" "${OSDIR}/${MAIN_TAG}/${FILE}"
                }
            done

            IMAGE_ID=$(docker images -q |head -1)
#            # Create correct Tags and remove unneeded ones from the creation script
#            for TAG in $(echo "${TAGS_CSV}"| sed 's/,/ /g')
#            do
#                FULL_IMAGE_NAME="${HUB_USER}/${ARCH}-${OS}:${TAG}"
#                docker tag -f ${IMAGE_ID}  ${FULL_IMAGE_NAME}
#                docker rmi ${OS}:${TAG} || true
#                docker push ${FULL_IMAGE_NAME}
#            done
            # Remove the docker container started for testing the image and the last unneeded tag
            # docker rmi -f ${OS}:${REL} || true
            docker rm $(docker ps -l -q) 2>/dev/null || true
            docker rmi -f ${IMAGE_ID} 2>/dev/null || true
            
            echo "### DONE."
        done < ${VERSIONFILE}
    done

}

gitpush(){
    cd ${__dir}
    git add -A
    git commit -m "Automatic push from deployment script"
    git push
}

while getopts "ha:u:" opt; do
    case $opt in
        a)
            ARCH=$OPTARG
            ;;
        u)
            HUB_USER=$OPTARG
            ;;
        *)
            usage
            ;;
    esac
done


export ARCH=${ARCH:-armhf}
DAILY=${DAILY:-0}
HUB_USER=${HUB_USER:-m3adow}
SKEL_DIR=${SKEL_DIR:-_skel}

mkimages
gitpush
