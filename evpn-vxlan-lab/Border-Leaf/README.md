# Border-Leaf - Fabric Edge / External Peering

## Role

Border-Leaf is the translation point between the EVPN fabric and the outside world. Everything inside the fabric speaks VXLAN and BGP EVPN. The outside world (CE-Switch and beyond) speaks plain eBGP. Border-Leaf bridges these two worlds.

It performs two functions simultaneously. Inbound: it receives external BGP prefixes from CE-Switch and redistributes them into the EVPN fabric as Type-5 routes, making them visible in all tenant VRF routing tables across all four leaves. Outbound: when tenant hosts send traffic to external destinations, it arrives via VXLAN L3VNI encapsulation, gets decapsulated at Border-Leaf, and is forwarded to CE-Switch via plain eBGP next-hop.

Border-Leaf also runs the full VTEP stack - it has L3VNI interfaces for both tenants so it can participate in EVPN Type-5 route exchange.

## BGP Design

Border-Leaf has three BGP sessions:
- SP1 (10.0.9.1) - eBGP, AS 65000, spine peer
- SP2 (10.0.10.1) - eBGP, AS 65000, spine peer
- CE-Switch (10.0.11.2) - eBGP, AS 65100, external peer

The spine sessions use the SPINES peer-group with `next-hop-self` to ensure underlay loopbacks are reachable. The CE session is a plain external eBGP session without any special flags.

## VRF Import - External Route Leaking

CE-Switch advertises two prefixes into the Border-Leaf default VRF:
- `172.16.0.0/16` - simulated WAN prefix (CE Loopback0)
- `192.168.254.0/24` - real VMnet8 subnet

The `import vrf default` command under each tenant VRF BGP instance pulls these prefixes from the default VRF routing table into the tenant VRF routing tables. This is what makes `172.16.0.0/16` appear in `show ip route vrf vrf-tenA` on all leaves as a Type-5 route pointing to Border-Leaf's VTEP.

## Known Limitation - Inter-VRF Forwarding

While the control plane correctly distributes external routes into all tenant VRFs, the actual packet forwarding from a tenant VRF to CE-Switch requires crossing from vrf-tenA into the default VRF to exit via eth2. Linux does not forward packets across VRF boundaries to interfaces that belong to a different VRF without explicit configuration.

The `ip route get vrf vrf-tenA 172.16.0.1` command shows the correct result - the kernel knows the route and the egress interface. However, because eth2 is in the default VRF (not vrf-tenA), the kernel rejects actual forwarding. iptables MASQUERADE does not intercept l3mdev-forwarded traffic.

In production hardware this is handled natively by the ASIC. In this lab the limitation is documented and the control plane story (Type-5 distribution) is fully demonstrated. Border-Leaf itself can reach CE from the default VRF with no issues.

## Interface Assignments

| Interface | Connected To | Purpose | IP |
|---|---|---|---|
| eth0 | SP1 eth4 | Underlay uplink | 10.0.9.2/30 |
| eth1 | SP2 eth4 | Underlay uplink | 10.0.10.2/30 |
| eth2 | CE-Switch Ethernet0/0 | External eBGP peering | 10.0.11.1/30 |
| lo | - | VTEP loopback | 10.255.1.5/32 |

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
vtysh -c "show bgp summary"
vtysh -c "show ip bgp"
vtysh -c "show evpn vni"
vtysh -c "show vrf vni"
vtysh -c "show ip route vrf vrf-tenA"
ping -c3 172.16.0.1
ping -c3 192.168.254.134
```

Expected: CE session established with 2 prefixes received, both external prefixes in `show ip bgp`, both L3VNIs in state Up, external prefixes in vrf-tenA routing table.

## Errors Encountered

**`redistribute bgp` did not pull CE routes into tenant VRFs**

The initial frr.conf used `redistribute bgp` under `router bgp 65005 vrf vrf-tenA`. The intent was to pull CE-learned BGP routes from the default VRF into the tenant VRF. This had no effect because `redistribute bgp` only redistributes BGP routes that originated within the same VRF context - CE routes live in the default VRF BGP table, not in vrf-tenA's BGP table.

Fix: replace `redistribute bgp` with `import vrf default` under `address-family ipv4 unicast` in each per-VRF BGP instance. This correctly leaks all default VRF routes (including CE-learned ones) into the tenant VRF routing table.

**Inter-VRF packet forwarding failed despite correct routing table**

After `import vrf default` was applied, `show ip route vrf vrf-tenA` correctly showed `172.16.0.0/16 via 10.0.11.2 dev eth2`. However `ip vrf exec vrf-tenA ping 172.16.0.1` still failed.

Diagnosis: `ip route get vrf vrf-tenA 172.16.0.1` returned `via 10.0.11.2 dev eth2 src 10.0.11.1` - the kernel knows the path. The failure is that eth2 belongs to the default VRF. When a packet from vrf-tenA tries to egress via eth2, the kernel rejects it because eth2 is not a member of vrf-tenA.

Multiple fixes were attempted - veth pairs, iptables MASQUERADE, sysctl forwarding - none resolved the cross-VRF forwarding for l3mdev traffic. This is a documented Linux kernel VRF limitation for this architecture. The control plane is correct; the data plane cross-VRF forwarding requires hardware ASIC support or a dedicated sub-interface per tenant VRF facing CE.

**vxlan50010 TX drop counter incrementing**

`ip -s link show vxlan50010` showed TX dropped packets accumulating. This was observed when testing VRF pings - packets were being generated inside the VRF but dropped at the VXLAN egress because there was no valid RMAC/FDB entry programmed for the destination. After proper EVPN convergence the drop counter stabilized.
