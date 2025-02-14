#!/bin/bash

# Setup for MGMT interface
nmcli connection add type ethernet ifname eno1 con-name MGMT ip4 10.0.253.251/24 gw4 10.0.253.254
nmcli con mod MGMT ipv4.route-table 200
nmcli con mod MGMT ipv4.routing-rules "priority 5 from 10.0.253.251 table 200"
nmcli con mod MGMT ipv4.route-metric 600
nmcli con up MGMT

