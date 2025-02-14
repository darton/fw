#!/bin/bash

# Setup for MGMT interface
nmcli con mod MGMT ipv4.route-table 200
nmcli con mod MGMT ipv4.routing-rules "priority 5 from 10.0.253.251 table 200"
nmcli con mod MGMT ipv4.route-metric 600
nmcli con up MGMT

