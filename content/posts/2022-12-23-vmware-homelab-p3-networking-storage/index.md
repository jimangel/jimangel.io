---
# not too long or too short (think G-search)
title: "VMware homelab [Part 3]: How to configure vSphere networking and storage"
date: 2022-12-31
# description is usually what's used in a google snippet
# informs and interests users with a short, relevant summary of what a particular page is about.
# They are like a pitch that convince the user that the page is exactly what they're looking for.
description: "Setting up a VMware cluster and adjusting the configuration for networking and storage"
summary: "The third post of a VMware homelab series covering the configuration for networking and storage in a vSphere 7 cluster"
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
# from https://unsplash.com/photos/ute2XAFQU2I
cover:
    image: "img/vmware-lab-featured-p3.jpg"
    alt: "Hands above a laptop keyboard with a black screen" # alt text
# check config.toml for some of the default options / toggles

# contain keywords relevant to the page's topic, and contain no spaces, underscores or other characters. You should avoid the use of parameters when possible, as they make URLs less inviting for users to click or share. Google's suggestions for URL structure specify using hyphens or dashes (-) rather than underscores (_). Unlike underscores, Google treats hyphens as separators between words in a URL.
slug: "vmware-series-p3-network-storage"  # make your URL pretty!


---

In the fall of 2022, I decided to build a VMware homelab so I could explore [Anthos clusters on VMware](https://cloud.google.com/anthos/clusters/docs/on-prem/latest/overview) a bit closer. A few jobs back I administered VMware and in 2017 I blogged about [creating a single node VMware homelab](/posts/vmware-homelab-build-2017). I thought it _couldn't be that hard_ to build a multi-node VMware homelab with a few Intel NUCs. I was wrong.

> The difference in settings up a single node ESXi host vs. a cluster of 3 ESXi hosts was staggering. Mainly the networking design required.

At first I was going to update my older VMware install posts but, after hitting enough issues, it was clear I needed to start over. My goal is to start with an overview of things to consider before jumping in. Reading my series should save you many hours of problems if you have similar ambitions to build a multi-node lab.

This is **Part 3** of a **3** part series I've called **VMware homelab**:

- [[Part 1]: Introduction & Considerations](/posts/vmware-series-p1-considerations/)
- [[Part 2]: How to install vSphere on a NUC](/posts/vmware-series-p2-installation/)
- [This Page]: How to configure vSphere networking and storage (this page)

**TL;DR:** If external networking is configured properly with vLANs, trunks, and routes, it should be a matter of configuring each hosts networking through VCSA.

## Overview

## Prerequisites

## NETWORKING

## vDS Networking setup

vDS requires vSphere. I didn't find an easy way to create a vDS from the command line. As a result, we'll have to use the GUI.

In vCenter, on the Networking tab (globe), right click the Datacenter and select "New Distributed Switch"

![](https://i.imgur.com/0ygHxVl.png)

I want to create the "backend" 2.5 connection first. I'll name the switch: `DSwitch-2.5`

I'll choose the latest version of distributed switch as this is a clean install.

![](https://i.imgur.com/x1mjy2l.png)

For the Configure settings, this is going to be "to taste." Here's what I did:

![](https://i.imgur.com/DIVJS1q.png)

I didn't choose the default port group because I want to migrate management and other networks over. It's possible I want to do things non-default.

![](https://i.imgur.com/WbgsLiY.png)

Finish

### Create the port group(s)

Port groups for vDS can only be created in the vCenter GUI:

![](https://i.imgur.com/0ejBRAT.png)

We'll call the first one `Management` and take the defaults.

### Add a non-vCenter ESXi hosts to the vDS

I'm going to add esxi-host-3. This way, if I ruin the network, vCenter should remain up.

![](https://i.imgur.com/e4vhq8Y.png)

When configuring the host, it prompts to assign uplink. I'll attach `vmnic0` to `DSwitch-2.5`

The installer prompts to migrate the port groups. Selecting the new port group will migrate them.

![](https://i.imgur.com/PC29wkk.png)

Since there's no VMs to migrate, we can skip step 5. Next.

Finish.

### Create the VM Network vDS

Next create a port group named `VM Network`

Next let's setup the VM Network

In vCenter, on the Networking tab (globe), right click the Datacenter and select "New Distributed Switch." This time, I'll name it `DSwitch-1` to indicate 1g

I did not let a default port group get created. I'll do that now.

Right click `DSwitch-1` and select "New Distributed Port Group"

I'll use the name "VM Network." Taking the defaults is fine. Considering the NIC has the native VLAN set to the desired traffic, I do not need to configure a VLAN type.

Let's add host-3 to this new switch and see how it behaves. Right click the switch > "Add or manage hosts" > Add hosts

This time, I select the vusb0 adapter for the uplink. I assign it the VM Network port group.

IMPORTANT: CREATE A VMK NIC FIRST TO USE (otherwise it steals the mgmt nic)...

I skip the VM migrations > Next > Finish

### Add the other hosts

1. add hosts
    1. add usb to uplink
    2. skip vmkernel adapters (for now)
    3. skip VM migraitons
    4. Finish

I only need to create the VMKs on the hosts that don't have them (101/102) in the VMware port group

![](https://i.imgur.com/O8pgGHb.png)

1. create VMKs for uplinks

Now that the essential network has been recreated

I can now go back and modify all hosts to use uplink 1:

![](https://i.imgur.com/EK4oUxQ.png)

I can also assing the port group

![](https://i.imgur.com/OMdBrhl.png)

Skip the migration as usual... Now the switch should look like:

### Switch vCenter's network to using the vDS

Log into the ESXi host running vCenter and shut it down / change to the new network.

![](https://i.imgur.com/r2VZviF.png)

> Addition or reconfiguration of network adapters attached to non-ephemeral distributed virtual port groups (VM Network) is not supported.

![](https://i.imgur.com/w4er5dG.png)

> non-ephemeral distributed virtual port groups 

> You can assign a virtual machine to a distributed port group with ephemeral port binding on ESX/ESXi and vCenter, giving you the flexibility to manage virtual machine connections through the host when vCenter is down. 

> TIL: choose ephemeral over static for vm network (or put vCENTER ON MGMT NETWORK!!!!)

>  I looked at the vSphere 5.1 (know its old) documentation, and there it said "Avoid putting vCenter Server on any network other than the management network.

TODO: NAME THE VM NETWORK BETTER? "New-VM Network?"

## SETUP vmotion nic

https://practical-admin.com/blog/automated-vmotion-configuration-from-the-esx-hosts-command-line/

```
# create vMotion port group on vSS
esxcli network vswitch standard portgroup add --portgroup-name=VMotion --vswitch-name=vSwitch0

# add VLAN
esxcli network vswitch standard portgroup set -p VMotion --vlan-id 5
```

What we have so far:

![](https://i.imgur.com/OqqSjIj.png)

To create a VMkernel port and attach it to a portgroup on a Standard vSwitch, run these commands:

```
# I'm using the built-in vmotion named TCPIP stack (can be omitted)
esxcli network ip interface add --interface-name=vmk1 --portgroup-name=VMotion

esxcli network ip interface ipv4 set --interface-name=vmk1 --type=dhcp
```

Tag it for vMotion? 

```
esxcli network ip interface tag add --tagname="VMotion" --interface-name=vmk1
```

Enable vMotion on vSwitch via the command line. Enable a VirtualNic to be used as the vMotion NIC.

```
# vim-cmd hostsvc/vmotion/vnic_set [vnic]
vim-cmd hostsvc/vmotion/vnic_set vmk1
```

https://kb.vmware.com/s/article/1006989

https://serverfault.com/questions/1093203/what-is-wrong-with-esxi-vmkernel-port-in-active-active-configuration


## Remove maintence mode

In the GUI

![](https://i.imgur.com/9Wl35HL.png)

### Setup up VM Network

created a new distributed switch `DSwitch-02-VM Network``

![](https://i.imgur.com/YoKtwpc.png)

then a port group called `DSwitch-02-VM Network`

![](https://i.imgur.com/VmujJBq.png)

Next we need to add the hosts uplink (usb) for the VM network

Right Click > Add or manage hosts

![](https://i.imgur.com/e568Jm9.png)

Skip over adding VM kernel adaptares (we just use USB)

![](https://i.imgur.com/5bUWNYk.png)

Skip migrate netowkring (if yoyu have no VMs)

### Other section?

![](https://i.imgur.com/9fQYyJK.png)

removed other uplinks

~~changed port tagging to 0?~~ tried and remove vlan 1 tag.

Now accepting:

![](https://i.imgur.com/woFf2xF.png)


Disabled port blocking on the swtich:
![](https://i.imgur.com/tKohmqM.png)

same for the vmnetwork swtich...

![](https://i.imgur.com/jbCLbql.png)


https://www.reddit.com/r/vmware/comments/nzzxgj/why_would_vms_on_a_nested_esxi_not_be_able_to/

## Set up bootstrap networks 

TODO: SUMMARY (network, ports, vlans, etc...) USB NICs etc... (VM Traffic / Managment)

> Note: If I only had 2 1G NICs, I would probably combine all networks and run redundant NICs / multipath iSCSI / etc.

On each host, we need to enable SSH and setup networking. This is comprised of the following steps:

1. login to the UI
1. enable SSH
1. login to the console
1. create and confirm network

### log into to the UI

I have the following hosts:

```shell
172.16.6.101
172.16.6.102
172.16.6.103
```

Login to the UI using our defined `root`/`esxir00tPW!` user/password combo at the IP address of the host.

## One version of setup

## Create a new switch to split the 2 interfaces

We want VM traffic isolated to the 1G USB NIC and management/storage/vMotion isolated to the 2.5G onboard NIC, we need to create 2 switches.

!! PIC !! [TODO]

This allows us the ability to create 2 seperate uplinks.

First, create VM Traffic network vSwitch1. This only contains our 1G traffic on our homelab network.

```
# esxcli network vswitch standard list

# createa a switch named vSwitch1
esxcli network vswitch standard add --ports 128 --vswitch-name vSwitch1
```

Create uplink (using USB NIC)

```
# add an uplink
esxcli network vswitch standard uplink add --uplink-name=vusb0 --vswitch-name=vSwitch1
```

Delete the "VM Network" port group from vSwitch0 so we can create it on vSwitch1.

```
esxcli network vswitch standard portgroup remove --portgroup-name="VM Network" --vswitch-name=vSwitch0
```

Create "VM Network" port group on vSwitch1

```
esxcli network vswitch standard portgroup add --portgroup-name="VM Network" --vswitch-name=vSwitch1
```

## How to configure an NFS datastore VMware ESXi 7.0

First configure the switch to chat on that network (via mgmt nic)

![](https://i.imgur.com/XEVDCxE.png)

and then added vmkernel adapters (to pick up a new DHCP)

![](https://i.imgur.com/ygIbuPe.png)


Configure a VMkernel port group for NFS storage. You can create the VMkernel port group for IP storage on an existing virtual switch (vSwitch) or on a new vSwitch. The vSwitch can be a vSphere Standard Switch (VSS) or a vSphere Distributed Switch (VDS).

Right click on the cluster and choose new datastore:

![](https://i.imgur.com/N35VS5D.png)

![](https://i.imgur.com/p0gF8YP.png)

NOTE:
I had to change my NFS one to VLAN 1 (default): ![](https://i.imgur.com/4kPsO7w.png)

![](https://i.imgur.com/hZ9roq6.png)


Had to putz with permissions but I got NFS to work"
![](https://i.imgur.com/M3EQt8z.png)

what's below?

![](https://i.imgur.com/m5l5yMy.png)

I'm not going to add a ton of detail here, just adding a NFS server that I created on another NAS:

![](https://i.imgur.com/XmilXkl.png)

![](https://i.imgur.com/IUxvLIg.png)

no kerberos

## How to configure an iSCSI datastore VMware ESXi 7.0


https://vdc-repo.vmware.com/vmwb-repository/dcr-public/24be7af7-d9cd-48d9-bab8-8c91614be19d/0ca33108-8017-4b40-86b9-f066456894ea/doc/GUID-8E8481F7-9506-4437-94F1-2DAEEE8A6053.html

```
esxcli iscsi software set --enabled=true

# check for iscsi adapters
esxcli iscsi adapter list
```

Output:

```
Adapter  Driver     State   UID            Description
-------  ---------  ------  -------------  -----------
vmhba64  iscsi_vmk  online  iscsi.vmhba64  iSCSI Software Adapter
```

```
# (optional) check the status (true/false)
esxcli iscsi software get
```

## Test / setup iSCSi hosts (copy)

create the vDS switch (for NETIO)

new port group:

![](https://i.imgur.com/0EfDZ7S.png)

![](https://i.imgur.com/o5pz4z9.png)

Add VMKernel adapater

![](https://i.imgur.com/mnHNbTX.png)

select all hosts

![](https://i.imgur.com/EsfpKjK.png)

172.16.6.102

- setup datastores
- 

### Add iSCSI vDS portgroup (real)

Software iSCSI does not require port binding, but requires that at least one VMkernel NIC is available and can be used as an iSCSI NIC.

1. Right click the DSwitch-01
2. Select Distributed Port Group > New Distribted Port Group
3. Name: DSwitch-01-iSCSI
4. VLAN changed from None to "VLAN" and "4" is added for the ID, which is my iSCSI network

### Add VMkernel adapater

Since we have 3 vmk's starting with 0, I'll add the 4th one as "vmk3":

![](https://i.imgur.com/0sJ3XiF.png)

To create a VMkernel, right click on the newly created DSwitch port group and choose: Add VMkernel Adapters.

I selected all hosts:

![](https://i.imgur.com/nuWsUKx.png)

I didn't select any of the available services and left IPv4 settings as auto (DHCP).

![](https://i.imgur.com/zdLuJDg.png)

### LUN planning

We can do any of this: ![](https://i.imgur.com/YDmYqmL.png)

For my setup, I'm going to do 1 target to multiple luns. This differs based on provider.

The following depends on your SAN:

Create the target:

![](https://i.imgur.com/dGWzV7D.png)

Skipping chap for now, but worth doing if in production.

![](https://i.imgur.com/PCEAMRt.png)

Upon applying, the LUN creation wizard pops up. I chose to provision a thick Lun:

![](https://i.imgur.com/VPRi0Vh.png)

Since we have 4 hosts and I have 2TBs, I'll create one giant lun that all hosts share

> Sharing a VMFS Datastore Across Hosts

https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.storage.doc/GUID-52DC7277-5321-4BB5-86B4-D73D258F6529.html


![](https://i.imgur.com/4WyxfcZ.png)

Created a 1TB lun named terralun

![](https://i.imgur.com/fTnFkf1.png)

Since I used the wizard, it automatically maps the lun to my iSCSI target.

![](https://i.imgur.com/UaYHuOH.png)


### create the discovery connection

Connect to esxi vDS with:

```
# value `3260` for port is a default
# value `vmhba64` is from the `adapter list`
esxcli iscsi adapter discovery sendtarget add --address=172.16.4.100:3260 --adapter=vmhba64


# Run rediscovery on the host:

esxcli iscsi adapter discovery rediscover --adapter=vmhba64
```

**IMPORTANT:** Repeat for the other 3 hosts...

With dynamic discovery, all storage targets associated with a host name or IP address are discovered.

Once I confirmed everything worked, I created the datastore in vCenter

Right-clicked the cluster and chose, Storage > New Datastore:

![](https://i.imgur.com/nbQUlA0.png)

The QNAP LUN autopopulated and I nexted my way throught the addition.

Once created, verify it's configured on multiple hosts.

> Note: In production, probably not recomended, but for now, I'll use mutliple vmdk's on the same VMFS lun.

We should see all hosts:

![](https://i.imgur.com/bNEZYc0.png)

## Testing

## Clean-up

### Networking clean. up

right click each vSwitch in the host and delete:

![](https://i.imgur.com/XJB2Tcv.png)

Don't confuse with networking tab, this is in the hosts configuration. The other networking areas can't be modified.

### removing switches

![](https://i.imgur.com/Z4X0eer.png)

or remove the whole switch:

![](https://i.imgur.com/sIhu0jz.png)

## OTHER

- Networking
    - focus vDS on GUI
    - Delete the management vSS network? (already been migrated)
- Storage
    - ensure to cover the datastore mount to other hosts
    - Since my other vmks can access iSCI network, I might not need to create the vmk
    - RECOMENDATION: ignore heart beat datastores leave to reader (how to disable)

## How to troubleshoot iSCSI on VMware

Check send target

```
esxcli iscsi adapter discovery sendtarget list
```

Output:

```
Adapter  Sendtarget
-------  ----------
vmhba64  172.16.4.100:3260
```

Check that the storage responds to a ping...

```
# esxcli iscsi logicalnetworkportal list


vmkping -I vmk3 172.16.4.100

#Looking for no packets dropped:
#3 packets transmitted, 3 packets received, 0% packet loss
```

Check if the iSCSI TCP Port 3260 is available on the storage using netcat:

```
# If needing to use a different IP, use -s (source) to specify the adapter IP to use.
nc -z 172.16.4.100 3260
```

Expected result:

```
Connection to 172.16.4.100 3260 port [tcp/*] succeeded!
```

### NFS unmount issues:

[root@localhost:~] esxcfg-nas -l
toaster is /vmware from 192.168.7.19 mounted available
[root@localhost:~] esxcfg-nas -d toaster
NAS volume toaster deleted.
[root@localhost:~] exit

Turns out:
VCLS was running on my NAS, wtf...

![](https://i.imgur.com/bL6icou.png)

Needed to do a storage vmotion then remove NAS hosts...

## Stop ssh?

![](https://i.imgur.com/wWoimkN.png)

![](https://i.imgur.com/XqdLjPp.png)

## Conclusion

It would be great to automate all of this with Terraform, maybe some day soon. That way the cluster can be destroyed and rebuilt easily.

- Traffic misconceptions: https://devstime.com/2021/07/19/misconception-about-vmotion-traffic-usage/