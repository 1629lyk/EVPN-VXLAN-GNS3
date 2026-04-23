#!/bin/bash
# SP2 init.sh - underlay interface setup
# Run before FRR starts

ip addr add 10.255.0.2/32 dev lo 2>/dev/null || true
ip link set lo up

ip addr add 10.0.5.1/30 dev eth0 2>/dev/null || true
ip addr add 10.0.6.1/30 dev eth1 2>/dev/null || true
ip addr add 10.0.7.1/30 dev eth2 2>/dev/null || true
ip addr add 10.0.8.1/30 dev eth3 2>/dev/null || true
ip addr add 10.0.10.1/30 dev eth4 2>/dev/null || true

ip link set eth0 up
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up
ip link set eth4 up
