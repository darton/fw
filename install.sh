#!/bin/bash

#  (C) Copyright Dariusz Kowalczyk
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License Version 2 as
#  published by the Free Software Foundation.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.

#Config
LAN=eth0
WAN=eth1
installdir=/opt/gateway
scriptsdir="${installdir}"/scripts


#Main program
[[ -d "${scriptsdir}" ]] || mkdir -p "${scriptsdir}"

cp ./fw.sh "${scriptsdir}"/fw.sh
cp ./fw.conf "${scriptsdir}"/fw.conf
cp ./fwfunctions "${scriptsdir}"/fwfunctions
chmod u+x "${scriptsdir}"/fw.sh
echo "export PATH=$PATH:$scriptsdir" >> /root/.bash_profile
source /root/.bash_profile

set_env_var() {
    local key="$1"
    local value="$2"
    local file="$3"

    if grep -q "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        echo "${key}=${value}" >> "$file"
    fi
}

set_env_var LAN "${LAN}" /etc/environment
set_env_var WAN "${WAN}" /etc/environment
. /etc/environment

