#!/bin/bash
# Ubuntu-H1 setup - Tenant-A VLAN10
# Run after container starts

ip addr add 10.10.1.11/24 dev eth0 2>/dev/null || true
ip link set eth0 up
ip route add default via 10.10.1.1 2>/dev/null || true

echo "H1 configured: 10.10.1.11/24 gw 10.10.1.1"
ip addr show eth0
ip route show
