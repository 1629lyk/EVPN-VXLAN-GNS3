# SP1 - Spine 1

## Role

SP1 is one of two spine nodes in the leaf-spine fabric. Spines provide pure IP transit for the underlay - they carry no VXLAN tunnels, no VRFs, and no host routes. Every leaf and the border leaf peers with SP1 via eBGP, giving SP1 a full view of all VTEP loopbacks across the fabric.

SP1 also participates in the l2vpn evpn address-family to relay EVPN routes between leaves. It does not originate EVPN routes - it only reflects what it receives from one leaf toward all others.

## BGP Design

SP1 runs AS 65000 shared with SP2. All leaf nodes run different ASNs (65001–65005). This eBGP design means no route reflection is needed - every leaf-to-spine session is an external BGP session and routes are forwarded naturally.

The `bgp bestpath as-path multipath-relax` command allows ECMP across paths with different AS paths - required for equal-cost load balancing when two spines advertise the same prefix with different AS paths prepended.

`next-hop-self` is configured toward leaves so that SP1 rewrites the BGP next-hop to itself when advertising loopbacks learned from other leaves. Without this, a leaf would receive a route with a next-hop IP it has no direct route to.

## BFD

BFD runs on all five neighbor sessions. With 300ms transmit/receive intervals and a detect-multiplier of 3, failure detection occurs within 900ms. BFD operates independently of BGP timers - it detects link failures much faster than BGP hold timers would allow.

## EVPN Relay

SP1 activates the l2vpn evpn address-family for all leaf neighbors. It does not configure `advertise-all-vni` - that command is only for VTEPs. SP1 simply passes EVPN routes between leaves without interpreting them.

## Interface Assignments

| Interface | Connected To | IP |
|---|---|---|
| eth0 | Leaf1 eth0 | 10.0.1.1/30 |
| eth1 | Leaf2 eth0 | 10.0.2.1/30 |
| eth2 | Leaf3 eth0 | 10.0.3.1/30 |
| eth3 | Leaf4 eth0 | 10.0.4.1/30 |
| eth4 | Border-Leaf eth0 | 10.0.9.1/30 |
| lo | - | 10.255.0.1/32 |

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
vtysh -c "show bfd peers"
vtysh -c "show ip route"
vtysh -c "show bgp l2vpn evpn summary"
```

Expected: 5 BGP neighbors all Established, 5 BFD sessions all up, all leaf and border-leaf loopbacks in routing table.

## Errors Encountered

**SP1 and SP2 loopbacks missing from leaf routing tables**

After Phase 2 config was applied, leaves could not ping the spine loopbacks (10.255.0.1 and 10.255.0.2). The `show ip route` on any leaf was missing these two entries.

Root cause: The `network 10.255.0.1/32` statement was missing from the `address-family ipv4 unicast` block in frr.conf. Spines were advertising leaf loopbacks (learned via BGP) but not their own loopbacks.

Fix: Add `network 10.255.0.1/32` inside `address-family ipv4 unicast` under `router bgp 65000`.

This fix must also be applied to SP2 with its own loopback address.
