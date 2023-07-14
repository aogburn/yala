#!/bin/bash

# This script is preparing the local GIT repository for an update of the yala.sh. This includes:
# - updating the md5 file

# Usage: sh ./prepare-yala-update.sh

SCRIPT_SH="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
BASE_DIR=$(dirname "$(readlink -f "$0")")/../

YALA_SH="${BASE_DIR}/yala.sh"
MD5="${BASE_DIR}/md5"

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

NEW_MD5=($(md5sum ${YALA_SH}))

echo ${NEW_MD5} > ${MD5}
