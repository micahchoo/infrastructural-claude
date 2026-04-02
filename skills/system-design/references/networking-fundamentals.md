# Networking Fundamentals

## IP Addresses

An IP address uniquely identifies a device on a network.

### Versions
- **IPv4**: 32-bit numeric dot-decimal (e.g., `102.22.192.181`). ~4 billion addresses.
- **IPv6**: 128-bit alphanumeric hex (e.g., `2001:0db8:85a3:0000:0000:8a2e:0370:7334`). ~340e+36 addresses.

### Types
- **Public**: One primary address for your whole network (assigned by ISP)
- **Private**: Unique per device within your local network (assigned by router)
- **Static**: Manually created, doesn't change. More expensive, more reliable.
- **Dynamic**: Assigned by DHCP, changes over time. Cheaper, allows IP reuse.

## OSI Model

Seven-layer model for network communication:

| Layer | Name | Function |
|-------|------|----------|
| 7 | Application | Protocols like HTTP, SMTP. Interfaces with user software. |
| 6 | Presentation | Translation, encryption/decryption, compression |
| 5 | Session | Opens/closes communication sessions, synchronizes with checkpoints |
| 4 | Transport | End-to-end communication, breaks data into segments |
| 3 | Network | Routing between different networks, breaks segments into packets |
| 2 | Data Link | Transfer between devices on same network, breaks packets into frames |
| 1 | Physical | Physical equipment (cables, switches), bit stream transmission |

## TCP vs UDP

| Feature | TCP | UDP |
|---------|-----|-----|
| Connection | Requires established connection | Connectionless |
| Guaranteed delivery | Yes | No |
| Re-transmission | Yes | No |
| Speed | Slower | Faster |
| Broadcasting | No | Yes |
| Use cases | HTTPS, HTTP, SMTP, POP, FTP | Video streaming, DNS, VoIP |

**TCP**: Connection-oriented, reliable, ordered delivery. Higher overhead.
**UDP**: Connectionless, no error recovery. Preferred for real-time where late data is worse than lost data.

## DNS (Domain Name System)

Hierarchical, decentralized system translating domain names to IP addresses.

### Lookup Flow
1. Client queries DNS resolver
2. Resolver queries root nameserver
3. Root responds with TLD address
4. Resolver queries TLD (e.g., `.com`)
5. TLD responds with domain's nameserver IP
6. Resolver queries domain's nameserver
7. Nameserver returns IP
8. Resolver returns IP to client

### Server Types
- **DNS Resolver**: First stop, recursive middleman. Caches results.
- **Root Server**: 13 types (with Anycast copies worldwide). Directs to TLD.
- **TLD Nameserver**: Manages extensions (`.com`, `.org`, `.uk`, etc.)
- **Authoritative DNS Server**: Final step, holds actual domain records.

### Query Types
- **Recursive**: Server must return answer or error
- **Iterative**: Server returns best answer or referral
- **Non-recursive**: Answer already cached, immediate response

### Record Types
| Record | Purpose |
|--------|---------|
| A | IPv4 address of domain |
| AAAA | IPv6 address of domain |
| CNAME | Alias to another domain (no IP) |
| MX | Mail server |
| TXT | Text notes (often email security) |
| NS | Name server for DNS entry |
| SOA | Admin info about domain |
| SRV | Port for specific services |
| PTR | Reverse lookup (IP → domain) |

### DNS Caching
Records cached with TTL (time-to-live). When TTL hits zero, record purged and re-resolved.

### Reverse DNS
Query domain from IP using PTR records. Used by email servers for validation.

**Managed DNS examples**: Route53, Cloudflare DNS, Google Cloud DNS, Azure DNS, NS1.
