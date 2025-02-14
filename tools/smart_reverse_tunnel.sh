#!/bin/bash

# Variables
REMOTE_HOST="10.10.10.10"
REMOTE_PORT=22
REMOTE_USER="remoteuser"
REVERSE_TUNNEL_PORT=2221
LOCAL_TUNNEL_PORT=222
PRIVATE_KEY_PATH=""
PING_TIMEOUT=2

# Function to get the metric of the interface
get_metric() {
  METRIC=$(ip -4 route show table all dev $1 | grep -oP '(?<=metric\s)\d+' | head -1)
  if [ -z "$METRIC" ]; then
    METRIC=0
  fi
  echo $METRIC
}

# Function to get the IP address of the interface
get_ip() {
  ip -4 addr show $1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1
}

# Function to check ping availability
check_ping() {
  local IP_ADDR=$1
  ping -I "$IP_ADDR" -c 1 -w $PING_TIMEOUT "$REMOTE_HOST" &> /dev/null
  return $?
}

# Get the list of interfaces
INTERFACES=($(ip -o link show | awk -F': ' '!/ lo:/{print $2}'))

# Create an array of interfaces with metrics
declare -A INTERFACE_METRICS
for IFACE in "${INTERFACES[@]}"; do
  METRIC=$(get_metric "$IFACE")
  INTERFACE_METRICS["$IFACE"]=$METRIC
done

# Sort interfaces by metric
SORTED_INTERFACES=($(for IFACE in "${!INTERFACE_METRICS[@]}"; do
  echo "$IFACE ${INTERFACE_METRICS[$IFACE]}"; done | sort -k2n | awk '{print $1}'))

# Check the availability of interfaces and establish the tunnel
for IFACE in "${SORTED_INTERFACES[@]}"; do
  IP_ADDR=$(get_ip "$IFACE")
  if [ -n "$IP_ADDR" ] && check_ping "$IP_ADDR"; then
    echo "Using interface $IFACE ($IP_ADDR) to establish the tunnel"
    exec autossh -M 0 -N -R "$REVERSE_TUNNEL_PORT":localhost:"$LOCAL_TUNNEL_PORT" -p "$REMOTE_PORT"  \
      -o BindAddress="$IP_ADDR" -o ExitOnForwardFailure=yes \
      -i "${PRIVATE_KEY_PATH:-$HOME/.ssh/id_rsa}" \
      "$REMOTE_USER@$REMOTE_HOST"
  fi
done

echo "No interface is available to communicate with $REMOTE_HOST"
