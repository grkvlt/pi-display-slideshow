#!/bin/bash
#
# PI DISPLAY SLIDESHOW
#
# Raspberry PI slideshow for displaying posters on a portrait mode
# monitor. The posters should be available as a publicly readable
# Dropbox folder, provided as a download URL to the script.
#
# Version 0.1.8
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

# debugging
#set -x

# load configuration file
CONFIG_FILE="$(dirname $0)/$(basename $0 .sh).ini"
source=${1:-${CONFIG_FILE}}
[ -f ${source} ] && . ${source}

# dropbox configuration
DROPBOX_URL="${DROPBOX_URL}"

# slideshow configuration
SLIDESHOW_LENGTH="${SLIDESHOW_LENGTH:-30}"
SLIDESHOW_DELAY="${SLIDESHOW_DELAY:-10}"
SLIDESHOW_ROTATE="${SLIDESHOW_ROTATE:-true}"
SLIDESHOW_JOIN="${SLIDESHOW_JOIN:-false}"

# get screen size
SCREEN_RES="${SCREEN_RES:-$(fbset | grep "^mode " | cut -d\" -f2)}"
SCREEN_X=$(echo ${SCREEN_RES} | cut -dx -f1)
SCREEN_Y=$(echo ${SCREEN_RES} | cut -dx -f2)

# setup directory
SLIDESHOW_DIR="${SLIDESHOW_DIR:-/tmp/posters}"
mkdir -p ${SLIDESHOW_DIR}

# slideshow logging
FEH_LOG="${FEH_LOG:-$(mktemp -u /tmp/slideshow.XXXXXX).log}"
LOGFILE="${LOGFILE:-/var/log/slideshow.log}"

# error handler function
function error() {
    log ERROR "$@"
    exit 1
}

# debug message function
function debug() {
    if [ "${DEBUG}" ] ; then
        log DEBUG "$@"
    fi
}

# logging function
function log() {
    LEVEL="$1"
    shift
    MESSAGE="$@"
    echo "${LEVEL} $(date +"%Y%m%d%H%M%S") ${MESSAGE}" | tee -a "${LOGFILE}"
}

# start slideshow process
function slideshow() {
    [ "${DEBUG}" ] || QUIET="--quiet" FEH_LOG="/dev/null"
    debug "Running slideshow process"
    feh -F -Y -N ${QUIET} \
            --slideshow-delay "${SLIDESHOW_DELAY}" \
            --randomize \
            "${SLIDESHOW_DIR}" >> ${FEH_LOG} 2>&1 &
    FEH_PID=$!
}

# turn off screen blanking
xset s off
xset -dpms
xset s noblank

# start slideshow if files in slideshow dir already
[ "${DEBUG}" ] || QUIET="-q"
if ( ls -1 "${SLIDESHOW_DIR}" | grep ${QUIET} "png" ) ; then
    slideshow
fi

# main slideshow display loop
while true ; do
    # download archive from dropbox
    [ "${DROPBOX_URL}" ] || error "Must set DROPBOX_URL to a valid download link"
    tmpfile=$(mktemp -u /tmp/slideshow.XXXXXX)
    [ "${DEBUG}" ] || QUIET="--quiet"
    wget ${QUIET} ${DROPBOX_URL} -O ${tmpfile}.zip || error "Failed to download from Dropbox"

    # extract files from archive
    tmpdir=$(mktemp -d /tmp/slideshow.XXXXXX)
    cd ${tmpdir}
    [ "${DEBUG}" ] || QUIET="-qq"
    unzip ${QUIET} -b ${tmpfile}.zip
    rm -f ${tmpfile}.zip

    # remove spaces etc from filenames
    debug "Fixing filenames"
    find . -maxdepth 1 -type f | while read file ; do
        fixed=$(echo "${file}" | tr " \:\-\'_" "-----")
        mv "${file}" "${fixed}"
    done

    # convert all file formats to png and rotate
    find . -maxdepth 1 -type f | while read file ; do
        # get name and extension
        extension="${file##*.}"
        filename="${file%.*}"
        debug "Processing ${file}"

        # convert to png
        if [ "${extension}" == "pdf" ] ; then
            [ "${DEBUG}" ] || QUIET="-q"
            debug "Converting from PDF"
            pdftoppm ${QUIET} -singlefile -f 1 -png "${file}" "${filename}" || error "Converting ${file} from PDF failed"
            rm -f "${file}"
        elif [ "${extension}" != "png" ] ; then
            [ "${DEBUG}" ] || QUIET="-quiet"
            debug "Converting to PNG"
            convert ${QUIET} "${file}" "${filename}.png" || error "Converting ${file} to PNG failed"
            rm -f "${file}"
        fi 
    done
        
    # rotate 90 degrees if required
    if ${SLIDESHOW_ROTATE} ; then
        ls -1 *.png | while read file ; do
            [ "${DEBUG}" ] || QUIET="-quiet"
            debug "Rotating ${file}"
            mogrify ${QUIET} -rotate "-90" "${file}" || error "Failed to rotate ${file}"
        done
    fi

    # otherwise join left/right pairs if required
    if ! ${SLIDESHOW_ROTATE} && ${SLIDESHOW_JOIN} ; then
        ls -1 *.png | xargs -n 2 echo | while read left right ; do
            # if two files are available
            if [ -f "${right}" ] ; then
                [ "${DEBUG}" ] || QUIET="-quiet"
                debug "Joining ${left} and ${right}"

                # resize left and right to fit screen height
                mogrify ${QUIET} -geometry "x${SCREEN_Y}" "${left}" || error "Failed to resize ${left}"
                mogrify ${QUIET} -geometry "x${SCREEN_Y}" "${right}" || error "Failed to resize ${right}"

                # join left and right images
                join=$(mktemp -u /tmp/slideshow.XXXXXX)
                convert ${QUIET} "${left}" "${right}" +append "${join}.png" || error "Failed joining ${left} to ${right}"
                rm -f "${left}" "${right}"
                mv "${join}.png" "${left}"
            fi
        done
    fi

    # resize to screen
    ls -1 *.png | while read file ; do
        [ "${DEBUG}" ] || QUIET="-quiet"
        debug "Resizing ${file}"
        mogrify ${QUIET} \
                -resize "${SCREEN_RES}" \
                -background black \
                -gravity center \
                -extent "${SCREEN_RES}" "${file}" || error "Failed to resize to ${SCREEN_RES}"
    done

    # copy files to target directory
    rm -f ${SLIDESHOW_DIR}/*.png
    cp *.png ${SLIDESHOW_DIR}

    # start or restart slideshow
    if [ "${FEH_PID}" ] && ps -p "${FEH_PID}" > /dev/null 2>&1 ; then
        kill -USR1 ${FEH_PID}
    else
        slideshow
    fi

    # wait for X minutes
    delay=$((${SLIDESHOW_LENGTH} * 60))
    sleep ${delay}
done
