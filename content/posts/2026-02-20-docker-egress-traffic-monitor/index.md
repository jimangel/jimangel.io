---
title: "How to Restrict Container Internet Access with a Squid Proxy"
date: 2026-02-20
description: "A simple guide to blocking and allowlisting internet access for containers using internal networks and a Squid proxy."
summary: "Use Docker's internal networks and a Squid proxy to give your containers domain-level internet allowlisting with just two files and zero iptables."
tags:
- docker
- networking
- squid
- security
keywords:
- Docker
- Docker Compose
- Squid Proxy
- Internal Network
- Container Security
- Network Isolation
- Domain Allowlist
- Block Internet Docker
- Docker Networking
- iptables

draft: false

cover:
   # image: "img/docker-squid-proxy.png"
    #alt: "Docker containers with controlled internet access via Squid proxy"
    #relative: true

slug: "docker-block-internet-squid-proxy"
---

Need to run containers locally but control exactly which external domains they can reach? 

Docker's `internal` networks block all internet access — and by adding a L7 Squid proxy as the only gateway out, you get clean domain-level allowlisting.

## The Concept

```
┌────────────────────────────────────┐
│         internal network           │
│                                    │
│   ┌──────┐          ┌───────┐      │
│   │ app1 │─────────►│       │      │
│   └──────┘          │ squid │─────────► internet (allowed domains only)
│   ┌──────┐          │       │      │
│   │ app2 │─────────►│       │      │
│   └──────┘          └───────┘      │
│                                    │
└────────────────────────────────────┘
```

- `app1` and `app2` sit on an **internal** network — no direct route to the internet.
- `squid` sits on **both** the internal network and a normal network, acting as the only door out.
- Squid's config decides which domains are allowed. Everything else is denied.

## Docker Compose Setup

```
mkdir ~/demo && cd ~/demo

#~/demo
# ├── docker-compose.yml
# └── squid.conf
```

### squid.conf

```squid
cat <<'EOF' > squid.conf
# Allowlisted domains — edit this list to suit your needs
acl allowed_domains dstdomain .github.com
acl allowed_domains dstdomain .pypi.org
acl allowed_domains dstdomain .google.com

# Standard ports
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 443

# Allow CONNECT for HTTPS
acl CONNECT method CONNECT

# Access rules
http_access allow CONNECT SSL_ports allowed_domains
http_access allow allowed_domains
http_access deny all

# Listener
http_port 3128
EOF
```

Edit the `acl allowed_domains` lines for your needs.

### docker-compose.yml

You may take this architecture and apply it to any existing compose file, just add the squid service and update the networks. Here's a complete demo for reference:

```yaml
cat <<'EOF' > docker-compose.yml
services:
  squid:
    image: ubuntu/squid
    container_name: squid
    networks:
      - internal
      - external
    volumes:
      - ./squid.conf:/etc/squid/squid.conf:ro

  app1:
    image: curlimages/curl
    container_name: app1
    entrypoint: ["sleep", "3600"]
    environment:
      - http_proxy=http://squid:3128
      - https_proxy=http://squid:3128
    networks:
      - internal
    depends_on:
      - squid

  app2:
    image: curlimages/curl
    container_name: app2
    entrypoint: ["sleep", "3600"]
    environment:
      - http_proxy=http://squid:3128
      - https_proxy=http://squid:3128
    networks:
      - internal
    depends_on:
      - squid

networks:
  internal:
    internal: true    # no internet access for containers on this network
  external:
    driver: bridge    # normal network — squid uses this to reach the internet
EOF
```

Key details: the `internal: true` network has no route out. The app containers only connect to that network. Squid connects to both, so it's the sole gateway — and it only forwards requests to domains you've explicitly allowed.

## Start the continers

```bash
docker compose up -d
```

## Validate Everything (All-in-one check)

```bash
echo "=== Allowed domain ===" && \
STATUS=$(docker exec app1 curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://www.google.com) && \
[ "$STATUS" = "200" ] && echo "✅ PASS ($STATUS)" || echo "❌ FAIL ($STATUS)" && \
echo "=== Blocked domain ===" && \
STATUS=$(docker exec app1 curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://example.com) && \
[ "$STATUS" = "403" ] && echo "✅ BLOCKED (good - $STATUS)" || echo "❌ FAIL ($STATUS)" && \
echo "=== Direct internet ===" && \
docker exec app1 curl -sS --noproxy '*' --connect-timeout 3 http://8.8.8.8 2>&1 && echo "❌ FAIL (leaked)" || echo "✅ BLOCKED (good)" && \
echo "=== Container-to-container ===" && \
docker exec app1 curl -sS --noproxy '*' --connect-timeout 3 http://app2:12345 2>&1 | grep -q "Failed to connect" && echo "✅ PASS (reachable)" || echo "❌ FAIL"
```

## Adding or Removing Domains

Edit `squid.conf` and restart:

```bash
# Add a new domain to squid.conf, then:
docker compose restart squid
```

## Cleanup

```bash
docker compose down
```