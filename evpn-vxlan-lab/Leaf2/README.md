# Leaf2 - VTEP / Pod-1 Secondary

## Role

Leaf2 is the MLAG secondary in Pod-1, paired with Leaf1. It serves the same tenant subnets and VNIs as Leaf1 - both leaves present the same anycast gateway IPs to hosts. SW1's Po1 has one member on Leaf1 and one on Leaf2, giving hosts dual-homed connectivity into the fabric.

When Leaf1's spine uplinks fail, SW1's LACP bond continues forwarding via the Leaf2 member. This is what produced 0% packet loss in the Phase 6 failure test - the MLAG bond kept the access layer alive independently of the spine uplink state.

## Key Differences from Leaf1

- ASN is 65002 (Leaf1 is 65001)
- Loopback is 10.255.1.2/32
- MLAG peer link IP is 10.0.20.2/30 (Leaf1 is 10.0.20.1)
- eth0 connects to SP1 eth1, eth1 connects to SP2 eth1
- MLAG system-mac is the same as Leaf1: `44:38:39:FF:01:01`

## Interface Assignments

| Interface | Connected To | Purpose | IP |
|---|---|---|---|
| eth0 | SP1 eth1 | Underlay uplink | 10.0.2.2/30 |
| eth1 | SP2 eth1 | Underlay uplink | 10.0.6.2/30 |
| eth2 | Leaf1 eth2 | MLAG peer link | 10.0.20.2/30 |
| eth3 | SW1 Ethernet0/1 | Access trunk (via bond0) | - |
| lo | - | VTEP loopback | 10.255.1.2/32 |

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

Same commands as Leaf1. Cross-check that `show evpn vni` shows identical VNI table with different remote VTEP IPs.

## Errors Encountered

All errors on Leaf2 are identical to Leaf1 - SVD failure, VLAN ID out of range, bridge PVID, LACP system-mac. Refer to Leaf1 README for full details. The fixes applied to Leaf1 were replicated exactly on Leaf2 with the only differences being the loopback IP and MLAG peer link IP.
