#!/bin/bash

# This script is preparing the local GIT repository for an update of the yala-errors.tar.xz. This includes:
# - creating the yala-errors.tar.xz from the local GIT repository folders (yala-errors and condition-scripts)
# - updating the tarmd5

# Usage: sh ./prepare-yala-errors-update.sh

SCRIPT_SH="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
BASE_DIR=$(dirname "$(readlink -f "$0")")/../

YALA_ERRORS_TAR="${BASE_DIR}/yala-errors.tar.xz"
TAR_MD5="${BASE_DIR}/tarmd5"

IGNORE_UNCOMITTED_CHANGES=0

cd ${BASE_DIR}

# parse the cli options
OPTS=$(getopt -o 'i' --long 'ignore' -n "${SCRIPT_SH}" -- "$@")

# if getopt has a returned an error, exit with the return code of getopt
res=$?; [ $res -gt 0 ] && exit $res

eval set -- "$OPTS"
unset OPTS

while true; do
    case "$1" in
        '-i'|'--ignore')
            IGNORE_UNCOMITTED_CHANGES=1; shift
            ;;
        '--') shift; break;;
        * )
            echo "Invalid Option: $1"
            echo ""
            usage; exit; shift
            ;;
    esac
done

if [ ${IGNORE_UNCOMITTED_CHANGES} -eq 0 ]; then
    # ensure there no open or untracked files in the local GIT repository
    if [[ `git status --porcelain` ]]; then
      echo "Uncomitted changes in the repository. The script must be called when no files are opened, or option '-i|--ignore' must be set."
      exit 1
    fi
fi

[ -f ${YALA_ERRORS_TAR} ] && rm ${YALA_ERRORS_TAR}

tar cvfoz ${YALA_ERRORS_TAR} yala-errors/ condition-scripts/ 2>&1 >/dev/null

NEW_MD5=($(md5sum ${YALA_ERRORS_TAR}))

echo ${NEW_MD5} > ${TAR_MD5}
