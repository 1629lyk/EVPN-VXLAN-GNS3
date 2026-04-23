#!/bin/bash
# Ubuntu-H4 setup - Tenant-B VLAN40

ip addr add 10.20.2.11/24 dev eth0 2>/dev/null || true
ip link set eth0 up
ip route add default via 10.20.2.1 2>/dev/null || true

echo "H4 configured: 10.20.2.11/24 gw 10.20.2.1"
ip addr show eth0
ip route show
