#!/usr/bin/env bash
set -e
set -u
#set -x

# Set magic variables for current file & dir, thx kvz.io
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

# And, of course the correct ARCH version
export ARCH="armhf"

cd ${__dir}

# Ignore hidden dirs and files with a leading underscore
for OSDIR in $(find ${__dir} -maxdepth 1 -mindepth 1 -regextype posix-egrep -type d -regex '^\/?(\w+\/)*[^_.]\w+$')
do
    VERSIONFILE="${OSDIR}/Versionfile"
    # If the VERSIONFILE can't be read, skip the dir
    if [ ! -f ${VERSIONFILE} -o ! -r ${VERSIONFILE} ]
    then
        echo "${OSDIR}: No Versionfile or unreadable, skipping dir."
        continue
    fi

    while read VERSIONLINE
    do
        REGEGGS='^#'
        [[ ${VERSIONLINE} =~ ${REGEGGS} ]] && continue		
        echo -n "LINE: $VERSIONLINE"
        VERSION=${VERSIONLINE%:*}
        TAGS_CSV=${VERSIONLINE##*:}
        OSNAME=$(basename ${OSDIR})
        bash "${OSDIR}/make_${OSDIR##*/}_image.sh" -r "${VERSION}" -t "${TAGS_CSV}" </dev/null #&>/dev/null
        mkdir -p "${OSDIR}/${VERSION}" &>/dev/null
        mv -u "rootfs.tar" "${OSDIR}/${VERSION}/rootfs.tar" &>/dev/null
        # Copy the Default Dockerfile and/or README.md if there is none existing yet
        [ -f "${OSDIR}/${VERSION}/Dockerfile" ] || cp -a "${__dir}/_misc/Dockerfile.dist" "${OSDIR}/${VERSION}/Dockerfile"
        if [ ! -f "${OSDIR}/${VERSION}/README.md" ]
        then
            cp -a "${__dir}/_misc/README.md.dist" "${OSDIR}/${VERSION}/README.md"
            sed -i -e "s/%OSNAME%/${OSNAME}/g" -e "s/%RELEASE%/${VERSION}/g" "${OSDIR}/${VERSION}/README.md"
        fi
        echo " => DONE"
    done < ${OSDIR}/Versionfile
done

# Push to git
# WIP
: '
git add -A
git commit -m "Auto push from script."
git push
'
