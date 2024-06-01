#!/bin/bash
set -x

if [ "$1" != "up" ] && [ "$1" != "down" ] || [ $# != 1 ]; then
    echo "missing required argument"
    echo "$0: <up/down>"
    exit
fi

# VARIABLES
BR_IFACE="br_lan"
WAN_IFACE="eth_wan"
LAN_IFACE="eth_lan_host"
LAN2_IFACE="eth_lan_vnet"

LAN_IP="192.168.200.1"
LAN_SUBNET="255.255.255.0"
LAN_DHCP_START="192.168.200.10"
LAN_DHCP_END="192.168.200.100"
LAN_DNS_SERVER="1.1.1.1"

DNSMASQ_CONF="tmp_dnsmasq.conf"

SCRIPT_RELATIVE_DIR=$(dirname "${BASH_SOURCE[0]}") 
cd $SCRIPT_RELATIVE_DIR

if [ $1 = "down" ]; then
    echo "== stop router services"
    killall dnsmasq
    sysctl net.ipv4.ip_forward=0
    sysctl net.ipv6.conf.all.forwarding=0

    echo "== reset all network interfaces"
    ifconfig $LAN_IFACE 0.0.0.0
    ifconfig $LAN_IFACE down
    ifconfig $LAN2_IFACE 0.0.0.0
    ifconfig $LAN2_IFACE down
    ifconfig $BR_IFACE 0.0.0.0
    ifconfig $BR_IFACE down
    brctl delbr $BR_IFACE
fi
if [ $1 = "up" ]; then

    echo "== create dnsmasq config file"
    echo "interface=${BR_IFACE}" > $DNSMASQ_CONF
    echo "dhcp-range=${LAN_DHCP_START},${LAN_DHCP_END},${LAN_SUBNET},12h" >> $DNSMASQ_CONF
    echo "dhcp-option=6,${LAN_DNS_SERVER}" >> $DNSMASQ_CONF

    echo "== bring up interfaces and bridge"
    ifconfig $LAN_IFACE up
    ifconfig $LAN2_IFACE up
    brctl addbr $BR_IFACE
    brctl addif $BR_IFACE $LAN_IFACE
    brctl addif $BR_IFACE $LAN2_IFACE

    echo "== setup iptables"
    iptables --flush
    iptables -t nat --flush
    iptables -t nat -A POSTROUTING -o $WAN_IFACE -j MASQUERADE
    iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i $BR_IFACE -o $WAN_IFACE -j ACCEPT
    # optional mitm rules
    #iptables -t nat -A PREROUTING -i $BR_IFACE -p tcp -d 1.2.3.4 --dport 443 -j REDIRECT --to-ports 8081

    echo "== setting static IP on bridge interface"
    ifconfig $BR_IFACE inet $LAN_IP netmask $LAN_SUBNET
    ifconfig $BR_IFACE up

    echo "== starting dnsmasq"
    dnsmasq -C $DNSMASQ_CONF
    sysctl net.ipv4.ip_forward=1
    sysctl net.ipv6.conf.all.forwarding=1
fi
