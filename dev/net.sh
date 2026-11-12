#!/bin/bash

ip link add link eth0 name eth0.10 type vlan id 10
ip link add link eth0 name eth0.20 type vlan id 20
ip link add link eth0 name eth0.30 type vlan id 30
ip link set eth0.10 up
ip link set eth0.20 up
ip link set eth0.30 up


ip a add 100.64.100.2/30 dev eth0.10
ip a add 192.168.96.1/21 dev eth0.20
ip a add 10.10.10.254/24 dev eth0.30

ip route add default via 100.64.100.1 dev eth0.10
