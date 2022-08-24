#!/bin/bash
#
# PI DISPLAY SLIDESHOW INSTALL
#
# Version 0.1.9
#
# Usage:
#   install.sh [ target-directory [ target-user ] ]
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

# error handler function
function error() {
    echo "Error: $@" >&2
    exit 1
}

# check for root user
[ "${EUID}" -eq 0 ] || error "Please run installer as root"

# install configuration variables
TARGET_DIR="${1:-/slideshow}"
TARGET_USER="${2:-pi}"

# setup target directory
if [ ! -d ${TARGET_DIR} ] ; then
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
install -m 755 slideshow.sh ${TARGET_DIR}
install -m 644 -o ${TARGET_USER} slideshow.ini ${TARGET_DIR}

# create empty logfile
LOGFILE="/var/log/slideshow.log"
touch ${LOGFILE}
chown ${TARGET_USER} ${LOGFILE}

# update PATH in profile
cat <<EOF > /etc/profile.d/slideshow.sh
# PI DISPLAY SLIDESHOW PROFILE
# Copyright 2022 by Andrew Donald Kennedy
# Licensed under the Apache Software License, Version 2.0 

# add pi-display-slideshow directory to the PATH
PATH=\${PATH}:${TARGET_DIR}
export PATH
EOF

# add slideshow to autostart
AUTOSTART="/home/${TARGET_USER}/.config/lxsession/LXDE-pi/autostart"
mkdir -p $(dirname ${AUTOSTART})
cat <<EOF >> ${AUTOSTART}
@${TARGET_DIR}/slideshow.sh
EOF
chown ${TARGET_USER} ${AUTOSTART}
