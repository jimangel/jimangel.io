---
# not too long or too short (think G-search)
title: "VMware homelab 2023 [Part 1]: Introduction & Considerations"
date: 2022-12-31
# description is usually what's used in a google snippet
# informs and interests users with a short, relevant summary of what a particular page is about.
# They are like a pitch that convince the user that the page is exactly what they're looking for.
description: "Things to consider when planning to build a VMware homelab"
summary: "What to consider when building a VMware homelab like how many hosts, networking, storage, and more! This is the first post of a series that follows the complete process when building a multi-host VMware cluster at home"

tags:
- vmware
- homelab
- walkthrough
- nuc
keywords:
- VMware
- ESXi 7.0 U3
- vCenter 7.0 U3
- VCSA
- homelab
- NUC11PAHi7
- NUC11PAHi5
- Intel NUC 11 Pro
- NUC 11 Canyon


# !! DON'T FORGET: https://medium.com/p/import
# !! DON'T FORGET: https://medium.com/p/import
draft: true
# !! DON'T FORGET: https://medium.com/p/import
# !! DON'T FORGET: https://medium.com/p/import


#comments: false
cover:
    image: "img/vmware-lab-featured-p1.jpg"
    alt: "7 NUC computers mounted in a server rack with blue power on lights" # alt text
# check config.toml for some of the default options / toggles

# contain keywords relevant to the page's topic, and contain no spaces, underscores or other characters. You should avoid the use of parameters when possible, as they make URLs less inviting for users to click or share. Google's suggestions for URL structure specify using hyphens or dashes (-) rather than underscores (_). Unlike underscores, Google treats hyphens as separators between words in a URL.
slug: "vmware-series-p1-considerations"  # make your URL pretty!

---

In the fall of 2022, I decided to build a VMware homelab so I could explore [Anthos clusters on VMware](https://cloud.google.com/anthos/clusters/docs/on-prem/latest/overview) a bit closer. A few jobs back I administered VMware and in 2017 I blogged about [creating a single node VMware homelab](/posts/vmware-homelab-build-2017). I thought it _couldn't be that hard_ to build a multi-node VMware homelab with a few Intel NUCs. I was wrong.

> The difference in settings up a single node ESXi host vs. a cluster of 3 ESXi hosts was staggering. Mainly the networking design required.

At first I was going to update my older VMware install posts but, after hitting enough issues, it was clear I needed to start over. My goal is to start with an overview of things to consider before jumping in. Reading my series should save you many hours of problems if you have similar ambitions to build a multi-node lab.

This is Part **1** of a **3** part series I've called **_VMware homelab 2023_**:

- [This Page]: Introduction & Considerations
- [[Part 2]: How to install vSphere on a NUC](/posts/vmware-series-p2-installation/)
- [[Part 3]: How to configure vSphere networking and storage](/posts/vmware-series-p3-network-storage/)

**TL;DR:** Running a single node cluster avoids most of the following issues, but I wanted to run a VMware cluster closer to "real" production. Focusing on network design before jumping into ESXi installations will pay dividends.

## Overview

not many answers just things to consider and nudges in that direction.

in a bit review my goal and I have tutorials walking through how I create it. Feel free to borrow some or all for you own use!

## Audience

Outcome:

Expectations:

- vlan (basic networking)
- familiarity of vmware
- etcx

## Start with the end

By adding my goal here with more detail, you -the reader- can determine if the other articles are worth reading or if they aren't related to your issue. 

![diagram of 3 nucs and 1 qnap NAS networked together with various vLANs described for VMware](/img/vmware-homelab-2022.svg)

### Key points

- The network supports 2.5g and 1g NICs
- The switches are L3 and I can configure vLANs
- Operations (MGMT / vMotion / Storage) all go through the 2.5g switch using QoS
- The iSCSI/NAS appliance supports 2.5g
- VMware traffic is isolated to another 1g switch to prevent conflicts with operations


{{< notice warning >}}
VMware official docs recommend redundant NICs if there's 2 (instead of separating traffic like I plan on doing). If I didn't have 2.5g speeds on one and 1g on the other, I probably would combing the 2 NICs per host to do everything (including handling failover).
{{< /notice >}}

## Considerations

Three huge questions that drive clarity for the remaining questions

### 1) Why are you doing this?

My reason anthos on vmware.. etc

In addition, how much do you care about config? Is rebuilding many times a priority or a "like prod" env with upgrades on top?

TODO: EXPLAIN THE IMPACT OF EACH CHOICE

- DRS? (DRS for resource pools)
- vMotion? 
- NSX-T? 
- Tanzu?



### 2) To HA or not HA

Why are you chasing HA? Do the following support HA? Networking?

The 2 above should build a great foundation to shape the answers of the next sections.

### 3) How long do you plan on using this lab for?

Is the 60 day evaluation mode enough? Is it worth the $200 for the 1 year evaluation licenses?

1. VMUG membership ($200/y) gets us 1/y licenses to all products.

> VMUG Advantage is the best way to gain the technical skills to accelerate your success with exclusive access to 365-day evaluation licenses for 15+ VMware solutions, 20-35% discounts on VMware training and certifications, a discount off VMworld registration and more!
***NEW EVALExperience License: VMware vSphere with VMware Tanzu

VMUG is a group, VMUG advantage is pay-for-more stuff option. Once your membership is changed. log into the advantage protal:

https://vmugadvantage.onthehub.com/WebStore/Security/Signin.aspx?rurl=/WebStore/ProductsByMajorVersionList.aspx

> Your benefits aren't yet available - within 1 full business day you will receive an email from noreply@kivuto.com prompting you to create your account. 

### What hardware do you have?

- NUCs (USB adapters, network adapaters.. etc)
- boot disk? USB not really a thing anymore?
- 12th gen `cpuUniformityHardCheckPanic=FALSE`



#### Bootable ESXi USB is gone

https://blogs.vmware.com/vsphere/2021/09/esxi-7-boot-media-consideration-vmware-technical-guidance.html

![](https://i.imgur.com/XvFmb6I.png)


![](https://i.imgur.com/b7tWF1l.png)

> For best performance, also provide a separate persistent local device with a minimum of 32 GB to store the /scratch and VMware Tools partitions of the ESX-OSData volume. The optimal capacity for persistent local devices is 128 GB. The use of SD and USB devices for storing ESX-OSData partitions is being deprecated.

NUCs and "12? Gen" intel processors are not officially approved by VMware. Do you plan on using approved hardware or creating custom ISOs (as I include later)?

### What do you plan for storage?

local disk / iscsi / vsan

https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.esxi.upgrade.doc/GUID-DEB8086A-306B-4239-BF76-E354679202FC.html

![](https://i.imgur.com/vLhZHsw.png)

- vsan?
- vSAN disk == no partitions ( extra disks)

```
Maximum 1024 LUNs per vSAN cluster
Maximum 128 targets per vSAN cluster
Maximum 256 LUNS per target
Maximum LUN size of 62TB
Maximum 128 iSCSI sessions per host
Maximum 4096 iSCSI IO queue depth per host
Maximum 128 outstanding writes per LUN
Maximum 256 outstanding IOs per LUN
Maximum 64 client initiators per LUN
```

### What type of networking do you require?

vmware nics 101 / eli5

Plan on having more than 2 nics? Ensure your method has support, etc... (ie: USB driver installs or generic)

WAY MORE important if using multiple hosts.

> To return to your question, your vendor's best practices are going to come into play for how you setup a dVS.  Generally, I've setup a single dVS, with two port groups, two vmkernels, and Active/Unused and port binding.

IPV6?



### Firewall rules?

### Traffic misconceptions

https://devstime.com/2021/07/19/misconception-about-vmotion-traffic-usage/

## ESXi Networking Security Recommendations

Isolation of network traffic is essential to a secure ESXi environment. Different networks require a different access and level of isolation.

Your ESXi host uses several networks. Use appropriate security measures for each network, and isolate traffic for specific applications and functions. For example, ensure that VMware vSphere® vMotion® traffic does not travel over networks where virtual machines are located. Isolation prevents snooping. Having separate networks is also recommended for performance reasons.

vSphere infrastructure networks are used for features such as vSphere vMotion, VMware vSphere Fault Tolerance, VMware vSAN, and storage. Isolate these networks for their specific functions. It is often not necessary to route these networks outside a single physical server rack.
A management network isolates client traffic, command-line interface (CLI) or API traffic, and third-party software traffic from other traffic. This network should be accessible only by system, network, and security administrators. Use jump box or virtual private network (VPN) to secure access to the management network. Strictly control access within this network.
Virtual machine traffic can flow over one or many networks. You can enhance the isolation of virtual machines by using virtual firewall solutions that set firewall rules at the virtual network controller. These settings travel with a virtual machine as it migrates from host to host within your vSphere environment.

## Other lessons learned

- vCenter cannot be vMotioned. This makes sense, but I've learned the hard way. There is vCenter HA which could provide "true" HA.
- Related to the above, that made me want to move vCenter to my MGMT network so I can make VM changes without impacting connectivity.

### Health check scripts? SMS alerts?

### THEY REALLY WANT YOU TO JOIN THEIR PROGRAM:

![](https://i.imgur.com/vhWamYc.png)

## MVP recap for the next part of the series:

...