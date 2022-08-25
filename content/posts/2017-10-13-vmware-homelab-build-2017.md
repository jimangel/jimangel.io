---
title: 'Building a vSphere 6.5 Homelab 2017'
subtitle: 'For Under $600, If Possible...'
summary: 'Building an enterprise datacenter with a small footprint'
date: 2017-10-13
lastmod: 2017-10-13
featured: false
draft: false
math: false
authors:
- jimangel
tags:
- homelab
- vmware
categories: []

cover:
  image: /img/vmware-homelab-featured.jpg

aliases:
- "/post/vmware-homelab-build-2017/"

---

I'll be using this homelab to explore [vRealize Automation](https://www.vmware.com/products/vrealize-automation.html) using my VMUG [EVALExperience](https://www.vmug.com/Join/EVALExperience) subscription. I'd like this homelab not to take up a ton of power when running 24/7. Lastly, I'd like the server to look nice if it was out in the open.

### Wish list
* Under $600
* 4+ core CPU
* Enough RAM to handle a handful of VMs
* Very small footprint (no 2U rack servers)

### My Build
* Intel NUC NUC6i7KYK ($325 - ebay)
* Samsung 850 EVO ($110)
* Crucial 16GB RAM ($145)
* **TOTAL COST:** $580

![nuc-promo](/img/nuc-promo.jpg#center)

### Breakdown
#### Intel NUC
The [Intel NUC NUC6i7KYK](https://amzn.to/2yoR93a) has a i7 6770HQ CPU. This i7 has 4 cores and 8 threads to run a handful of VMs on. All other NUC's (including other i7s) only have 2 cores.

With a 120 watt PSU, including reports of it utilizing less than 20 watts idle, makes it a perfect server to run 24/7.

Also, it is SMALL. I think the specs and promo pics don't do it justice.

![nuc](/img/nuc.jpg#center)

This Intel NUC has everything I need.

#### SSD
A [Samsung 850 EVO](https://amzn.to/2yKLG8B) with 250GB is the perfect compliment for my ESXi host. The NUC supports x2 M.2 SSD HDDs and this will be a great start. I also can use the SSD for a local VMFS datastore that is stupid fast. I plan on using this for all of my mission critical VMs.

#### RAM
Using a single stick of [Crucial 16GB RAM](https://amzn.to/2ylpbDP), I leave the option open to expand to a MAX of 32GB if needed.

### Conclusion
This setup will be _plenty_ to get my feet wet with vRealize. It's also built in a way that I can add more hosts (VMware Datacenter Cluster) or expand my existing server hardware. For now, this will be perfect to leave in my living room without overtaking any other device. I'm thrilled with the bang for the buck on my new lab.

View my upcoming posts for what it looks like to install vSphere 6.5 U1!
