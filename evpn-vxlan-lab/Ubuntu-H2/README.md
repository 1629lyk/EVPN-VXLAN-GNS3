# Ubuntu-H2 - Tenant-A Host / VLAN 20

## Role

Ubuntu-H2 is the second Tenant-A host, on VLAN 20. It uses `10.10.2.11/24` with gateway `10.10.2.1`. H2 is the destination for cross-subnet L3VNI tests from H1 - a successful ping from H1 to H2 confirms the full EVPN data plane is working including L3VNI inter-subnet routing.

## IP Configuration

```bash
ip addr add 10.10.2.11/24 dev eth0
ip link set eth0 up
ip route add default via 10.10.2.1
```

## Test Commands

```bash
# Should succeed - same tenant, different subnet
ping -c3 10.10.1.11

# Should succeed - gateway
ping -c3 10.10.2.1

# Should fail - different tenant
ping -c3 10.20.2.11
```

## Errors Encountered

None specific to H2.
