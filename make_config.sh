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

# Get config for fw.sh script from LMS (lms.org.pl) data base.
# Currently get config for nat11, nat1n, public_ip module of fw.sh script.

. ./fw.conf
confdir=./conf

# Exec command methods
# On remote host
# exec_cmd="ssh $sshurl"
# on local host
exec_cmd="eval"

files_prefix=""

function db_cmd {
dburl="mysql -s -u $lms_dbuser $lms_db"

if [ "$1" = "dbquery" ] && [ "$dbquery" != "" ]; then
    $exec_cmd $dburl -e \"$dbquery\" > /dev/null
    if [ $? -eq 0 ]; then
	$exec_cmd $dburl -e \"$dbquery\"
    else
	echo "error"
	exit 
    fi
fi
}


###Get all variables with values of fw section from LMS uiconfig table.
###SELECT var,value FROM uiconfig WHERE section='fw'

# LMS hosts groups names
# Group for hosts with public ip address (forward only without NAT).
dbquery="SELECT value FROM uiconfig WHERE section='fw' AND var='forwarded_nodegroup_name';"
forwarded_group_name=$(db_cmd dbquery)

# Group for hosts which ip address is translated by method NAT 1-1.
dbquery="SELECT value FROM uiconfig WHERE section='fw' AND var='nat_11_nodegroup_name';"
nat_11_group_name=$(db_cmd dbquery)

# Group for hosts which ip address is translated by method NAT 1-n.
dbquery="SELECT value FROM uiconfig WHERE section='fw' AND var='nat_1n_nodegroups_rootname';"
nat_1n_groups_rootname=$(db_cmd dbquery)

# List of hosts with public ip address
cp /dev/null $confdir/"$files_prefix"$public_ip_file
for host_status in {0..1}; do
    if [ "$host_status" = "1" ]; then
        status="grantedhost"
    elif [ "$host_status" = "0" ]; then
        status="deniedhost"
    fi
    dbquery="SELECT INET_NTOA(ipaddr),INET_NTOA(ipaddr_pub) FROM nodegroupassignments nga JOIN nodes n ON nga.nodeid=n.id AND n.access=$host_status AND nga.nodegroupid=(SELECT id FROM nodegroups WHERE name='$forwarded_group_name');"
    db_cmd dbquery | while read ip ip_pub; do echo $status $ip; done >> $confdir/"$files_prefix"$public_ip_file
done


# List of ip address of hosts which ip address is translated by method NAT 1-1.
cp /dev/null $confdir/"$files_prefix"$nat_11_file
for host_status in {0..1}; do
    if [ "$host_status" = "1" ]; then
        status="grantedhost"
    elif [ "$host_status" = "0" ]; then
        status="deniedhost"
    fi
    dbquery="SELECT INET_NTOA(ipaddr),INET_NTOA(ipaddr_pub) FROM nodegroupassignments nga JOIN nodes n ON nga.nodeid=n.id AND n.access=$host_status AND nga.nodegroupid=(SELECT id FROM nodegroups WHERE name='$nat_11_group_name');"
    db_cmd dbquery | while read ip ip_pub; do echo $status $ip $ip_pub; done >> $confdir/"$files_prefix"$nat_11_file
done


#List of ip address of hosts which ip address is translated by method NAT 1-n.
dbquery="SELECT id FROM nodegroups WHERE name like '$nat_1n_groups_rootname%';"
nat_1n_nodegroups_id=$(db_cmd dbquery)
cp /dev/null $confdir/"$files_prefix"$nat_1n_ip_file

for item in $nat_1n_nodegroups_id; do
    dbquery="SELECT name FROM nodegroups WHERE id=$item;"
    nat_1n_nodegroup_name=$(db_cmd dbquery)
    nat_1n_nodegroup_ip=$(echo $nat_1n_nodegroup_name | cut -c 9-)
#    nat_1n_nodegroup_file=$(echo $nat_1n_nodegroup_name | cut -c -8)
#    echo fw_$nat_1n_nodegroup_file"ip"$item
    cp /dev/null $confdir/"$files_prefix"fw_$nat_1n_nodegroup_name
    echo "Create IP address list file "$files_prefix"fw_$nat_1n_nodegroup_name for NAT IP address $nat_1n_nodegroup_ip"
    echo ""$files_prefix"fw_$nat_1n_nodegroup_name $nat_1n_nodegroup_ip" >> $confdir/"$files_prefix"$nat_1n_ip_file
    for host_status in {0..1}; do
        if [ "$host_status" = "1" ]; then
            status="grantedhost"
        elif [ "$host_status" = "0" ]; then
            status="deniedhost"
        fi
        dbquery="SELECT INET_NTOA(n.ipaddr) FROM nodegroupassignments nga JOIN nodes n ON nga.nodeid=n.id AND n.access=$host_status AND nga.nodegroupid=$item;"
        db_cmd dbquery | while read ip; do echo $status $ip; done >> $confdir/"$files_prefix"fw_$nat_1n_nodegroup_name
    done
done