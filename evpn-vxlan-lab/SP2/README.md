# SP2 - Spine 2

## Role

SP2 is the second spine node, identical in function to SP1. Together they provide redundant ECMP paths between all leaves. Every leaf has one uplink to SP1 and one uplink to SP2 - giving two equal-cost paths to every other leaf in the fabric.

SP2 runs the same AS (65000) as SP1. This shared spine AS is standard in eBGP leaf-spine designs and simplifies peer-group configuration on the leaves.

## BGP Design

Identical to SP1. SP2 peers with all four leaves and the border leaf via eBGP. It advertises its own loopback and relays all leaf loopbacks between peers. The `next-hop-self` configuration ensures leaves can always reach the next-hop for any advertised prefix.

## ECMP Behavior

When a leaf receives a prefix (say Leaf3's loopback 10.255.1.3/32), it receives it from both SP1 and SP2. Because `bgp bestpath as-path multipath-relax` is configured, both paths are installed as equal-cost. Traffic to Leaf3 is load-balanced across both spine uplinks at the leaf.

## Interface Assignments

| Interface | Connected To | IP |
|---|---|---|
| eth0 | Leaf1 eth1 | 10.0.5.1/30 |
| eth1 | Leaf2 eth1 | 10.0.6.1/30 |
| eth2 | Leaf3 eth1 | 10.0.7.1/30 |
| eth3 | Leaf4 eth1 | 10.0.8.1/30 |
| eth4 | Border-Leaf eth1 | 10.0.10.1/30 |
| lo | - | 10.255.0.2/32 |

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
```

Expected: 5 BGP neighbors all Established, 5 BFD sessions all up.

## Errors Encountered

No unique errors on SP2. The same missing `network 10.255.0.2/32` issue that affected SP1 also affected SP2 - see SP1 README for details. The fix is identical: add the loopback network statement inside `address-family ipv4 unicast`.
