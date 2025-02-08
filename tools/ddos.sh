#!/bin/bash

ipset list fw_wan_ddos_source|tail -n +9 | (while read a1 a2 a3; do echo $( date '+%d-%m-%Y %H:%M:%S') $a1; done; )>>  /var/log/ddos/fw_wan_ddos_source.log
