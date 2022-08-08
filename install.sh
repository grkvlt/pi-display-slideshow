#!/bin/bash
#
# PI DISPLAY SLIDESHOW INSTALL
#
# Version 0.1.3
#
# Usage:
#   install.sh target-directory
#
# Copyright 2022 by Andrew Donald Kennedy
#
# Licensed under the Apache Software License, Version 2.0 

# error handler function
function error() {
    echo "Error: $@" >&2
    exit 1
}

# check for root user
[ "${EUID}" -eq 0 ] || error "Please run installer as root"

# setup target directory
TARGET_DIR="$1"
if [ -z "${TARGET_DIR}" ] ; then
    error "Must specify target directory as first argument"
elif [ ! -d ${TARGET_DIR} ] ; then
    mkdir -p ${TARGET_DIR}
    chmod 755 ${TARGET_DIR}
fi

# install packages
(   apt-get -qq update ;
    apt-get -qq --assume-yes install \
            wget \
            unzip \
            poppler-utils \
            imagemagick \
            feh
) || error "Package installation failed"

# copy files to target directory
mkdir -p ${TARGET_DIR}
install -m 755 slideshow.sh ${TARGET_DIR}
install -m 644 slideshow.ini ${TARGET_DIR}

# update PATH in profile
cat <<EOF >> /etc/profile
####
# add pi-display-slideshow directory to the PATH
PATH=\${PATH}:${TARGET_DIR}
export PATH
####
EOF