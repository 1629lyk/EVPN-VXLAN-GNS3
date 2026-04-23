# Leaf1 - VTEP / Pod-1 Primary

## Role

Leaf1 is a VTEP (VXLAN Tunnel Endpoint) in Pod-1, serving Tenant-A hosts on VLANs 10 and 20. It is the MLAG primary in the Leaf1/Leaf2 pair, meaning it handles BUM (Broadcast, Unknown unicast, Multicast) traffic forwarding decisions.

Leaf1 originates EVPN routes - Type-2 MAC/IP advertisements for locally learned hosts, and Type-5 IP prefix routes for tenant subnets. It peers with both spines via eBGP and receives EVPN routes from all other leaves through the spine relay.

## VXLAN Architecture - Per-VNI Bridge

Each VNI has its own dedicated vxlan interface and Linux bridge. This is the working architecture after the SVD approach failed due to iproute2 version limitations - see Errors section below.

| Bridge | VXLAN IF | VNI | Purpose |
|---|---|---|---|
| br10 | vxlan10010 | 10010 | Tenant-A VLAN10 L2VNI |
| br20 | vxlan10020 | 10020 | Tenant-A VLAN20 L2VNI |
| br30 | vxlan10030 | 10030 | Tenant-B VLAN30 L2VNI |
| br40 | vxlan10040 | 10040 | Tenant-B VLAN40 L2VNI |
| br100 | vxlan50010 | 50010 | Tenant-A L3VNI |
| br200 | vxlan50020 | 50020 | Tenant-B L3VNI |

## VRF Design

Two VRFs provide tenant isolation at the routing layer. Each VRF has a dedicated kernel routing table.

- `vrf-tenA` - table 10 - carries Tenant-A routes (10.10.1.0/24, 10.10.2.0/24)
- `vrf-tenB` - table 20 - carries Tenant-B routes (10.20.1.0/24, 10.20.2.0/24)

The L3VNI SVI (vlan100 and vlan200) must NOT have an IP address. FRR uses these interfaces purely for L3VNI VXLAN encapsulation - an IP address would confuse the routing table.

## L2VNI SVIs - Anycast Gateway

Each L2VNI bridge has a VLAN subinterface (vlan10, vlan20 etc.) with the tenant gateway IP. The same gateway IP (10.10.1.1/24) is configured on all leaves - this is the anycast gateway pattern. Hosts always use the same gateway IP regardless of which leaf they're attached to.

## MLAG - Pod-1 Primary

Leaf1 is the MLAG primary in Pod-1. The MLAG peer link is eth2, connected directly to Leaf2 eth2. The Linux bond (bond0) on eth3 carries LACP toward SW1.

The MLAG system-mac `44:38:39:FF:01:01` is shared between Leaf1 and Leaf2. This makes SW1's LACP see both leaves as a single logical device, allowing Po1 to bundle both uplinks. The system-mac is set via the `ad_actor_system` sysfs parameter - not via `ip link set address`.

## Interface Assignments

| Interface | Connected To | Purpose | IP |
|---|---|---|---|
| eth0 | SP1 eth0 | Underlay uplink | 10.0.1.2/30 |
| eth1 | SP2 eth0 | Underlay uplink | 10.0.5.2/30 |
| eth2 | Leaf2 eth2 | MLAG peer link | 10.0.20.1/30 |
| eth3 | SW1 Ethernet0/0 | Access trunk (via bond0) | - |
| lo | - | VTEP loopback | 10.255.1.1/32 |

## How to Apply Configuration

```bash
cat > /etc/frr/init.sh << 'EOF'
<paste init.sh content>
EOF
chmod +x /etc/frr/init.sh

cat > /etc/frr/frr.conf << 'EOF'
<paste frr.conf content>
EOF

bash /etc/frr/init.sh
sleep 2
service frr restart
```

## Verification

```bash
vtysh -c "show evpn vni"
vtysh -c "show bgp l2vpn evpn summary"
vtysh -c "show bgp l2vpn evpn route type 2"
vtysh -c "show bgp l2vpn evpn route type 5"
vtysh -c "show vrf vni"
vtysh -c "show ip route vrf vrf-tenA"
bridge vlan show
cat /proc/net/bonding/bond0
```

## Errors Encountered

**SVD mode failed - `vnifilter` unknown command**

The initial init.sh used SVD (Single VXLAN Device) mode with the `external vnifilter` flags on the vxlan0 interface. When run, the command failed with `vxlan: unknown command "vnifilter"`. The iproute2 version inside the FRR Docker container is 5.17.0 - it supports `external` but not `vnifilter`.

Attempted fix: remove `vnifilter`, use `external` only. This created the vxlan0 device but zebra registered it as VNI 0, not as individual VNIs. `show evpn vni` showed a single entry: `0 L2 vxlan0`. The L3VNIs showed `Vxlan-Intf: None` and `State: Down`.

Final fix: switched to per-VNI bridge architecture - one vxlan interface and one bridge per VNI. This works with all iproute2 versions and gives zebra unambiguous VNI-to-interface mapping.

**VLAN ID 50010 out of range**

In the SVD transition attempt, the init.sh used `bridge vlan add dev vxlan0 vid 50010` for the L3VNI VLAN mapping. This failed because VLAN IDs are limited to 1–4094. VNI numbers (up to 16 million) cannot be used directly as VLAN IDs.

Fix: use VLAN ID 100 mapped to VNI 50010, and VLAN ID 200 mapped to VNI 50020. The local VLAN ID is just a label - it does not need to match the VNI number.

**Bridge PVID wrong - H1 ARP not reaching leaf**

After MLAG was configured, H1 could not ping its gateway (10.10.1.1). Diagnosis showed H1's MAC appeared in the bridge FDB on bond0.10 but `ip neigh show dev vlan10` was empty - ARP requests were arriving but the leaf wasn't responding.

Root cause: `bridge vlan show dev bond0.10` showed `1 PVID Egress Untagged` - the bridge was treating all frames as VLAN 1, not VLAN 10. The L2VNI SVI (vlan10) expects VLAN 10 tagged frames inside br10.

Fix: enable `vlan_filtering 1` on br10, set `pvid untagged` for VLAN 10 on bond0.10, and delete the default VLAN 1 entry. Also add the VLAN to the vxlan and bridge interfaces explicitly.

**STP blocking trunk VLANs on SW1**

After fixing the bridge PVID issue, pings from H1 to the gateway still failed. `show interfaces trunk` on SW1 showed `Vlans in spanning tree forwarding state: none` - STP was blocking VLANs 10 and 20 on Po1.

Fix: `no spanning-tree vlan 10,20` on SW1, `no spanning-tree vlan 30,40` on SW2. The EVPN fabric handles loop prevention - STP is not needed and actively harmful on trunk ports toward the fabric.

**LACP system-mac mismatch - Et0/1 suspended**

After applying the bond, SW1's `show etherchannel summary` showed `Et0/0(P) Et0/1(s)` - only one member bundled. `show lacp neighbor` showed different Dev IDs for Et0/0 and Et0/1, meaning SW1 saw Leaf1 and Leaf2 as two separate devices.

Root cause: each leaf's bond0 starts with its own hardware MAC as the LACP system MAC. `ip link set bond0 address 44:38:39:FF:01:01` changed the interface MAC but did not update the LACP PDU system MAC.

Fix: write directly to the sysfs bonding parameter: `echo 44:38:39:FF:01:01 > /sys/class/net/bond0/bonding/ad_actor_system`. Both leaves must use the same value. After this, SW1 sees a single system MAC and bundles both ports.

**`RTNETLINK: Directory not empty` on init.sh re-run**

When init.sh was run a second time (after a partial run), it failed with `Directory not empty` and `Resource busy` errors. The `2>/dev/null || true` pattern suppresses errors but doesn't handle objects that already exist with members attached.

Fix: add a teardown block at the top of init.sh that removes bond subinterfaces, removes eth3 from bond, and deletes the bond before recreating it. This makes init.sh idempotent - safe to run multiple times.
