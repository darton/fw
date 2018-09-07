
#!/bin/bash

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

curl -sS https://raw.githubusercontent.com/darton/fw/master/fw.sh > $scriptsdir/fw.sh
curl -sS https://raw.githubusercontent.com/darton/fw/master/fw.conf > $scriptsdir/fw.sconf
curl -sS https://raw.githubusercontent.com/darton/fw/master/fwfunctions > $scriptsdir/fwfunctions
chmod u+x $scriptsdir/fw.sh
echo "export PATH=$PATH:$scriptsdir" >> /root/.bash_profile
source /root/.bash_profile

