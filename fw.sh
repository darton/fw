#!/usr/bin/env bash

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

#Load fw.sh config file
source $scriptsdir/fw.conf

current_time=$(date '+%Y-%m-%d %H:%M:%S')

if [[ $EUID -ne 0 ]]; then
  echo ""
  echo "Program must be run as root !"
  exit 1
fi

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

if [ "$DEBUG" == "no" ]; then
  logdir="/dev"
  logfile="null"
fi

#Load fwfunction 
source $scriptsdir/fwfunctions


    maintenance-on ()
    {
        mpid=$(cat /run/fw-sh/maintenance.pid)
        if [ $mpid = 1 ]; then
            echo ""
    	    echo -e "Firewall maintenance is allready on \n"
            echo "To exit from maintenance mode run: /etc/init.d/fw.sh maintenance-off"
            exit
        else
        fw_cron stop
	shaper_cmd stop
        static_routing_down
        firewall_down
        destroy_all_hashtables
        dhcpd_cmd stop
        ifup $MGMT
        #ifdown $WAN
        ifdown $LAN
        echo 1 > /run/fw-sh/maintenance.pid
        fi
        echo ""
	echo -e "Firewall maintenance is on \n"
	echo "$current_time - Firewall maintenance is on" >> $logdir/$logfile
    }

    maintenance-off ()
    {
        mpid=$(cat /run/fw-sh/maintenance.pid)
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
        shaper_cmd start
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
	shaper_cmd stop
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
        shaper_cmd start
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
	shaper_cmd restart
	dhcpd_cmd restart
	echo "$current_time - Firewall newreload OK" >> $logdir/$logfile
    }

    restart ()
    {
	echo "Firewall restart"
	echo "$current_time - Firewall restart" >> $logdir/$logfile
	shaper_cmd stop
	firewall_down
	destroy_all_hashtables
	create_fw_hashtables
	load_fw_hashtables
	firewall_up
	shaper_cmd start
	dhcpd_cmd restart
	echo "$current_time - Firewall restart OK" >> $logdir/$logfile
    }
 
    lmsd ()
    {
    dburl="mysql -s -u $lms_dbuser $lms_db -e \"select reload from hosts where id=4\""
    lmsd_status=$($exec_cmd $dburl| grep -v reload)

    if [ $lmsd_status = 1 ]; then
        echo "$current_time - Host reload status has been set" >> $logdir/$logfile
	lmsd_reload
        get_config
        newreload
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
        echo -e "\nUsage: fw.sh start|stop|restart|reload|status|lmsd|shaper_stop|shaper_start|shaper_restart|shaper_stats|shaper_status|maintenance-on|maintenance-off"
        echo "$current_time - fw.sh running without parameter" >> $logdir/$logfile
    ;;
    esac
