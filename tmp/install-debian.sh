#!/bin/bash

source /etc/environment #This file should contain the values of the LAN and WAN variables

sudo apt update -y
sudo apt upgrade -y
sudo apt install ulogd2 iptables ipset isc-dhcp-server -y

#afer fw.sh installation
sudo cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.org
sudo ln -s /opt/gateway/conf/dhcpd.conf /etc/dhcp/dhcpd.conf

lan_value=$LAN
sed -i "s/^INTERFACESv4=.*/INTERFACESv4=\"$lan_value\"/" /etc/default/isc-dhcp-server

sudo systemctl start isc-dhcp-server
sudo systemctl enable isc-dhcp-server
