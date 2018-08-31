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
installdir=/opt/gateway
scriptsdir=$installdir/scripts
confdir=$installdir/conf
oldconfdir=$installdir/oldconf

#Path to log
logdir=/var/log
logfile=fw.log

#Names of config files
nat_11_file=fw_nat_1-1
nat_1n_ip_file=fw_nat_1-n
public_ip_file=fw_public_ip
routed_nets_file=fw_routed_ip
blacklist_file=fw_blacklist
lan_banned_dst_ports_file=fw_lan_banned_dst_ports
shaper_file=fw_shaper_cfg
dhcp_conf_file=dhcpd.conf

#Source of config files
scpurl=root@10.10.10.10:/opt/gateway

#URL to LMS database server
sshurl=root@10.10.10.10

#PROXY IP ADDRESS
proxy_ip=10.10.10.254

#Warning: user lmsd_reload has SELECT privileges to lms.hosts table only with no password
dburl="mysql -s -u lmsd_reload lms -e \"select reload from hosts where id=4\""

#Ethernet interfaces
#WAN=$(ip r|grep default |awk '{print $5}')
WAN=enp2s0
LAN=enp3s0
MGMT=eno1

#Shaper configuration
IPT=iptables
TC=tc
BURST="burst 30k"
ISPRXLIMIT=470000kbit
ISPTXLIMIT=470000kbit
GW2LANLIMIT=1000000kbit
GW2WANLIMIT=100000kbit
DEFAULTLIMIT=128kbit

####Makes necessary config directories and files####
[[ -d /run/fw-sh/ ]] || mkdir /run/fw-sh
[[ -f /run/fw-sh/maintenance.pid ]] || echo 0 > /run/fw-sh/maintenance.pid
[[ -d $confdir ]] || mkdir -p $confdir
[[ -d $oldconfdir ]] || mkdir -p $oldconfdir

for param in $confdir $oldconfdir
do
[[ -f $param/$nat_11_file ]] || touch $param/$nat_11_file
[[ -f $param/$nat_1n_ip_file ]] || touch $param/$nat_1n_ip_file
[[ -f $param/$public_ip_file ]] || touch $param/$public_ip_file
[[ -f $param/$routed_nets_file ]] || touch $param/$routed_nets_file
[[ -f $param/$blacklist_file ]] || touch $param/$blacklist_file
[[ -f $param/$lan_banned_dst_ports_file ]] || touch $param/$lan_banned_dst_ports_file
[[ -f $param/$shaper_file ]] || touch $param/$shaper_file
[[ -f $param/$dhcp_conf_file ]] || touch $param/$dhcp_conf_file
done

[[ -f $logdir/$logfile ]] || touch $logdir/$logfile

current_time=$(date '+%Y-%m-%d %H:%M:%S')

source $scriptsdir/fwfunctions


    maintenance-on ()
    {
        mpid=`cat /run/fw-sh/maintenance.pid`
        if [ $mpid = 1 ]; then
            echo ""
    	    echo -e "Firewall maintenance is allready on \n"
            echo "To exit from maintenance mode run: /etc/init.d/fw.sh maintenance-off"
            exit
        else
        fw_cron stop
	htb_cmd stop
        static_routing_down
        firewall_down
        destroy_all_hashtables
        dhcpd_cmd stop
        ifup $MGMT
        ifdown $WAN
        ifdown $LAN
        echo 1 > /run/fw-sh/maintenance.pid
        fi
        echo ""
	echo -e "Firewall maintenance is on \n"
	echo "$current_time - Firewall maintenance is on" >> $logdir/$logfile
    }

    maintenance-off ()
    {
        mpid=`cat /run/fw-sh/maintenance.pid`
        if [ $mpid = 0 ]; then
            echo ""
	    echo -e "Firewall maintenance is allready off \n"
            exit
        else
        ifup $LAN
        ifup $WAN
        static_routing_up
        create_fw_hashtables
        load_fw_hashtables
        firewall_up
        htb_cmd start
        dhcpd_cmd start
        fw_cron start
        echo 0 > /run/fw-sh/maintenance.pid
        ifdown $MGMT
        fi
        echo ""
        echo -e "Firewall maintenance is off \n"
	echo "$current_time - Firewall maintenance is off" >> $logdir/$logfile
    }

    stop ()
    {
	echo "Firewall Stop"
	echo "$current_time - Firewall Stop" >> $logdir/$logfile
	fw_cron stop
	htb_cmd stop
	static_routing_down
	firewall_down
	destroy_all_hashtables
	echo "$current_time - Firewall Stop OK" >> $logdir/$logfile
    }

    start ()
    {
	#tuned-adm profile network-latency
	echo "Firewall Start"
	stop
	echo "$current_time - Firewall Start" >> $logdir/$logfile
        static_routing_up
        create_fw_hashtables
        load_fw_hashtables
        firewall_up
        htb_cmd start
        dhcpd_cmd start
        fw_cron start
	echo "$current_time - Firewall Start OK" >> $logdir/$logfile
    }

    newreload ()
    {
	echo "Firewall newreload"
	echo "$current_time - Firewall newreload" >> $logdir/$logfile
	load_fw_hashtables
	modify_nat11_fw_rules
	modify_nat1n_fw_rules
	htb_cmd restart
	dhcpd_cmd restart
	echo "$current_time - Firewall newreload OK" >> $logdir/$logfile
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
	dhcpd_cmd restart
	echo "$current_time - Firewall restart OK" >> $logdir/$logfile
    }

    qos ()
    {
	get_qos_config
	htb_cmd restart
    }

    lmsd ()
    {
        lmsd_reload
    }

    lmsd_reload ()
    {
	#Sprawdza czy ustawiony jest status przeładowania dla demona lmsd na maszynie z LMS
        lms_status=`ssh $sshurl "$dburl"| grep -v reload`
    if [ $lms_status = 1 ]; then
        echo "$current_time - Status przeładowania lmsd został ustawiony, wykonuje reload lmsd na zdalnej maszynie." >> $logdir/$logfile
        ssh $sshurl '/usr/local/lmsd/bin/lmsd -q -h 127.0.0.1:3306 -H newgateway -u lmsd_reload -d lms'
        echo "$current_time - Wykonałem reload lmsd na zdalnej maszynie, czekam 10s, aż lmsd stworzy nowe pliki konfiguracyjne" >> $logdir/$logfile
        sleep 10
	get_config
	newreload
    fi
    }

lmsd_reload_old ()
    {
#Sprawdza czy ustawiony jest status przeładowania dla demona lmsd na maszynie z LMS

        lms_status=`ssh $sshurl "$dburl"| grep -v reload`
    if [ $lms_status = 1 ]
    then
        echo "$current_time - Status przeładowania lmsd został ustawiony" >> /tmp/lms.status
        echo "$current_time - Wykonuję reload lmsd na zdalnej maszynie" >> /tmp/lms.status
        ssh $sshurl '/usr/local/lmsd/bin/lmsd -q -h 127.0.0.1:3306 -H newgateway -u lmsd_reload -d lms'
        echo "$current_time - Czekam 10 sekund na wygenerowanie nowych plików konfiguracyjnych" >> /tmp/lms.status
        sleep 10
        echo "$current_time - Pobieram konfigurację z LMS" >> /tmp/lms.status
        get_config
        echo "$current_time - Sprawdzam czy konieczny jest restart czy wystarczy reload" >> /tmp/lms.status
        nat_11_current_sha1sum=$(cat $oldconfdir/$nat_11_file |sort |sha1sum)
        nat_11_new_sha1sum=$(cat $confdir/$nat_11_file |sort |sha1sum)
        nat_1n_current_sha1sum=$(cat $oldconfdir/$nat_1n_ip_file |sort |sha1sum)
        nat_1n_new_sha1sum=$(cat $confdir/$nat_1n_ip_file |sort |sha1sum)

        if [ "$nat_11_current_sha1sum" != "$nat_11_new_sha1sum" ] || [ "$nat_1n_current_sha1sum" != "$nat_1n_new_sha1sum" ]; then
            restart
        else
            newreload
        fi
    else
        echo "Status przeładowania lmsd nie został ustawiony, kończę program."
    exit
    fi
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
        echo "$current_time - fw.sh running without parameter" >> $logdir/$logfile
    ;;

esac
