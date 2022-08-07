#!/bin/bash
#
# PI DISPLAY SLIDESHOW
#
# Version 0.1.3
#
# Usage:
#   slideshow.sh [ config.ini ]
#
# Andrew Donald Kennedy
# Copyright 2022 by BEHOLDER

#set -x # DEBUG

# load configuration file
CONFIG_FILE="$(dirname $0)/$(basename $0 .sh).ini"
source=${1:-${CONFIG_FILE}}
[ -f ${source} ] && . ${source}

# dropbox configuration
DROPBOX_URL="${DROPBOX_URL:-https://www.dropbox.com/sh/422x1u57rnc2op6/AADNP_LJe48lBRg1RS5-mtnpa/Posters}"
DROPBOX_DIR="${DROPBOX_DIR:-./dropbox}"

# slideshow configuration
SLIDESHOW_LENGTH="${SLIDESHOW_LENGTH:-30}"
SLIDESHOW_DELAY="${SLIDESHOW_DELAY:-10}"
SLIDESHOW_ROTATE="${SLIDESHOW_ROTATE:-true}"
SLIDESHOW_JOIN="${SLIDESHOW_JOIN:-false}"

# get screen size
SCREEN_RES="${SCREEN_RES:-$(fbset | grep mode | cut -d\" -f2)}"

# slideshow process id
FEH_PID=""

# setup directory
mkdir -p ${DROPBOX_DIR}
cd ${DROPBOX_DIR}

while true ; do
    # download archive from dropbox
    tmpfile=$(mktemp /tmp/dropbox.XXXXXX)
    wget ${DROPBOX_URL} -O ${tmpfile}.zip

    # extract files from archive
    rm -f *.*
    unzip -a ${tmpfile}.zip

    # go through files in archive
    ls -1 | while read file ; do
        # check name and extension
        extension="${file##*.}"
        filename="${file%.*}"

        # convert all files to png
        if [ "${extension}" == "pdf" ] ; then
            pdftoppm -singlefile -f 1 -png "${file}" "${filename}"
            rm -f "${file}"
        elif [ "${extension}" != "png" ] ; then
            convert "${file}" "${filename}.png"
            rm -f "${file}"
        fi 
        
        # rotate 90 degrees
        mogrify -rotate "-90" "${filename}.png"

        # resize to screen
        mogrify -resize "${SCREEN_RES}" \
                -background black \
                -gravity center \
                -extent "${SCREEN_RES}" "${filename}.png"
    done

    # run slideshow
    if [ "${FEH_PID}" ] ; then
        kill -USR1 ${FEH_PID}
    else
        feh -F -Y -N --slideshow-delay "${SLIDESHOW_DELAY}" "${DROPBOX_DIR}" &
        FEH_PID=$!
    fi

    # wait for X minutes
    delay=$((${SLIDESHOW_LENGTH} * 60))
    sleep ${delay}
done