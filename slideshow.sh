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

# cleanup on exit
trap cleanup KILL STOP EXIT

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
#SCREEN_RES="${SCREEN_RES:-$(system_profiler SPDisplaysDataType | grep Resolution | cut -d:  -f2 | cut -d\  -f2,4 | tr ' ' 'x')}"
SCREEN_X=$(echo ${SCREEN_RES} | cut -dx -f1)
SCREEN_Y=$(echo ${SCREEN_RES} | cut -dx -f2)

# setup directory
SLIDESHOW_DIR="${SLIDESHOW_DIR:-/tmp/posters}"
mkdir -p ${SLIDESHOW_DIR}

# slideshow logging
FEH_LOG="${FEH_LOG:-$(mktemp -u /tmp/slideshow.XXXXXX).log}"
LOGFILE="${LOGFILE:-/var/log/slideshow.log}"
[ "${DEBUG}" ] || LOGFILE="/dev/null"

# cleanup function
function cleanup() {
    log INFO "Cleanup on exit"
    cd /tmp
    rm -rf "/tmp/slideshow.*"
    [ "${FEH_PID}" ] && kill -9 ${FEH_PID}
}

# error handler function
function error() {
    log ERROR "$@"
}

# debug message function
function debug() {
    [ "${DEBUG}" ] && log DEBUG "$@"
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
    log INFO "Running slideshow process"
    feh -F -Y -N ${QUIET} \
            --slideshow-delay "${SLIDESHOW_DELAY}" \
            --randomize \
            "${SLIDESHOW_DIR}" >> ${FEH_LOG} 2>&1 &
    FEH_PID=$!
    debug "Slideshow PID is ${FEH_PID} logging at ${FEH_LOG}"
}

# turn off screen blanking
xset s off
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
    wget ${QUIET} ${DROPBOX_URL} -O ${tmpfile}.zip 2>&1 | tee -a ${LOGFILE} ||
            error "Failed to download from Dropbox"

    # extract files from archive
    tmpdir=$(mktemp -d /tmp/slideshow.XXXXXX)
    cd ${tmpdir}
    [ "${DEBUG}" ] || QUIET="-qq"
    unzip ${QUIET} -b ${tmpfile}.zip 2>&1 | tee -a ${LOGFILE}
    rm -f ${tmpfile}.zip

    # remove spaces etc from filenames
    log INFO "Fixing filenames"
    find . -maxdepth 1 -type f | while read file ; do
        fixed=$(echo "${file}" | tr " \&\:\|\'_" "-")
        if [ "${file}" != "${fixed}" ] ; then
            mv "${file}" "${fixed}"
            debug "Renamed to ${fixed}"
        fi
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
            pdftoppm ${QUIET} -singlefile -f 1 -png "${file}" "${filename}" 2>&1 | tee -a ${LOGFILE} ||
                    error "Converting ${file} from PDF failed"
            rm -f "${file}"
        elif [ "${extension}" != "png" ] ; then
            [ "${DEBUG}" ] || QUIET="-quiet"
            debug "Converting to PNG"
            convert ${QUIET} "${file}" "${filename}.png" 2>&1 | tee -a ${LOGFILE} ||
                    error "Converting ${file} to PNG failed"
            rm -f "${file}"
        fi
    done

    # rotate 90 degrees if required
    if ${SLIDESHOW_ROTATE} ; then
        ls -1 *.png | while read file ; do
            [ "${DEBUG}" ] || QUIET="-quiet"
            debug "Rotating ${file}"
            mogrify ${QUIET} -rotate "-90" "${file}" 2>&1 | tee -a ${LOGFILE} || (
                error "Failed to rotate ${file}"
                rm -f "${file}"
            )
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
                (   mogrify ${QUIET} -geometry "x${SCREEN_Y}" "${left}"
                    mogrify ${QUIET} -geometry "x${SCREEN_Y}" "${right}"
                ) 2>&1 | tee -a ${LOGFILE} || error "Failed to resize files" && (
                    # join left and right images
                    join=$(mktemp -u /tmp/slideshow.XXXXXX)
                    (   convert ${QUIET} "${left}" "${right}" +append "${join}.png" 2>&1 | tee -a ${LOGFILE}
                        mv "${join}.png" "${left}"
                    ) || error "Failed joining ${left} to ${right}"
                )
                rm -f "${left}" "${right}"
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
                -extent "${SCREEN_RES}" "${file}" 2>&1 | tee -a ${LOGFILE} || (
            error "Failed to resize to ${SCREEN_RES}"
            rm -f "${file}"
        )
    done

    # copy files to slideshow directory
    log INFO "Copying to ${SLIDESHOW_DIR}"
    rm -f ${SLIDESHOW_DIR}/*.png
    cp *.png ${SLIDESHOW_DIR}
    cd ${SLIDESHOW_DIR}
    rm -rf ${tmpdir}

    # start or restart slideshow
    if [ "${FEH_PID}" ] && ps -p "${FEH_PID}" > /dev/null 2>&1 ; then
        debug "Signalling slideshow PID ${FEH_PID}"
        kill -USR1 ${FEH_PID}
    else
        slideshow
    fi

    # wait for X minutes
    delay=$((${SLIDESHOW_LENGTH} * 60))
    log INFO "Waiting for ${delay} seconds"
    sleep ${delay}
done
