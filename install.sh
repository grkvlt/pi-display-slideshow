#!/bin/bash
#
# PI DISPLAY SLIDESHOW INSTALL
#
# Version 0.1.2
#
# Usage:
#   install.sh target-directory
#
# Andrew Donald Kennedy
# Copyright 2022 by BEHOLDER

# check for root user
if [ "${EUID}" -ne 0 ]
  then echo "Error: Please run installer as root" >&2
  exit
fi

# setup target directory
TARGET_DIR="$1"
if [ -z "${TARGET_DIR}" ] ; then
    echo "Error: Must specify target directory as first argument" >&2
    exit
elif [ ! -d ${TARGET_DIR} ] ; then
    mkdir -p ${TARGET_DIR}
    chmod 755 ${TARGET_DIR}
fi

# install packages
apt-get update
apt-get --assume-yes install \
        wget \
        unzip \
        poppler-utils \
        imagemagick \
        feh

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