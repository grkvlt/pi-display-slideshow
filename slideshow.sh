#!/bin/bash
#
# PI DISPLAY SLIDESHOW
#
# Raspberry PI slideshow for displaying posters on a portrait mode
# monitor. The posters should be available as a publicly readable
# Dropbox folder, provided as a download URL to the script.
#
# Version 0.1.3
#
# Usage:
#   slideshow.sh [ config.ini ]
#
# Copyright 2022 by Andrew Donald Kennedy
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#set -x # DEBUG

# load configuration file
CONFIG_FILE="$(dirname $0)/$(basename $0 .sh).ini"
source=${1:-${CONFIG_FILE}}
[ -f ${source} ] && . ${source}

# dropbox configuration
DROPBOX_URL="${DROPBOX_URL:-https://www.dropbox.com/sh/422x1u57rnc2op6/AADNP_LJe48lBRg1RS5-mtnpa/Posters}"

# slideshow configuration
SLIDESHOW_LENGTH="${SLIDESHOW_LENGTH:-30}"
SLIDESHOW_DELAY="${SLIDESHOW_DELAY:-10}"
SLIDESHOW_ROTATE="${SLIDESHOW_ROTATE:-true}"
SLIDESHOW_JOIN="${SLIDESHOW_JOIN:-false}"

# get screen size
SCREEN_RES="${SCREEN_RES:-$(fbset | grep mode | cut -d\" -f2)}"
SCREEN_X=$(echo ${SCREEN_RES} | cut -dx -f1)
SCREEN_Y=$(echo ${SCREEN_RES} | cut -dx -f2)

# setup directory
SLIDESHOW_DIR="${SLIDESHOW_DIR:-./slideshow}"
mkdir -p ${SLIDESHOW_DIR}

# slideshow process id
FEH_PID=""

while true ; do
    # download archive from dropbox
    tmpfile=$(mktemp -u /tmp/slideshow.XXXXXX)
    wget ${DROPBOX_URL} -O ${tmpfile}.zip

    # extract files from archive
    tmpdir=$(mktemp -d /tmp/slideshow.XXXXXX)
    cd ${tmpdir}
    unzip -a ${tmpfile}.zip
    rm -f ${tmpfile}.zip

    # remove spaces etc from filenames
    ls -1 | while read file ; do
        fixed=$(echo "${file}" | tr " :-\'" "____")
        mv "${file}" "${fixed}"
    done

    # convert all file formats to png and rotate
    ls -1 | while read file ; do
        # get name and extension
        extension="${file##*.}"
        filename="${file%.*}"

        # convert to png
        if [ "${extension}" == "pdf" ] ; then
            pdftoppm -singlefile -f 1 -png "${file}" "${filename}"
            rm -f "${file}"
        elif [ "${extension}" != "png" ] ; then
            convert "${file}" "${filename}.png"
            rm -f "${file}"
        fi 
    done
        
    # rotate 90 degrees if required
    if ${SLIDESHOW_ROTATE} ; then
        ls -1 *.png | while read file ; do
            mogrify -rotate "-90" "${file}"
        done
    fi

    # join left/right pairs if required
    if ${SLIDESHOW_JOIN} ; then
        ls -1 *.png | xargs -n 2 echo | while read left right ; do
            # resize left and right to fit screen height
            mogrify -geometry "x${SCREEN_Y}" "${left}"
            mogrify -geometry "x${SCREEN_Y}" "${right}"

            # join left and right images
            join=$(mktemp -u /tmp/slideshow.XXXXXX)
            convert "${left}" "${right}" +append "${join}.png"
            rm -f "${left}" "${right}"
            mv "${join}.png" "${left}"
        done
    fi

    # resize to screen
    ls -1 *.png | while read file ; do
        mogrify -resize "${SCREEN_RES}" \
                -background black \
                -gravity center \
                -extent "${SCREEN_RES}" "${file}"
    done

    # copy files to target directory
    rm -f ${SLIDESHOW_DIR}/*.png
    cp *.png ${SLIDESHOW_DIR}

    # run slideshow
    if [ "${FEH_PID}" ] ; then
        kill -USR1 ${FEH_PID}
    else
        feh -F -Y -N --slideshow-delay "${SLIDESHOW_DELAY}" "${SLIDESHOW_DIR}" &
        FEH_PID=$!
    fi

    # wait for X minutes
    delay=$((${SLIDESHOW_LENGTH} * 60))
    sleep ${delay}
done