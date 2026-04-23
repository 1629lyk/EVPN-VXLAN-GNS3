# Ubuntu-H3 - Tenant-B Host / VLAN 30

## Role

Ubuntu-H3 is the first Tenant-B host, on VLAN 30 behind SW2. It uses `10.20.1.11/24` with gateway `10.20.1.1`. H3 validates Pod-2 EVPN and MLAG functionality independently of Pod-1.

## IP Configuration

```bash
ip addr add 10.20.1.11/24 dev eth0
ip link set eth0 up
ip route add default via 10.20.1.1
```

## Test Commands

```bash
# Should succeed - same tenant, different subnet
ping -c3 10.20.2.11

# Should fail - different tenant
ping -c3 10.10.1.11
```

## Errors Encountered

None specific to H3.
