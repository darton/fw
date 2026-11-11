#!/bin/bash

INTERFACE=$(echo $LAN)

# Tworzymy tablicę do przechowywania mapowania classid -> IP
declare -A classid_to_ip

# Parsujemy reguły iptables, aby zbudować mapowanie classid -> IP
while read -r line; do
    if [[ "$line" =~ CLASSIFY ]]; then
        classid=$(echo "$line" | grep -oP 'CLASSIFY set \K[^\s]+')
        ip=$(echo "$line" | awk '{print $5}')
        if [[ -n "$classid" && -n "$ip" ]]; then
            classid_to_ip["$classid"]="$ip"
        fi
    fi
done < <( iptables -L -n -t mangle |grep set |awk '$5!="0.0.0.0/0" { print $0 }')

# Wyświetlamy zawartość tablicy classid_to_ip
#echo "Zawartość tablicy classid_to_ip:"
#for classid in "${!classid_to_ip[@]}"; do
#    echo "classid: $classid -> adres IP: ${classid_to_ip[$classid]}"
#done
echo ""

# Analizujemy wyjście tc i szukamy qdisc fq_codel z drop_overmemory > 0
while read -r line; do
#    echo "Analizowany wiersz: $line"
    if [[ "$line" =~ ^qdisc\ fq_codel ]]; then
        qdisc_id=$(echo "$line" | awk '{print $3}')
        parent=$(echo "$line" | awk '{print $5}')
        parent=${parent#parent }
#        echo "qdisc_id: $qdisc_id, parent: $parent"
        drop_overmemory=0
    elif [[ "$line" =~ drop_overmemory ]]; then
        if [[ "$line" =~ drop_overmemory\ ([0-9]+) ]]; then
            drop_overmemory=${BASH_REMATCH[1]}
#            echo "drop_overmemory: $drop_overmemory"
        fi
        if [[ "$drop_overmemory" -gt 0 ]]; then
            ip_address="${classid_to_ip[$parent]}"
            if [[ -z "$ip_address" ]]; then
                ip_address="nieznany"
            fi
            #echo "Klasa HTB: $parent"
            #echo "qdisc fq_codel: $qdisc_id"
            #echo "drop_overmemory: $drop_overmemory"
            #echo "Adres IP: $ip_address"
            #echo ""
            echo "Klasa HTB: $parent; drop_overmemory: $drop_overmemory; Adres IP: $ip_address;"
        fi
    fi
done < <(tc -s -d qdisc show dev "$INTERFACE")

