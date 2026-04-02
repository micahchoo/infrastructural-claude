# Load Balancing

Distributes incoming traffic across multiple resources for high availability and reliability.

## Why Load Balance?
- Route requests only to online resources
- No single server overworked
- Automatic inclusion of new servers
- Can load balance at every system layer (client → web servers → app servers → database)

## Workload Distribution
- **Host-based**: Routes by requested hostname
- **Path-based**: Routes by entire URL
- **Content-based**: Inspects message content (e.g., parameter values)

## Layers
- **Network layer (L4)**: Routes by IP/port. Fast, dedicated hardware. No content-based routing.
- **Application layer (L7)**: Reads full requests. Content-based routing. Full traffic understanding.

## Types
- **Software**: Flexible, cost-effective, configurable. Examples: installable or cloud-managed.
- **Hardware**: Physical devices, high volume, expensive, limited flexibility. Proprietary firmware.
- **DNS**: Configures domain to distribute across servers. Doesn't check for outages. Unreliable.

## Routing Algorithms
| Algorithm | Description |
|-----------|-------------|
| Round-robin | Rotation across servers |
| Weighted Round-robin | Accounts for server capacity via weights |
| Least Connections | Sends to server with fewest active connections |
| Least Response Time | Combines fastest response + fewest connections |
| Least Bandwidth | Routes to server with least Mbps traffic |
| Hashing | Distributes by key (client IP, request URL) |

## Redundant Load Balancers
Load balancer itself can be SPOF. Use N load balancers in cluster mode with active/passive failover.

## Key Features
Autoscaling, sticky sessions, healthchecks, persistent connections, SSL/TLS encryption, certificate management, compression, caching, logging, request tracing, redirects, fixed responses.

**Examples**: AWS ELB, Azure Load Balancing, GCP Load Balancing, DigitalOcean LB, Nginx, HAProxy.
