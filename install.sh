#!/bin/bash

SCRIPT_RELATIVE_DIR=$(dirname "${BASH_SOURCE[0]}")
cd $SCRIPT_RELATIVE_DIR

systemctl disable dnsmasq
systemctl mask dnsmasq

mkdir -p /etc/router/
cp router.sh /etc/router/service
cp router.service /etc/systemd/system/router.service
systemctl enable router.service

find -name '*eth*' -exec basename {} \; |\
  xargs -i cp {} /etc/systemd/network/{}
systemctl enable systemd-networkd
