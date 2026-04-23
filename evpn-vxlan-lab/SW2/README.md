# SW2 - Access Layer Switch / Pod-2

## Role

SW2 is functionally identical to SW1 but serves Pod-2 - Tenant-B hosts on VLANs 30 and 40. It dual-homes to Leaf3 and Leaf4 via Po1 using the same LACP 802.3ad design. The MLAG system-mac on Leaf3 and Leaf4 is `44:38:39:FF:02:02` - different from Pod-1 but the same principle.

## Key Differences from SW1

- VLANs are 30 and 40 instead of 10 and 20
- Ethernet0/0 connects to Leaf3 (not Leaf1)
- Ethernet0/1 connects to Leaf4 (not Leaf2)
- Ethernet0/2 connects to Ubuntu-H3 (VLAN 30)
- Ethernet0/3 connects to Ubuntu-H4 (VLAN 40)
- STP disabled on VLANs 30 and 40

## Interface Assignments

| Interface | Connected To | Role | VLAN |
|---|---|---|---|
| Ethernet0/0 | Leaf3 eth3 | Po1 member - trunk | 30, 40 |
| Ethernet0/1 | Leaf4 eth3 | Po1 member - trunk | 30, 40 |
| Ethernet0/2 | Ubuntu-H3 eth0 | Access port | 30 |
| Ethernet0/3 | Ubuntu-H4 eth0 | Access port | 40 |
| Ethernet1/0–3/3 | - | Unused - shutdown | - |

## How to Apply Configuration

```
enable
configure terminal
<paste sw2.cfg content>
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
```

## Errors Encountered

Identical errors to SW1. STP blocking was the primary issue and was resolved with `no spanning-tree vlan 30,40`. The VLAN trunk mask display issue was also present and resolved identically to SW1.
