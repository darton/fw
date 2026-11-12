#!/bin/bash

ip link set dev $WAN up
ip link set dev $LAN up

ip a add 192.168.96.1/21 dev $LAN

ip a add 100.64.100.2/30 dev $WAN

ip route add default via 100.64.100.1 dev $WAN
