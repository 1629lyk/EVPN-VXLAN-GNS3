#!/bin/bash
# Border-Leaf init.sh - L3VNI setup for external peering
# Run before FRR starts

# ── Loopback ──────────────────────────────
ip addr add 10.255.1.5/32 dev lo 2>/dev/null || true
ip link set lo up

# ── Underlay interfaces ───────────────────
ip addr add 10.0.9.2/30 dev eth0 2>/dev/null || true
ip addr add 10.0.10.2/30 dev eth1 2>/dev/null || true
ip addr add 10.0.11.1/30 dev eth2 2>/dev/null || true
ip link set eth0 up
ip link set eth1 up
ip link set eth2 up

# ── VRFs ──────────────────────────────────
ip link add vrf-tenA type vrf table 10 2>/dev/null || true
ip link set vrf-tenA up
ip link add vrf-tenB type vrf table 20 2>/dev/null || true
ip link set vrf-tenB up

# ── L3VNI 50010 - Tenant-A ────────────────
ip link add vxlan50010 type vxlan id 50010 dstport 4789 \
    local 10.255.1.5 nolearning 2>/dev/null || true
ip link set vxlan50010 up
ip link add br100 type bridge 2>/dev/null || true
ip link set br100 up
ip link set vxlan50010 master br100
ip link add vlan100 link br100 type vlan id 100 2>/dev/null || true
ip link set vlan100 addrgenmode none
ip link set vlan100 master vrf-tenA
ip link set vlan100 up

# ── L3VNI 50020 - Tenant-B ────────────────
ip link add vxlan50020 type vxlan id 50020 dstport 4789 \
    local 10.255.1.5 nolearning 2>/dev/null || true
ip link set vxlan50020 up
ip link add br200 type bridge 2>/dev/null || true
ip link set br200 up
ip link set vxlan50020 master br200
ip link add vlan200 link br200 type vlan id 200 2>/dev/null || true
ip link set vlan200 addrgenmode none
ip link set vlan200 master vrf-tenB
ip link set vlan200 up

# ── IP forwarding ─────────────────────────
sysctl -w net.ipv4.ip_forward=1 2>/dev/null || true
sysctl -w net.ipv4.conf.all.forwarding=1 2>/dev/null || true



iptables -t nat -A POSTROUTING -o eth2 -j MASQUERADE
iptables -A FORWARD -i vlan100 -o eth2 -j ACCEPT
iptables -A FORWARD -i eth2 -o vlan100 -j ACCEPT
iptables -A FORWARD -i vlan200 -o eth2 -j ACCEPT
iptables -A FORWARD -i eth2 -o vlan200 -j ACCEPT

