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

###Get all variables with values of fw section from LMS uiconfig table.
###SELECT var,value FROM uiconfig WHERE section='fw'

# LMS hosts groups names
# Group for hosts with public ip address (forward only without NAT).
forward_group_name="public_ip"
#dbquery="SELECT value FROM uiconfig WHERE section='fw' AND var='forward_nodegroup_name';"
#dburl="mysql -s -u $lms_dbuser $lms_db -e \"$dbquery\""
#forward_group_name=$($exec_cmd "$dburl")


# Group for hosts which ip address is translated by method NAT 1-1.
nat11_group_name="nat_1-1"
#dbquery="SELECT value FROM uiconfig WHERE section='fw' AND var='nat_11_nodegroup_name';"
#dburl="mysql -s -u $lms_dbuser $lms_db -e \"$dbquery\""
#nat_11_group_name=$($exec_cmd "$dburl")


# Group for hosts which ip address is translated by method NAT 1-n.
nat_1n_groups_rootname="nat_1-n_%"
#dbquery="SELECT value FROM uiconfig WHERE section='fw' AND var='nat_1n_nodegroups_rootname';"
#dburl="mysql -s -u $lms_dbuser $lms_db -e \"$dbquery\""
#nat_1n_groups_rootname=$($exec_cmd "$dburl")

nat_1n_ip_group_name="nat_1-n"
#dbquery="SELECT value FROM uiconfig WHERE section='fw' AND var='nat_1n_ip_group_name';"
#dburl="mysql -s -u $lms_dbuser $lms_db -e \"$dbquery\""
#nat_1n_ip_group_name=$($exec_cmd "$dburl")

routed_group_name="routed_ip"
#dbquery="SELECT value FROM uiconfig WHERE section='fw' AND var='forward_nodegroup_name';"
#dburl="mysql -s -u $lms_dbuser $lms_db -e \"$dbquery\""
#routed_group_name=$($exec_cmd "$dburl")



# List of hosts with public ip address
cp /dev/null $confdir/"$files_prefix"$public_ip_file
for host_status in {0..1}; do
    if [ "$host_status" = "1" ]; then
        status="grantedhost"
    elif [ "$host_status" = "0" ]; then
        status="deniedhost"
    fi
    dbquery="SELECT INET_NTOA(ipaddr),INET_NTOA(ipaddr_pub) FROM nodegroupassignments nga JOIN nodes n ON nga.nodeid=n.id AND n.access=$host_status AND nga.nodegroupid=(SELECT id FROM nodegroups WHERE name='$forward_group_name');"
    dburl="mysql -s -u $lms_dbuser $lms_db -e \"$dbquery\""
    $exec_cmd "$dburl"| while read ip ip_pub; do echo $status $ip; done >> $confdir/"$files_prefix"$public_ip_file
done


# List of ip address of hosts which ip address is translated by method NAT 1-1.
cp /dev/null $confdir/"$files_prefix"$nat_11_file
for host_status in {0..1}; do
    if [ "$host_status" = "1" ]; then
        status="grantedhost"
    elif [ "$host_status" = "0" ]; then
        status="deniedhost"
    fi
    dbquery="SELECT INET_NTOA(ipaddr),INET_NTOA(ipaddr_pub) FROM nodegroupassignments nga JOIN nodes n ON nga.nodeid=n.id AND n.access=$host_status AND nga.nodegroupid=(SELECT id FROM nodegroups WHERE name='$nat11_group_name');"
    dburl="mysql -s -u $lms_dbuser $lms_db -e \"$dbquery\""
    $exec_cmd "$dburl"| while read ip ip_pub; do echo $status $ip $ip_pub; done >> $confdir/"$files_prefix"$nat_11_file
done


#List of ip address of hosts which ip address is translated by method NAT 1-n.
dbquery="SELECT id FROM nodegroups WHERE name like '$nat_1n_groups_rootname';"
dburl="mysql -s -u $lms_dbuser $lms_db -e \"$dbquery\""
nat_1n_nodegroups_id=$($exec_cmd "$dburl")
cp /dev/null $confdir/"$files_prefix"$nat_1n_ip_file

for item in $nat_1n_nodegroups_id; do
    dbquery="SELECT name FROM nodegroups WHERE id=$item;"
    dburl="mysql -s -u $lms_dbuser $lms_db -e \"$dbquery\""
    nat_1n_nodegroup_name=$($exec_cmd "$dburl")
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
        dburl="mysql -s -u $lms_dbuser $lms_db -e \"$dbquery\""
#       $exec_cmd "$dburl"| while read ip; do echo $status $ip $nat_1n_nodegroup_ip; done > $confdir/"$files_prefix"fw_$nat_1n_nodegroup_name
        $exec_cmd "$dburl"| while read ip; do echo $status $ip; done >> $confdir/"$files_prefix"fw_$nat_1n_nodegroup_name
    done
done
