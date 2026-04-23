# Leaf4 - VTEP / Pod-2 Secondary

## Role

Leaf4 is the MLAG secondary in Pod-2, paired with Leaf3. Functionally identical to Leaf3 but with a different ASN, loopback, and peer link IP. Together with Leaf3 it provides redundant VTEP coverage for Tenant-B hosts behind SW2.

## Key Differences from Leaf3

- ASN is 65004
- Loopback is 10.255.1.4/32
- MLAG peer link IP is 10.0.21.2/30 (Leaf3 is 10.0.21.1)
- eth0 connects to SP1 eth3, eth1 connects to SP2 eth3
- MLAG system-mac is the same as Leaf3: `44:38:39:FF:02:02`

## Interface Assignments

| Interface | Connected To | Purpose | IP |
|---|---|---|---|
| eth0 | SP1 eth3 | Underlay uplink | 10.0.4.2/30 |
| eth1 | SP2 eth3 | Underlay uplink | 10.0.8.2/30 |
| eth2 | Leaf3 eth2 | MLAG peer link | 10.0.21.2/30 |
| eth3 | SW2 Ethernet0/1 | Access trunk (via bond0) | - |
| lo | - | VTEP loopback | 10.255.1.4/32 |

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

Identical to Leaf3. No unique errors.
