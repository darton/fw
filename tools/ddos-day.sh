#!/bin/bash

day_of_month=$(date +%d)
fw_wan_ddos_source_log=/var/log/ddos/fw_wan_ddos_source.log

for element in $(cat $fw_wan_ddos_source_log |awk '{print $3}' |sort -u); do
        element_counter=$(grep -c $element $fw_wan_ddos_source_log)
        if [  $element_counter -ge 3 ]; then
		echo $element
		#grep -v $element $fw_wan_ddos_source_log > /tmp/fw_wan_ddos_source_log.tmp
		#cp /tmp/fw_wan_ddos_source_log.tmp $fw_wan_ddos_source_log
		ipset add fw_time_blacklist $element timeout 86400
        fi
done
mv $fw_wan_ddos_source_log $fw_wan_ddos_source_log.$day_of_month
touch $fw_wan_ddos_source_log

exit

