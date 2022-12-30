---
title: 'EdgeRouter OS CLI Cheatsheet'
subtitle: 'Most common commands used on my Ubiquiti EdgeRouter Lite ERL'
description: "Most common commands used on my Ubiquiti EdgeRouter Lite ERL"
summary: 'Most common commands used on my Ubiquiti EdgeRouter Lite ERL'
date: 2018-04-22
lastmod: 2018-04-22
featured: false
draft: false
authors:
- jimangel
tags:
- cheatsheets
categories: []
keywords:
- dns forwarding edgerouter
- cheatsheets
- EdgeRouter
- edgerouter show config
- edgerouter cli commands

cover:
  image: "img/edgerouter-cheatsheet-featured.jpg"
  alt: "Network patch panel zoomed in on a blue cable plugging into port 074 in between 8 grey cables" # alt text

slug: ""
---

These are my frequently used `EdgeRouter OS` commands for Ubiquiti's EdgeRouter Lite (ERL).

You can enable SSH from the GUI (web interface) under `System`; check the box to enable the SSH server. Only enable SSH if you fully understand the risk of doing so.

## Basics

```bash
# access ssh
ssh <admin username>@<EdgeRouterIP>

# enter editing mode
configure

# saving changes
# NOTE: if you did not save, a reboot should roll back the changes.
commit ; save
# or
commit ; save ; exit

# use 'exit discard' to discard the changes and exit.

# rolling back changes
# shows versions
rollback ?
# reboot and revert to a previous version
rollback 2

# NOTE: swap 'set' with 'delete' to delete the change
```

## DNS Management

Assuming your ERL/ERX provides DHCP and is your primary DNS server.

### Set A records

```bash
# set a static fqdn to an IP
set system static-host-mapping host-name <test.testdomain.com> inet <1.1.1.1>
commit
# optional 'save'
exit

# to view mappings (in config mode)
show/delete system static-host-mapping

# set a wildcard DNS name for *.example.com
set service DNS forwarding options 'address=/example.com/172.16.0.2'
```
### Increase DNS cache on the router

```bash
# optional 'show dns forwarding statistics'

# set cache to 1000
set service dns forwarding cache-size 1000
```

### Set DNS forwarders

```bash
# optional 'show dns forwarding nameservers'

# follow a strict order
set service dns forwarding options strict-order

# set DNS forwarders to cloud flare
set service dns forwarding name-server 1.1.1.1
set service dns forwarding name-server 1.0.0.1
```



### Add Cloudflare DDNS provider

Set [Cloudflare](https://www.cloudflare.com/) to handle your dynamic IP.

```bash
# set CF DDNS on the EdgeRouter
set service dns dynamic interface eth0 service custom-cloudflare host-name www.yoursite.com
set service dns dynamic interface eth0 service custom-cloudflare login your_cloudflare_email
set service dns dynamic interface eth0 service custom-cloudflare password your_cloudflare_global_API_key
set service dns dynamic interface eth0 service custom-cloudflare protocol cloudflare
set service dns dynamic interface eth0 service custom-cloudflare server www.cloudflare.com
set service dns dynamic interface eth0 service custom-cloudflare options "zone=yoursite.com"
```
