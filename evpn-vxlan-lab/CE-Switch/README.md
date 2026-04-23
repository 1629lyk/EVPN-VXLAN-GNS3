# CE-Switch - WAN Simulation / External Peering

## Role

CE-Switch simulates a customer edge or WAN router at the boundary of the EVPN fabric. It connects to Border-Leaf via eBGP and advertises two external prefixes into the fabric:

- `172.16.0.0/16` - simulated WAN prefix, sourced from Loopback0
- `192.168.254.0/24` - real VMnet8 subnet, providing actual reachability to the GNS3 VM and Win11 host

CE-Switch also has a DHCP-assigned IP on Ethernet0/1 toward the VMnet8 NAT cloud, giving it real internet connectivity - useful for verifying the external connectivity path.

## BGP Design

CE-Switch runs AS 65100 with a single eBGP session to Border-Leaf (AS 65005). It advertises both prefixes using network statements. The static `ip route 172.16.0.0 255.255.0.0 Null0` is required to make the network statement valid - without a route to the prefix in the routing table, BGP will not originate it.

CE-Switch also has static routes pointing tenant subnets back toward Border-Leaf. This provides the return path when Border-Leaf or fabric nodes initiate pings toward CE.

## Important - IOL L3 `no switchport` Requirement

The Cisco IOSvL3 image (`i86bi-linux-l3`) starts with ALL interfaces in Layer 2 switchport mode by default. Attempting to assign an IP address without first running `no switchport` results in the command being rejected. This applies to every routed interface.

## Interface Assignments

| Interface | Connected To | IP | Purpose |
|---|---|---|---|
| Ethernet0/0 | Border-Leaf eth2 | 10.0.11.2/30 | eBGP peering |
| Ethernet0/1 | Cloud-NAT (VMnet8) | DHCP (192.168.254.x) | WAN/internet |
| Loopback0 | - | 172.16.0.1/32 | Simulated WAN prefix |

## How to Apply Configuration

```
enable
configure terminal
<paste ce.cfg content>
end
write memory
```

## Verification

```
show ip bgp summary
show ip bgp neighbors 10.0.11.1
show ip route
show ip interface brief
ping 172.16.0.1
ping 10.0.11.1
```

Expected: BGP session to Border-Leaf established, both prefixes in BGP table with status `*>`, Ethernet0/1 showing DHCP-assigned IP.

## Errors Encountered

**Wrong image used - IOSvL2 instead of IOSvL3**

The initial CE-Switch node was created using the i86bi-linux-l2 image (same as SW1 and SW2) instead of the i86bi-linux-l3 image. The `show version` output revealed `i86bi-linux-l2` in the image filename. The L2 image cannot do IP routing or assign IP addresses to interfaces.

Fix: delete the node in GNS3, add a new node using the L3 image (`i86bi-linux-l3-jk9s-15.0.1`), rewire the two links, and reapply config. Always verify `show version` shows `l3` in the image filename before proceeding with IP configuration.

**`ip address` rejected on Ethernet0/0**

After correctly using the L3 image, `ip address 10.0.11.2 255.255.255.252` was still rejected. The IOSvL3 image starts all interfaces in switchport mode despite being an L3 image.

Fix: run `no switchport` on each interface before assigning IP addresses. This must be done on every routed port - Ethernet0/0 and Ethernet0/1 in this case. Loopback interfaces do not require `no switchport`.

**CE-Switch cannot ping GNS3 VM (192.168.254.133)**

CE-Switch has `192.168.254.134` on Ethernet0/1 and the GNS3 VM has `192.168.254.133` on the same VMnet8 subnet. Despite being on the same subnet, they cannot ping each other. VMware's VMnet8 NAT mode prevents direct communication between two devices on the same VMnet8 segment - traffic from one device to another on VMnet8 is not bridged locally.

This limitation means `192.168.254.0/24` reachability from fabric hosts to the GNS3 VM is blocked at the CE-VMnet8 boundary. The prefix is correctly distributed as a Type-5 route in EVPN, but actual pings from hosts to 192.168.254.133 fail because the return path through VMnet8 is blocked by VMware NAT isolation. This is a VMware networking constraint, not a routing or EVPN issue.
