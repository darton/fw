#!/bin/bash

NET_IF1=eth0
NET_IF2=eth0
NET_IF3=eth0

ip link add link "${NET_IF1}" name wan type vlan id 10
ip link add link "${NET_IF2}" name lan type vlan id 20
ip link add link "${NET_IF3}" name mgmt type vlan id 30
ip link set wan up
ip link set lan up
ip link set mgmt up


ip a add 100.64.100.2/30 dev wan
ip a add 192.168.96.1/21 dev lan
ip a add 10.10.10.254/24 dev mgmt

ip route add default via 100.64.100.1 dev wan
