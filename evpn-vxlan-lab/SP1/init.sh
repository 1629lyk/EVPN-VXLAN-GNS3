#!/bin/bash
# SP1 init.sh - underlay interface setup
# Run before FRR starts

ip addr add 10.255.0.1/32 dev lo 2>/dev/null || true
ip link set lo up

ip addr add 10.0.1.1/30 dev eth0 2>/dev/null || true
ip addr add 10.0.2.1/30 dev eth1 2>/dev/null || true
ip addr add 10.0.3.1/30 dev eth2 2>/dev/null || true
ip addr add 10.0.4.1/30 dev eth3 2>/dev/null || true
ip addr add 10.0.9.1/30 dev eth4 2>/dev/null || true

ip link set eth0 up
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up
ip link set eth4 up
