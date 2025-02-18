
#!/bin/bash

# Setup for MGMT interface
nmcli connection add type ethernet ifname eno1 con-name MGMT ip4 10.0.253.251/24
#nmcli connection add type ethernet ifname eno1 con-name MGMT ip4 10.0.253.251/24 gw4 10.0.253.254
nmcli con mod MGMT ipv4.route-table 200
nmcli con mod MGMT ipv4.routing-rules "priority 5 from 10.0.253.251 table 200"
nmcli con mod MGMT ipv4.route-metric 600
nmcli con mod MGMT connection.autoconnect yes
nmcli con up MGMT

# Setup for WAN interface
sudo nmcli con add type ethernet ifname enp1s0f0 con-name WAN
sudo nmcli con mod WAN ipv4.addresses 10.48.183.138/30 ipv4.gateway 10.48.183.137 ipv4.dns "1.1.1.1,8.8.8.8" ipv4.method manual
sudo nmcli con mod WAN connection.autoconnect yes

# Setup for LAN interface
sudo nmcli con add type ethernet ifname enp1s0f1 con-name LAN
sudo nmcli con mod LAN ipv4.addresses 10.0.254.254/24 ipv4.method manual
sudo nmcli con mod LAN connection.autoconnect yes
