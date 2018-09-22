#!/bin/bash

. ./fw.conf
confdir=./conf

#Get config method from remote host
#get_cmd="ssh $sshurl"
#Get config method from localhost
get_cmd="eval"

files_prefix=""

forward_group_name="public_ip"
nat11_group_name="nat_1-1"
nat_1n_groups_name="nat_1-n_%"

#IP address list of host belong to LMS group public_ip
cp /dev/null $confdir/"$files_prefix"$public_ip_file
for host_status in {0..1}; do
    if [ "$host_status" = "1" ]; then
        status="grantedhost"
    elif [ "$host_status" = "0" ]; then
        status="deniedhost"
    fi

    dbquery="SELECT INET_NTOA(ipaddr),INET_NTOA(ipaddr_pub) FROM nodegroupassignments nga JOIN nodes n ON nga.nodeid=n.id AND n.access=$host_status AND nga.nodegroupid=(SELECT id FROM nodegroups WHERE name='$forward_group_name');"
    dburl="mysql -s -u $lms_dbuser $lms_db -e \"$dbquery\""

    $get_cmd "$dburl"| while read ip ip_pub; do echo $status $ip; done >> $confdir/"$files_prefix"$public_ip_file
done


#IP address list of host belong to LMS group nat_1-1
cp /dev/null $confdir/"$files_prefix"$nat_11_file
for host_status in {0..1}; do
    if [ "$host_status" = "1" ]; then
        status="grantedhost"
    elif [ "$host_status" = "0" ]; then
        status="deniedhost"
    fi

    dbquery="SELECT INET_NTOA(ipaddr),INET_NTOA(ipaddr_pub) FROM nodegroupassignments nga JOIN nodes n ON nga.nodeid=n.id AND n.access=$host_status AND nga.nodegroupid=(SELECT id FROM nodegroups WHERE name='$nat11_group_name');"
    dburl="mysql -s -u $lms_dbuser $lms_db -e \"$dbquery\""

    $get_cmd "$dburl"| while read ip ip_pub; do echo $status $ip $ip_pub; done >> $confdir/"$files_prefix"$nat_11_file
done


#IP address list of host belong to LMS groups nat_1n_*
dbquery="SELECT id FROM nodegroups WHERE name like '$nat_1n_groups_name';"
dburl="mysql -s -u $lms_dbuser $lms_db -e \"$dbquery\""
nat_1n_nodegroups_id=$($get_cmd "$dburl")

cp /dev/null $confdir/"$files_prefix"$nat_1n_ip_file

for item in $nat_1n_nodegroups_id; do
    dbquery="SELECT name FROM nodegroups WHERE id=$item;"
    dburl="mysql -s -u $lms_dbuser $lms_db -e \"$dbquery\""
    nat_1n_nodegroup_name=$($get_cmd "$dburl")
    nat_1n_nodegroup_ip=$(echo $nat_1n_nodegroup_name | cut -c 9-)

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

#       $get_cmd "$dburl"| while read ip; do echo $status $ip $nat_1n_nodegroup_ip; done > $confdir/"$files_prefix"fw_$nat_1n_nodegroup_name
        $get_cmd "$dburl"| while read ip; do echo $status $ip; done >> $confdir/"$files_prefix"fw_$nat_1n_nodegroup_name
    done
done
