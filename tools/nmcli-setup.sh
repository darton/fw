#!/bin/bash


setup_connection(){
  nmcli con mod "$connection_name" ipv4.route-table "$connection_route_table"
  nmcli con mod "$connection_name" ipv4.routing-rules "priority $connection_routing_rules_priority from $interface_ip table $connection_route_table"
  nmcli con mod "$connection_name" ipv4.route-metric "$connection_route_metric"
  nmcli con up "$connection_name"

}


connection_name="Wired LTE connection"
interface_ip="192.168.207.238"
connection_route_metric=600
connection_route_table=100
connection_routing_rules_priority=5
setup_connection


connection_name="Wireles connection 1"
interface_ip="192.168.144.7"
connection_route_metric=500
connection_route_table=99
connection_routing_rules_priority=4
setup_connection
