#!/bin/bash
# Leaf2 init.sh - full VTEP setup with MLAG bond
# Run before FRR starts

# ── Teardown (safe re-run) ────────────────
ip link set bond0.10 nomaster 2>/dev/null || true
ip link set bond0.20 nomaster 2>/dev/null || true
ip link set eth3 nomaster 2>/dev/null || true
ip link delete bond0.10 2>/dev/null || true
ip link delete bond0.20 2>/dev/null || true
ip link set bond0 down 2>/dev/null || true
ip link delete bond0 2>/dev/null || true

# ── Loopback ──────────────────────────────
ip addr add 10.255.1.2/32 dev lo 2>/dev/null || true
ip link set lo up

# ── Underlay interfaces ───────────────────
ip addr add 10.0.2.2/30 dev eth0 2>/dev/null || true
ip addr add 10.0.6.2/30 dev eth1 2>/dev/null || true
ip addr add 10.0.20.2/30 dev eth2 2>/dev/null || true
ip link set eth0 up
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up

# ── VRFs ──────────────────────────────────
ip link add vrf-tenA type vrf table 10 2>/dev/null || true
ip link set vrf-tenA up
ip link add vrf-tenB type vrf table 20 2>/dev/null || true
ip link set vrf-tenB up

# ── L2VNI 10010 - Tenant-A VLAN10 ─────────
ip link add vxlan10010 type vxlan id 10010 dstport 4789 local 10.255.1.2 nolearning 2>/dev/null || true
ip link set vxlan10010 up
ip link add br10 type bridge 2>/dev/null || true
ip link set br10 up
ip link set vxlan10010 master br10
ip link add vlan10 link br10 type vlan id 10 2>/dev/null || true
ip addr add 10.10.1.1/24 dev vlan10 2>/dev/null || true
ip link set vlan10 master vrf-tenA
ip link set vlan10 up

# ── L2VNI 10020 - Tenant-A VLAN20 ─────────
ip link add vxlan10020 type vxlan id 10020 dstport 4789 local 10.255.1.2 nolearning 2>/dev/null || true
ip link set vxlan10020 up
ip link add br20 type bridge 2>/dev/null || true
ip link set br20 up
ip link set vxlan10020 master br20
ip link add vlan20 link br20 type vlan id 20 2>/dev/null || true
ip addr add 10.10.2.1/24 dev vlan20 2>/dev/null || true
ip link set vlan20 master vrf-tenA
ip link set vlan20 up

# ── L2VNI 10030 - Tenant-B VLAN30 ─────────
ip link add vxlan10030 type vxlan id 10030 dstport 4789 local 10.255.1.2 nolearning 2>/dev/null || true
ip link set vxlan10030 up
ip link add br30 type bridge 2>/dev/null || true
ip link set br30 up
ip link set vxlan10030 master br30
ip link add vlan30 link br30 type vlan id 30 2>/dev/null || true
ip addr add 10.20.1.1/24 dev vlan30 2>/dev/null || true
ip link set vlan30 master vrf-tenB
ip link set vlan30 up

# ── L2VNI 10040 - Tenant-B VLAN40 ─────────
ip link add vxlan10040 type vxlan id 10040 dstport 4789 local 10.255.1.2 nolearning 2>/dev/null || true
ip link set vxlan10040 up
ip link add br40 type bridge 2>/dev/null || true
ip link set br40 up
ip link set vxlan10040 master br40
ip link add vlan40 link br40 type vlan id 40 2>/dev/null || true
ip addr add 10.20.2.1/24 dev vlan40 2>/dev/null || true
ip link set vlan40 master vrf-tenB
ip link set vlan40 up

# ── L3VNI 50010 - Tenant-A routing ────────
ip link add vxlan50010 type vxlan id 50010 dstport 4789 local 10.255.1.2 nolearning 2>/dev/null || true
ip link set vxlan50010 up
ip link add br100 type bridge 2>/dev/null || true
ip link set br100 up
ip link set vxlan50010 master br100
ip link add vlan100 link br100 type vlan id 100 2>/dev/null || true
ip link set vlan100 addrgenmode none
ip link set vlan100 master vrf-tenA
ip link set vlan100 up

# ── L3VNI 50020 - Tenant-B routing ────────
ip link add vxlan50020 type vxlan id 50020 dstport 4789 local 10.255.1.2 nolearning 2>/dev/null || true
ip link set vxlan50020 up
ip link add br200 type bridge 2>/dev/null || true
ip link set br200 up
ip link set vxlan50020 master br200
ip link add vlan200 link br200 type vlan id 200 2>/dev/null || true
ip link set vlan200 addrgenmode none
ip link set vlan200 master vrf-tenB
ip link set vlan200 up

# ── MLAG bond toward SW1 ──────────────────
ip link add bond0 type bond 2>/dev/null || true
ip link set bond0 type bond mode 802.3ad
ip link set bond0 type bond lacp_rate fast
ip link set bond0 type bond miimon 100
ip link set eth3 down
ip link set eth3 master bond0
ip link set bond0 up
ip link set eth3 up
echo 44:38:39:FF:01:01 > /sys/class/net/bond0/bonding/ad_actor_system

ip link add link bond0 name bond0.10 type vlan id 10 2>/dev/null || true
ip link set bond0.10 master br10
ip link set bond0.10 up

ip link add link bond0 name bond0.20 type vlan id 20 2>/dev/null || true
ip link set bond0.20 master br20
ip link set bond0.20 up

ip link set br10 type bridge vlan_filtering 1
ip link set br20 type bridge vlan_filtering 1
bridge vlan add dev bond0.10 vid 10 pvid untagged
bridge vlan del dev bond0.10 vid 1
bridge vlan add dev bond0.20 vid 20 pvid untagged
bridge vlan del dev bond0.20 vid 1
bridge vlan add dev br10 vid 10 self
bridge vlan add dev br20 vid 20 self
bridge vlan add dev vxlan10010 vid 10
bridge vlan add dev vxlan10020 vid 20
