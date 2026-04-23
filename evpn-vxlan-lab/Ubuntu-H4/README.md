# Ubuntu-H4 - Tenant-B Host / VLAN 40

## Role

Ubuntu-H4 is the second Tenant-B host, on VLAN 40. It uses `10.20.2.11/24` with gateway `10.20.2.1`. It is the cross-subnet ping target for H3 - confirming L3VNI inter-subnet routing works for Tenant-B independently.

## IP Configuration

```bash
ip addr add 10.20.2.11/24 dev eth0
ip link set eth0 up
ip route add default via 10.20.2.1
```

## Test Commands

```bash
# Should succeed - same tenant, different subnet
ping -c3 10.20.1.11

# Should fail - different tenant
ping -c3 10.10.2.11
```

## Errors Encountered

None specific to H4.
