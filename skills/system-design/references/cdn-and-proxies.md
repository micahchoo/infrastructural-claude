# CDN and Proxies

## Content Delivery Network (CDN)

Geographically distributed servers providing fast delivery of static content (HTML/CSS/JS, images, videos).

### How It Works
Origin server has original content. Edge servers distributed worldwide cache content. Users served from nearest edge location, reducing latency and origin load.

### Types

**Push CDN**: Content uploaded directly when changes occur. You manage uploads and URL rewriting. Good for low-traffic sites or infrequently updated content. Minimizes traffic, maximizes storage.

**Pull CDN**: Cache updated on request. If CDN doesn't have content, fetches from origin and caches. Good for high-traffic sites. Only recently-requested content remains cached.

### Disadvantages
- Extra cost (especially high traffic)
- Domain/IP blocking by some organizations/countries
- Performance penalty if audience far from CDN servers

**Examples**: Amazon CloudFront, Google Cloud CDN, Cloudflare CDN, Fastly.

---

## Proxies

Intermediary between client and backend. Filters, logs, or transforms requests.

### Forward Proxy
Sits in front of clients. Intercepts outgoing requests.
- Blocks certain content
- Access geo-restricted content
- Provides anonymity
- Bypass browsing restrictions

### Reverse Proxy
Sits in front of origin servers. Intercepts incoming requests.
- Improved security
- Caching
- SSL encryption
- Load balancing
- Scalability and flexibility

### Load Balancer vs Reverse Proxy
- LB useful with multiple servers. Reverse proxy useful even with one server.
- Reverse proxy CAN act as load balancer. Not vice versa.

**Examples**: Nginx, HAProxy, Traefik, Envoy.
