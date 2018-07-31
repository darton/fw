#!/bin/bash

#  (C) Copyright 2017 Dariusz Kowalczyk
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

#Paths to config dirs
confdir=/opt/gateway/conf
oldconfdir=/opt/gateway/oldconf

#Path to log
logdir=/var/log
logfile=fw.log

#Names of config files
nat_11_file=fw_nat_1-1
nat_1n_ip_file=fw_nat_1-n
public_ip_file=fw_public_ip
routed_nets_file=fw_routed_ip
lan_banned_dst_ports_file=fw_lan_banned_dst_ports

#Source of config files
scpurl=root@10.10.10.10:/opt/gateway

#URL to LMS database server.
sshurl=root@10.10.10.10

#Warning: user lmsd_reload has SELECT privileges to lms.hosts table only with no password
dburl="mysql -s -u lmsd_reload lms -e \"select reload from hosts where id=4\""

#PROXY IP ADDRESS
proxy_ip=192.168.1.254

#Ethernet interfaces
#WAN=$(ip r|grep default |awk '{print $5}')
WAN=enp2s0
LAN=enp3s0
MGMT=eno1

####Makes necessary config directories and files####
[[ -d /run/fw-sh/ ]] || mkdir /run/fw-sh
[[ -f /run/fw-sh/maintenance.pid ]] || echo 0 > /run/fw-sh/maintenance.pid


[[ -d $confdir ]] || mkdir -p $confdir
[[ -d $oldconfdir ]] || mkdir -p $oldconfdir

[[ -f $confdir/$nat_11_file ]] || touch $confdir/$nat_11_file
[[ -f $confdir/$nat_1n_ip_file ]] || touch $confdir/$nat_1n_ip_file
[[ -f $confdir/$public_ip_file ]] || touch $confdir/$public_ip_file
[[ -f $confdir/$routed_nets_file ]] || touch $confdir/$routed_nets_file
[[ -f $confdir/$lan_banned_dst_ports_file ]] || touch $confdir/$lan_banned_dst_ports_file

current_time=$(date '+%Y-%m-%d %H:%M:%S')

source /opt/gateway/scripts/fwfunctions

    lmsd_reload_new ()
    {
        #Sprawdza czy ustawiony jest status przeładowania dla demona lmsd na maszynie z LMS
        lms_status=`ssh $sshurl "$dburl"| grep -v reload`
    if [ $lms_status = 1 ]; then
        echo "$current_time - Status przeładowania lmsd został ustawiony" >> $logdir/$logfile
        ssh $sshurl '/usr/local/lmsd/bin/lmsd -q -h 127.0.0.1:3306 -H newgateway -u lmsd_reload -d lms'
        echo "$current_time - Wykonałem reload lmsd na zdalnej maszynie" >> $logdir/$logfile
        sleep 10
        echo "$current_time - Pobieram konfigurację z LMS" >> $logdir/$logfile
        get_config
        echo "$current_time - Sprawdzam czy konieczny jest restart czy wystarczy reload" >> $logdir/$logfile
#        nat_11_current_sha1sum=$(cat $oldconfdir/$nat_11_file |sort |sha1sum)
#        nat_11_new_sha1sum=$(cat $confdir/$nat_11_file |sort |sha1sum)
        nat_1n_current_sha1sum=$(cat $oldconfdir/$nat_1n_ip_file |sort |sha1sum)
        nat_1n_new_sha1sum=$(cat $confdir/$nat_1n_ip_file |sort |sha1sum)

#        if [ "$nat_11_current_sha1sum" != "$nat_11_new_sha1sum" ] || [ "$nat_1n_current_sha1sum" != "$nat_1n_new_sha1sum" ]
        if  [ "$nat_1n_current_sha1sum" != "$nat_1n_new_sha1sum" ]; then
            echo "$current_time - Wykonuję reload firewalla przez zmianę nat_1n_ip_file" >> $logdir/$logfile
            #restart
            newreload
        else
            echo "$current_time - Wykonuję reload firewalla przez zmianę innych plików" >> $logdir/$logfile
            newreload
        fi

    else
        echo "Status przeładowania lmsd nie został ustawiony, kończę program."
    exit
    fi
    }

    maintenance-on ()
    {
        mpid=`cat /run/fw-sh/maintenance.pid`
        if [ $mpid = 1 ]; then
            echo ""
            echo "Jesteś już w trybie diagnostycznym !"
            echo "Aby wyjśc z trybu diagnostycznego wykonaj:"
            echo ""
            echo "/etc/init.d/fw.sh maintenance-off"
            echo ""
            exit
        else
        echo ""
        echo "$current_time - Włączam tryb diagnostyczny" >> $logdir/$logfile
        echo ""
        static_routing_down
        firewall_down
        htb_cmd stop
        destroy_all_hashtables
        fw_cron stop
        ifup $MGMT
        ifdown $WAN
        ifdown $LAN
        echo 1 > /run/fw-sh/maintenance.pid
        fi
    }

    maintenance-off ()
    {
        mpid=`cat /run/fw-sh/maintenance.pid`
        if [ $mpid = 0 ]; then
            echo ""
            echo "Wyszedłeś już z trybu diagnostycznego !"
            echo ""
            exit
        else
        echo "$current_time - Wyłączam tryb diagnostyczny" >> $logdir/$logfile
        ifup $LAN
        ifup $WAN
        static_routing_up
        create_fw_hashtables
        load_fw_hashtables
        firewall_up
        htb_cmd start
        dhcpd_restart
        fw_cron start
        echo 0 > /run/fw-sh/maintenance.pid
        ifdown $MGMT
        fi
    }

    stop ()
    {
        echo "$current_time - Firewall Stop" >> $logdir/$logfile
        fw_cron stop
        htb_cmd stop
        static_routing_down
        firewall_down
        destroy_all_hashtables
    }

    start ()
    {
        #tuned-adm profile network-latency
        stop
        echo "$current_time - Firewall Start" >> $logdir/$logfile
        static_routing_up
        create_fw_hashtables
        load_fw_hashtables
        firewall_up
        htb_cmd start
        dhcpd_restart
        fw_cron start
    }

    lmsd ()
    {
        lmsd_reload_new
    }

    newreload ()
    {
        echo "Firewall newreload"
        echo "$current_time - Firewall newreload" >> $logdir/$logfile
        load_fw_hashtables
        modify_nat11_fw_rules
        modify_nat1n_fw_rules
        htb_cmd restart
        dhcpd_restart

    }

    restart ()
    {
        echo "Firewall restart"
        echo "$current_time - Firewall restart" >> $logdir/$logfile
        htb_cmd stop
        firewall_down
        destroy_all_hashtables
        create_fw_hashtables
        load_fw_hashtables
        firewall_up
        htb_cmd start
        dhcpd_restart
    }

    qos ()
    {
        get_qos_config
        htb_cmd restart
    }

#####Program główny####

case "$1" in

    'start')
        start
    ;;
    'stop')
        stop
    ;;
    'stats')
        stats
    ;;
    'status')
        fwstatus
    ;;
    'restart')
        start
    ;;
    'reload')
        newreload
    ;;
    'lmsd')
        lmsd
    ;;
    'qos')
        qos
    ;;
    'maintenance-on')
        maintenance-on
    ;;
    'maintenance-off')
        maintenance-off
    ;;

        *)
        echo -e "\nUsage: fw.sh start|stop|restart|reload|stats|lmsd|qos|status|maintenance-on|maintenance-off"
        echo "$current_time - fw.sh running without parameter OK" >> $logdir/$logfile
    ;;

esac
