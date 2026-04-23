# SW1 - Access Layer Switch / Pod-1

## Role

SW1 is a Cisco IOSvL2 access switch connecting Ubuntu-H1 and Ubuntu-H2 to the fabric. It dual-homes to both Leaf1 and Leaf2 via a single LACP port-channel (Po1), providing redundant uplinks into the fabric without the hosts knowing about the redundancy.

From the hosts' perspective, SW1 is a normal access switch - H1 is on VLAN 10, H2 is on VLAN 20, each with a single Ethernet connection. The complexity of MLAG and dual-homing is entirely handled between SW1, Leaf1, and Leaf2.

## LACP Port-Channel Design

SW1's Po1 bundles Ethernet0/0 (toward Leaf1) and Ethernet0/1 (toward Leaf2) using LACP 802.3ad in active mode. Both leaves present the same LACP system MAC (`44:38:39:FF:01:01`) - this makes SW1's LACP state machine see a single logical peer, allowing both physical links to be bundled into one port-channel.

The port-channel carries VLANs 10 and 20 as a dot1q trunk. Leaf1 and Leaf2 receive the tagged frames and map them to the appropriate bridge (br10 or br20) via bond VLAN subinterfaces.

## Access Ports

Ethernet0/2 is an untagged access port on VLAN 10 for Ubuntu-H1. Ethernet0/3 is an untagged access port on VLAN 20 for Ubuntu-H2. Hosts send and receive untagged frames - SW1 adds and removes the VLAN tag.

## STP

STP is disabled on VLANs 10 and 20. In the initial configuration STP blocked Po1 on these VLANs, preventing any host traffic from reaching the fabric. The EVPN fabric and MLAG handle loop prevention - STP is not needed and actively harmful on trunk ports facing the fabric.

## Interface Assignments

| Interface | Connected To | Role | VLAN |
|---|---|---|---|
| Ethernet0/0 | Leaf1 eth3 | Po1 member - trunk | 10, 20 |
| Ethernet0/1 | Leaf2 eth3 | Po1 member - trunk | 10, 20 |
| Ethernet0/2 | Ubuntu-H1 eth0 | Access port | 10 |
| Ethernet0/3 | Ubuntu-H2 eth0 | Access port | 20 |
| Ethernet1/0–3/3 | - | Unused - shutdown | - |

## How to Apply Configuration

Connect via GNS3 console and paste the config block from `sw1.cfg` in enable mode:

```
enable
configure terminal
<paste config>
end
write memory
```

## Verification

```
show etherchannel summary
show lacp neighbor
show interfaces trunk
show vlan brief
show mac address-table
show interfaces status
show spanning-tree vlan 10
```

Expected state:
- Po1 shows `SU` (in use) with Et0/0(P) and Et0/1(P) both bundled
- LACP neighbor shows Dev ID `4438.39ff.0101` on both ports
- Trunk shows VLANs 10,20 in forwarding state on Po1
- Host MACs visible in mac address-table on their respective VLANs

## Errors Encountered

**Po1 showing `SD` - LACP suspended**

After initial configuration, Po1 showed status `SD` (suspended) and both member ports showed `s` (suspended). The LACP neighbor table was empty. This was expected at the time of SW config - the leaf side had not yet been configured with MLAG bonds. The port-channel became fully active only after Leaf1 and Leaf2 had their bond0 interfaces up with matching system-mac.

**`Vlans allowed on trunk: none` despite config being correct**

`show interfaces trunk` showed `none` for allowed VLANs on Et0/0 and Et0/1 even after `switchport trunk allowed vlan 10,20` was configured on both the physical interfaces and Port-channel1. Multiple approaches were tried including removing ports from the channel-group and re-adding them.

Root cause: This is an IOL behavior where the trunk VLAN mask on port-channel member ports requires exact matching between the physical interfaces and the port-channel. The `vlan mask is different` LACP error confirmed the mismatch. Setting VTP mode to transparent and reapplying the allowed VLAN list consistently across all three interfaces (Et0/0, Et0/1, Po1) resolved the display issue.

Note: the `none` display in `show interfaces trunk` did not prevent actual traffic forwarding once LACP was fully up - the STP blocking issue (below) was the actual traffic blocker.

**STP blocking Po1 trunk VLANs**

Despite the trunk being up and LACP bundled, H1 could not ping its gateway. Diagnosis traced the issue to `Vlans in spanning tree forwarding state: none` in `show interfaces trunk`. STP had put Po1 into blocking state for VLANs 10 and 20.

Root cause: When Po1 came up, STP ran its election process and determined these VLANs should be blocked - likely because the trunk faces two separate switches (Leaf1 and Leaf2) with no STP synchronization between them.

Fix: `no spanning-tree vlan 10` and `no spanning-tree vlan 20` on SW1. After this, `show interfaces trunk` showed both VLANs in forwarding state and host pings immediately succeeded.
