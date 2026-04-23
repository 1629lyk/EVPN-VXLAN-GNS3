# Leaf3 - VTEP / Pod-2 Primary

## Role

Leaf3 is the MLAG primary in Pod-2, paired with Leaf4. It serves Tenant-B hosts on VLANs 30 and 40. Pod-2 is functionally identical to Pod-1 but carries different tenant subnets and uses a different MLAG system-mac.

## Key Differences from Leaf1/Leaf2

- ASN is 65003
- Loopback is 10.255.1.3/32
- MLAG peer link is eth2, subnet 10.0.21.0/30 (different from Pod-1's 10.0.20.0/30)
- Connects to SW2 instead of SW1
- Bond carries VLANs 30 and 40 (not 10 and 20)
- MLAG system-mac is `44:38:39:FF:02:02` (different from Pod-1)
- eth0 connects to SP1 eth2, eth1 connects to SP2 eth2

## Interface Assignments

| Interface | Connected To | Purpose | IP |
|---|---|---|---|
| eth0 | SP1 eth2 | Underlay uplink | 10.0.3.2/30 |
| eth1 | SP2 eth2 | Underlay uplink | 10.0.7.2/30 |
| eth2 | Leaf4 eth2 | MLAG peer link | 10.0.21.1/30 |
| eth3 | SW2 Ethernet0/0 | Access trunk (via bond0) | - |
| lo | - | VTEP loopback | 10.255.1.3/32 |

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

## Errors Encountered

Same error set as Leaf1 and Leaf2. No unique errors specific to Leaf3. The bridge PVID fix applies to VLANs 30 and 40 instead of 10 and 20, and the MLAG system-mac is different, but all root causes and fixes are identical.
