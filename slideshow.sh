#!/bin/bash
#
# PI DISPLAY SLIDESHOW
#
# Version 0.1.2
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

echo "DROPBOX_DIR = ${DROPBOX_DIR}"
exit

# slideshow configuration
SLIDESHOW_LENGTH="30"2# slideshow length in minutes
#
# Usage:
#   pi-display-slideshow.sh [ config.ini ]
SLIDESHOW_DELAY="10" # delay between slides in seconds
SLIDESHOW_ROTATE="true" # rotate posters for portrait mode?
SLIDESHOW_JOIN="false" # join two posters with same prefix in landscape

FEH_PID=""

# get screen size
#screen="$(fbset | grep mode | cut -d\" -f2)"
screen="2056x1329"

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
        mogrify -resize "${screen}" \
                -background black \
                -gravity center \
                -extent "${screen}" "${filename}.png"
    done

    # run slideshow
    if [ "${FEH_PID}" ] ; then
        kill -9 ${FEH_PID}
    fi
    feh -F -Y -N --slideshow-delay "${SLIDESHOW_DELAY}" "${DROPBOX_DIR}" &
    FEH_PID=$!

    # wait for X minutes
    delay=$((${SLIDESHOWWLENGTH} * 60))
    sleep ${delay}
done