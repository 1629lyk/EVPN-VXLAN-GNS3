#!/bin/bash
# Ubuntu-H2 setup - Tenant-A VLAN20

ip addr add 10.10.2.11/24 dev eth0 2>/dev/null || true
ip link set eth0 up
ip route add default via 10.10.2.1 2>/dev/null || true

echo "H2 configured: 10.10.2.11/24 gw 10.10.2.1"
ip addr show eth0
ip route show
