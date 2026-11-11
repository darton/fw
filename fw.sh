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

PATH=/sbin:/usr/sbin/:/bin:/usr/bin:$PATH

FW_CONFIG_TEMP_DIR=$(mktemp -d -p /dev/shm/ FW_CONFIG.XXXX)
trap 'rm -rf ${FW_CONFIG_TEMP_DIR}' INT TERM EXIT

current_time=$(date +"%F %T.%3N%:z")

SCRIPT_NAME="${BASH_SOURCE[0]##*/}"

MESSAGE="Program must be run as root"
if [[ $EUID -ne 0 ]]; then
    logger -p "error" -t "${SCRIPT_NAME}" "${MESSAGE}"
    echo "${MESSAGE}"
    exit 1
fi


SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P) || {
    MESSAGE="Cannot determine the script directory"
    logger -p "error" -t "${SCRIPT_NAME}" "${MESSAGE}"
    echo "${MESSAGE}"
    exit 1
}

FW_CONF_PATH="${SCRIPT_DIR}/fw.conf"
FW_FUNCTIONS_PATH="$SCRIPT_DIR/fwfunctions"

#Load fw.sh config file
MESSAGE="Can not load ${FW_CONF_PATH}"
if ! source "${FW_CONF_PATH}"; then
    logger -p error -t "${SCRIPT_NAME}" "${MESSAGE}"
    echo "$MESSAGE"
    exit 1
fi

if [ "$DEBUG" == "no" ]; then
    logdir="/dev"
    logfile="null"
fi

#Load fwfunction
MESSAGE="Can not load ${FW_FUNCTIONS_PATH}"
if ! source "${FW_FUNCTIONS_PATH}"; then
    logger -p error -t "${SCRIPT_NAME}" "${MESSAGE}"
    echo "${MESSAGE}"
    exit 1
fi

####Makes necessary directories and files####
init_fw

#####Main program####
case "$1" in

    'start')
        start
    ;;
    'stop')
        stop
    ;;
    'status')
        fwstatus
    ;;
    'restart')
        stop
        start
    ;;
    'reload')
        newreload
    ;;
    'lmsd')
        lmsd
    ;;
    'shaper_stop')
        shaper_cmd stop
    ;;
    'shaper_start')
        shaper_cmd start
    ;;
    'shaper_restart')
        get_shaper_config
        shaper_cmd restart
    ;;
    'shaper_stats')
        shaper_cmd stats
    ;;
    'shaper_status')
        shaper_cmd status
    ;;
    'maintenance-on')
        maintenance-on
    ;;
    'maintenance-off')
        maintenance-off
    ;;
    *)
        menu_help
    ;;
esac

