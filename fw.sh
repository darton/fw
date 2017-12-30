#!/bin/bash
#
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

#Ścieżki do katalogu z plikami konfiguracyjnymi dla skryptu
confdir=/opt/gateway/conf
oldconfdir=/opt/gateway/oldconf

#Deklaracja interfejsów sieciowych WAN -> od strony Internetu, LAN -> od strony klientów
WAN=enp2s0
LAN=enp3s0

#Deklaracja nazw plików konfiguracyjnych
nat_11_file=fw_nat_1-1
nat_1n_ip_file=fw_nat_1-n
public_ip_file=fw_public_ip
lan_banned_dst_ports_file=fw_lan_banned_dst_ports
routed_ip_file=fw_routed_ip

#Adres do wygenerowanych przez LMS plików dla niniejszego skryptu 
scpurl=root@192.168.102.79:/opt/gateway

#Adres bazy danych LMS 
sshurl=root@192.168.102.79

#Kwerenda do serwera bazy danych LMS, pobierająca  status przeładowania lmsd
dburl="mysql -s -u lmsd_reload lms -e \"select reload from hosts where id=4\""

#Adres IP serwera proxy
proxy_ip=192.168.100.1


####Deklaracje funkcji używanych w skrypcie####

function get_config {
	cd $confdir
    for FILENAME in *
    do
	mv $FILENAME $oldconfdir/$FILENAME
    done 
	echo "Łącze się z LMS i pobieram pliki konfiguracyjne"
	scp $scpurl/* $confdir/
}


function get_qos_config {
	cd $confdir
	mv $confdir/rc.htb $oldconfdir/rc.htb
	echo "Łącze się z serwerem i pobieram plik qos"
	scp $scpurl/rc.htb $confdir/
}


function compare_config_files {
    cd $confdir
    for f in *
    do
	diff -q $confdir/$f $oldconfdir/$f > /tmp/fw.diff
    done

    if [ -s "/tmp/fw.diff" ]
    then
	echo ""
	echo "Status konfiguracji"
	echo "-------------------"
	echo "Pliki konfiguracyjne zostały zmienione, wykonuję następne polecenia"
	echo ""
    else
    	echo ""
	echo "Status konfiguracji"
	echo "-------------------"
	echo "Nowa konfiguracja jest identyczna, kończę działanie programu."
	echo ""
	exit
    fi
}


function dhcpd_restart {
dhcpd_conf_current=$(cat $confdir/dhcpd.conf |sha1sum)
dhcpd_conf_new=$(cat $oldconfdir/dhcpd.conf |sha1sum)

    if [ "$dhcpd_conf_current" != "$dhcpd_conf_new" ]
    then
	echo "Plik dhcpd.conf ma nową konfigurację, restartuję serwer DHCP - `date`" >> /tmp/lms.status 
	systemctl restart dhcpd.service
    else
	echo "Konfiguracja dhcpd.conf jest identyczna, restart nie jest potrzebny"
    fi
}


function htb_cmd {
    if [ "$1" = "restart" ]
    then
    rc_htb_current=$(cat $confdir/rc.htb |sha1sum)
    rc_htb_new=$(cat $oldconfdir/rc.htb |sha1sum)
        if [ "$rc_htb_current" != "$rc_htb_new" ]
        then
            echo "Plik rc.htb ma nową konfigurację, restartuję Shaper - `date`" >> /tmp/lms.status 
            bash $confdir/rc.htb stop
            bash $confdir/rc.htb start
        else
            echo "Konfiguracja rc.htb jest identyczna, restart nie jest potrzebny"
        fi
    fi
    if [ "$1" = "stop" ]
    then
    echo "Zatrzymuję Shaper"
    bash $confdir/rc.htb stop
    fi
    if [ "$1" = "start" ]
    then
    echo "Uruchamiam Shaper"
    bash $confdir/rc.htb start
    fi
}


function create_fw_hashtables {
#hashtable for granted host 
	ipset create fw_ip hash:ip hashsize 2048

#hashtable for denied host
	ipset create fw_denied_hosts hash:ip hashsize 1024

#hashtable for warned host
	ipset create fw_warned_hosts hash:ip hashsize 2048

#hashtable for banned dst ports on LAN interface
	ipset create fw_lan_banned_dst_ports bitmap:port range 0-65535

#hashtable for nat1-n host
    while read nat_name ip; do
	ipset create "$nat_name" hash:ip hashsize 1024
    done <$confdir/$nat_1n_ip_file
}

function destroy_tmp_hashtables {
#remove all *.tmp ipset hashtables
    for ipsetlist in `ipset list -n|grep .tmp`
    do
        ipset destroy $ipsetlist
    done
}

function create_tmp_hashtables {
#create tmp hashtable for granted host
        ipset create fw_ip.tmp hash:ip hashsize 2048

#create tmp hashtable for denied host
        ipset create fw_denied_hosts.tmp hash:ip hashsize 1024

#create tmp hashtable for warned host
        ipset create fw_warned_hosts.tmp hash:ip hashsize 2048

#create tmp hashtable for banned dst ports on LAN interface
        ipset create fw_lan_banned_dst_ports.tmp bitmap:port range 0-65535

#create tmp hashtable for nat1-n host
    while read nat_name ip; do
        ipset create "$nat_name".tmp hash:ip hashsize 1024
    done <$confdir/$nat_1n_ip_file
}


function load_tmp_fw_ip_hashtable {
    while read status i; do
        if [ "$status" = "grantedhost" ]
        then
            ipset add fw_ip.tmp $i
        elif [ "$status" = "deniedhost" ]
        then
            ipset add fw_denied_hosts.tmp $i
        elif [ "$status" = "warnedhost" ]
        then
            ipset add fw_warned_hosts.tmp $i
        else
            echo "Plik $public_ip_file ma nieprawidłowy format, prawidłowy to: grantedhost|deniedhost|warnedhost ip_addres"
        fi
    done < $confdir/$public_ip_file
}


function load_tmp_nat1n_hashtables {
while read nat_name ip; do
    while read status i; do
        if [ "$status" = "grantedhost" ]
        then
            ipset add $nat_name.tmp $i
            ipset add fw_ip.tmp $i
        elif [ "$status" = "deniedhost" ]
        then
            ipset add fw_denied_hosts.tmp $i
        elif [ "$status" = "warnedhost" ]
        then
            ipset add fw_warned_hosts.tmp $i
        else
        echo    echo "Plik $nat_name ma nieprawidłowy format, prawidłowy to: grantedhost|deniedhost|warnedhost ip_addres"
        fi
    done < $confdir/$nat_name
done <$confdir/$nat_1n_ip_file
}


function load_tmp_nat_11_hashtable {
    while read status i ipub; do
        if [ "$status" = "grantedhost" ]
        then
            ipset add fw_ip.tmp $i
        elif [ "$status" = "deniedhost" ]
        then
            ipset add fw_denied_hosts.tmp $i
        elif [ "$status" = "warnedhost" ]
        then
            ipset add fw_warned_hosts.tmp $i
        else
            echo "Plik $nat_11_file ma nieprawidłowy format, prawidłowy to: grantedhost|deniedhost|warnedhost ip_adres ipub_adres"
        fi
    done < $confdir/$nat_11_file
}


function load_tmp_lan_banned_dst_ports_hashtable {
    while read ports; do
            ipset add fw_lan_banned_dst_ports.tmp $ports
    done < $confdir/$lan_banned_dst_ports_file
}


function load_new_ipset_hashtables {
    for ipsetname in `ipset list -n|grep -v .tmp`
    do
        current=$(ipset list $ipsetname |tail -n +8 |sort |sha1sum)
        new=$(ipset list $ipsetname.tmp |tail -n +8 |sort |sha1sum)

     if [ "$current" != "$new" ]
     then
        echo "Ładuję nową zawartość do $ipsetname" >> /tmp/lms.status 
        ipset -W $ipsetname $ipsetname.tmp
     fi
        ipset -X $ipsetname.tmp
    done
}


function load_nat_1n_fw_rules {
    while read nat_name ip; do
	iptables -t nat -A POSTROUTING -o $WAN -m set --match-set $nat_name src -j SNAT --to-source $ip
    done <$confdir/$nat_1n_ip_file
}


function load_nat_11_fw_rules {
    while read status i ipub; do
	if [ "$status" = "grantedhost" ]
	then
	    iptables -t nat -A POSTROUTING -o $WAN -s $i -j SNAT --to-source $ipub
	    iptables -t nat -A PREROUTING -i $WAN -d $ipub -j DNAT --to-destination $i
	fi
    done < $confdir/$nat_11_file
}


function firewall_up {
#Zwiększenie tablicy ARP
    echo "8192" > /proc/sys/net/ipv4/neigh/default/gc_thresh3
    echo "4096" > /proc/sys/net/ipv4/neigh/default/gc_thresh2
    echo "2048" > /proc/sys/net/ipv4/neigh/default/gc_thresh1

#Ustawienie domyślnej polityki
    iptables -P FORWARD DROP

#Włączenie przesyłania pakietów między interfejsami sieciowymi
    sysctl -w net.ipv4.ip_forward=1

#Blokada wybranych portów docelowych w sieci LAN
#    iptables -A FORWARD -i $WAN -m set --match-set fw_lan_banned_dst_ports dst -j DROP
    iptables -A FORWARD -i $WAN -o $LAN -m set --match-set fw_lan_banned_dst_ports dst -j DROP

#Włączenie logowania nowych pakietów mających swoje żródło w naszej sieci.
    iptables -A FORWARD -i $LAN -m state --state NEW -j ULOG --ulog-nlgroup 1 --ulog-prefix FORWARDED-CONN

#Ładowanie reguł FORWARD dla wszystkich upoważnionych hostów.
# Zezwolenie na przesył pakietów pomiędzy dowolnymi interfejsami ethernet firewalla dla wybranych hostów z listy fw_ip
#   iptables -A FORWARD -m set --match-set fw_ip src,dst -j ACCEPT
# Zezwolenie na przesył pakietów tylko pomiędzy interfejscami LAN i WAN dla wybranych hostów z listy fw_ip
    iptables -A FORWARD -i $LAN -o $WAN -m set --match-set fw_ip src -j ACCEPT
    iptables -A FORWARD -i $WAN -o $LAN -m set --match-set fw_ip dst -j ACCEPT

#Redirect dla klientów z włączonym ostrzeżeniem w LMS
    iptables -t nat -A PREROUTING -i $LAN -m set --match-set fw_warned_hosts src -p tcp --dport 80 -j DNAT --to $proxy_ip:3128

#Załadowanie reguł SNAT dla użytkowników NAT 1:n
    load_nat_1n_fw_rules

#Załadowanie reguł SNAT/DNAT dla użytkowników NAT 1:1
    load_nat_11_fw_rules
}


function firewall_down {
#Wyłączenie przesyłania pakietów między interfejsami.
    sysctl -w net.ipv4.ip_forward=0

#Usunięcie raguł iptables
    for i in raw filter nat mangle
    do
        iptables -t $i -F
        iptables -t $i -X
    done

#Ustawienie domyśłnej polityki dla wyłączonego firewalla
        iptables -P FORWARD DROP
	iptables -P INPUT ACCEPT
	iptables -P OUTPUT ACCEPT
}


function destroy_all_hashtables {
    for ipsetlist in `ipset list -n`
    do
        ipset destroy $ipsetlist
    done
}


function flush_hashtables {
    ipset -F
}


function load_fw_hashtables {
	destroy_tmp_hashtables
	create_tmp_hashtables
        load_tmp_fw_ip_hashtable
        load_tmp_nat1n_hashtables
        load_tmp_nat_11_hashtable
        load_tmp_lan_banned_dst_ports_hashtable
        load_new_ipset_hashtables
}


function lmsd_reload {
#Sprawdza czy ustawiony jest status przeładowania dla demona lmsd na maszynie z LMS

	lms_status=`ssh $sshurl "$dburl"| grep -v reload`
    if [ $lms_status = 1 ]
    then
	echo "Status przeładowania lmsd został ustawiony" 
	echo "Przeładowywuję lmsd na zdalnej maszynie"
	ssh $sshurl '/usr/local/lmsd/bin/lmsd -q -h 127.0.0.1:3306 -H newgateway -u lmsd_reload -d lms'
        echo "Pobieram konfigurację z LMS"
	get_config
        echo "Sprawdzam czy zmieniła się konfiguracja"
	compare_config_files
        echo "Pliki konfiguracyjne zostały zmienione, ładuję nową konfigurację. Uruchamiam skrypt w trybie reload"
	reload
    else
	echo "Status przeładowania lmsd nie został ustawiony, kończę program"
    exit
    fi
}


function lmsd_reload_new {
#Sprawdza czy ustawiony jest status przeładowania dla demona lmsd na maszynie z LMS

	lms_status=`ssh $sshurl "$dburl"| grep -v reload`
    if [ $lms_status = 1 ]
    then
	echo "Status przeładowania lmsd został ustawiony" 
	echo "Wykonuję reload lmsd na zdalnej maszynie"
	ssh $sshurl '/usr/local/lmsd/bin/lmsd -q -h 127.0.0.1:3306 -H newgateway -u lmsd_reload -d lms'
        echo "Pobieram konfigurację z LMS"
	get_config
	echo "Sprawdzam czy konieczny jest restart czy wystarczy reload"
	nat_11_current_sha1sum=$(cat $oldconfdir/$nat_11_file |sort |sha1sum)
	nat_11_new_sha1sum=$(cat $confdir/$nat_11_file |sort |sha1sum)
	nat_1n_current_sha1sum=$(cat $oldconfdir/$nat_1n_ip_file |sort |sha1sum)
	nat_1n_new_sha1sum=$(cat $confdir/$nat_1n_ip_file |sort |sha1sum)
        if [ "$nat_11_current_sha1sum" != "$nat_11_new_sha1sum" ] || [ "$nat_1n_current_sha1sum" != "$nat_1n_new_sha1sum" ]
        then
        echo "Wykonuję restart firewalla. - `date`" >> /tmp/lms.status
        restart
        else
        echo "Wykonuję reload firewalla. - `date`" >> /tmp/lms.status
        newreload
        fi
    else
	echo "Status przeładowania lmsd nie został ustawiony, kończę program. - `date`"
    exit
    fi
}

function static_routing_up {
    while read net gw interface; do
    	ip route add $net via $gw dev $interface
    done < $confdir/$routed_ip_file
}

function static_routing_down {
    while read net gw; do
    	ip route del $net via $gw dev $interface
    done < $confdir/$routed_ip_file
}

function fw_cron {
    if [ "$1" = "start" ]
    then
echo '# Run the fw.sh cron jobs
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=""
* * * * * root /opt/gateway/scripts/fw.sh lmsd  > /dev/null 2>&1
01 22 * * * root /opt/gateway/scripts/fw.sh qos  > /dev/null 2>&1
01 10 * * * root /opt/gateway/scripts/fw.sh qos  > /dev/null 2>&1
' > /etc/cron.d/fw_sh
    fi

    if [ "$1" = "stop" ]
    then
        rm /etc/cron.d/fw_sh
    fi
}


    stop ()
    {
	static_routing_down
        firewall_down
        htb_cmd stop
        destroy_all_hashtables
	fw_cron stop
    }


    start ()
    {
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


    reload ()
    {
	echo "Wykonuję reload"
	firewall_down
	load_fw_hashtables
        firewall_up
        htb_cmd restart
        dhcpd_restart
    }


    newreload ()
    {
	echo "Wykonuję reload"
	load_fw_hashtables
        htb_cmd restart
        dhcpd_restart
    }


    restart ()
    {
        echo "Wykonuję restart"
	echo "Restartuję Firewall"
	firewall_down
	destroy_all_hashtables
	create_fw_hashtables
	load_fw_hashtables
	firewall_up
	echo "Sprawdzam czy konieczny jest restart Shaper'a"
	htb_cmd restart
	echo "Sprawdzam czy konieczny jest restart serwera DHCP"
	dhcpd_restart
    }

    qos ()
    {
        get_qos_config
	htb_cmd restart
    }


    stats ()
    {
        iptables -t mangle -nvxL COUNTERSOUT |tail -n +3 | awk '{print $8 " "$2}' |grep -v 0.0.0.0 > /tmp/upload.tmp
	iptables -t mangle -nvxL COUNTERSIN |tail -n +3 | awk '{print $9 " "$2}' |grep -v 0.0.0.0 > /tmp/download.tmp
	join /tmp/upload.tmp /tmp/download.tmp
	rm /tmp/upload.tmp /tmp/download.tmp
	iptables -t mangle -Z COUNTERSIN
	iptables -t mangle -Z COUNTERSOUT
    }


    status ()
    {
        echo "########"
        echo "IPTABLES"
        echo "########"
        echo ""
    for tablename in raw filter nat mangle
    do
	echo "-------"
	echo "$tablename"
	echo "-------"
	iptables -t $tablename -nvL
	echo ""
    done

        echo "-----"
        echo "IPSET"
        echo "-----"
	echo ""
    for ipsetname in `ipset list -n`
    do
	ipset list $ipsetname
	echo ""	
    done
        echo "----------"
        echo "IPSET LIST"
        echo "----------"
	echo ""
	ipset list -n
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
        status
    ;;
    'restart')
        stop
        start
    ;;
    'reload')
        reload
    ;;
    'newreload')
        newreload
    ;;
    'lmsd')
        lmsd
    ;;
    'qos')
        qos
        
    ;;
        *)
        echo -e "\nUsage: fw.sh start|stop|restart|reload|stats|lmsd|qos|status"
    ;;

esac
