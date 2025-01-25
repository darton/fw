#!/bin/bash

sudo apt update -y
sudo apt upgrade -y
sudo apt install ulogd2 iptables ipset isc-dhcp-server -y
#po instalacji fw.sh konieczne kroki
sudo cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.org
sudo ln -s /opt/gateway/conf/dhcpd.conf /etc/dhcp/dhcpd.conf
