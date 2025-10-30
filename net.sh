#!/bin/bash

WAN=enp1s0
LAN=enp2s0

ip link set dev $WAN up
ip link set dev $LAN up

ip a add 100.64.0.1/21 dev $LAN

ip a add 100.64.100.2/30 dev $WAN

ip route add default via 100.64.100.1 dev $WAN
