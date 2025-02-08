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
shaper_file=fw_shaper
dhcp_conf_file=dhcpd.conf


[[ -d /run/fw-sh/ ]] || mkdir /run/fw-sh
[[ -f /run/fw-sh/maintenance.pid ]] || echo 0 > /run/fw-sh/maintenance.pid
[[ -d $installdir ]] || mkdir -p $installdir
[[ -d $scriptsdir ]] || mkdir -p $scriptsdir
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

cp ./fw.sh $scriptsdir/fw.sh
cp ./fw.conf $scriptsdir/fw.conf
cp ./fwfunctions $scriptsdir/fwfunctions
chmod u+x $scriptsdir/fw.sh
echo "export PATH=$PATH:$scriptsdir" >> /root/.bash_profile
source /root/.bash_profile

