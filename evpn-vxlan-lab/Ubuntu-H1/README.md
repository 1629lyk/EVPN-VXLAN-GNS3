# Ubuntu-H1 - Tenant-A Host / VLAN 10

## Role

Ubuntu-H1 is a host in Tenant-A connected to SW1 on VLAN 10. It uses `10.10.1.11/24` as its IP address with `10.10.1.1` as the default gateway - the anycast gateway IP configured identically on all four leaves.

H1 is used as the source node for all connectivity tests including the Phase 6 BFD failure test. The 250-packet ping stream from H1 to H2 during the dual-uplink failure demonstrated 0% packet loss thanks to MLAG failover.

## Connectivity

H1 connects to SW1 Ethernet0/2 via eth0. SW1 puts this port in VLAN 10 access mode - H1 sends and receives untagged frames. SW1 tags them as VLAN 10 before sending out Po1 toward the leaves.

## IP Configuration

```bash
ip addr add 10.10.1.11/24 dev eth0
ip link set eth0 up
ip route add default via 10.10.1.1
```

These commands are not persistent across Ubuntu Docker container restarts. Apply them each time the container starts, or add them to `/etc/rc.local` if the image supports it.

## Test Commands

```bash
# Gateway reachability
ping -c3 10.10.1.1

# Cross-subnet same tenant (L3VNI)
ping -c3 10.10.2.11

# Tenant isolation - must fail
ping -c3 10.20.1.11

# BFD failure test probe
ping -i 0.2 -c 250 10.10.2.11
```

## Errors Encountered

No configuration errors on H1. The connectivity failures observed were all caused by upstream issues - STP blocking on SW1, bridge PVID misconfiguration on Leaf1/2, and LACP system-mac mismatch. Once those were resolved, H1 connectivity worked immediately without any changes to H1's configuration.
