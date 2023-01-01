---
# not too long or too short (think G-search)
title: "VMware homelab [Part 2]: How to install vSphere on a NUC"
date: 2022-12-31
# description is usually what's used in a google snippet
# informs and interests users with a short, relevant summary of what a particular page is about.
# They are like a pitch that convince the user that the page is exactly what they're looking for.
description: "Installing ESXi and VCSA on 3 Intel NUCs"
summary: "The second post of a VMware homelab series covering the installation of vSphere 7"
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
    image: "img/vmware-lab-featured-p2.jpg"
    alt: "A screenshot of the progress bar of a VCSA install" # alt text
# check config.toml for some of the default options / toggles

# contain keywords relevant to the page's topic, and contain no spaces, underscores or other characters. You should avoid the use of parameters when possible, as they make URLs less inviting for users to click or share. Google's suggestions for URL structure specify using hyphens or dashes (-) rather than underscores (_). Unlike underscores, Google treats hyphens as separators between words in a URL.
slug: "vmware-series-p2-installation"  # make your URL pretty!

---

In the fall of 2022, I decided to build a VMware homelab so I could explore [Anthos clusters on VMware](https://cloud.google.com/anthos/clusters/docs/on-prem/latest/overview) a bit closer. A few jobs back I administered VMware and in 2017 I blogged about [creating a single node VMware homelab](/posts/vmware-homelab-build-2017). I thought it _couldn't be that hard_ to build a multi-node VMware homelab with a few Intel NUCs. I was wrong.

> The difference in settings up a single node ESXi host vs. a cluster of 3 ESXi hosts was staggering. Mainly the networking design required.

At first I was going to update my older VMware install posts but, after hitting enough issues, it was clear I needed to start over. My goal is to start with an overview of things to consider before jumping in. Reading my series should save you many hours of problems if you have similar ambitions to build a multi-node lab.

This is **Part 2** of a **3** part series I've called **VMware homelab**:

- [[Part 1]: Introduction & Considerations](/posts/vmware-series-p1-considerations/)
- [This Page]: How to install vSphere on a NUC
- [[Part 3]: How to configure vSphere networking and storage](/posts/vmware-series-p3-network-storage/)

**TL;DR:** Watch out for NIC / USB driver compatibility issues which require a custom ISO otherwise installation should be "normal."

## Overview

![](https://i.imgur.com/CxOliQc.png)

We use vmug advantage: ![](https://i.imgur.com/26FH6xL.png)

## Prerequisites

Network configured to match (see part 1)

MGMT Network has to be configured and used by esxi hosts

## Optional Pre-reqs

I had statically assigned IPs to host NICs, if you don't it can be changed once you boot (adjust / reboot)

## How to create an ESXi ISO

TODO: building isos for nucs (network and other / usb nics / 12th gen)

nic drivers ... windows (from other post)

### NUC CREATION (NIC DRIVERS)

![](https://i.imgur.com/EiOqXBE.png)


https://www.vanimpe.eu/2021/11/25/vmware-esxi-support-for-nuc-11-network-interface/
+
https://www.virten.net/2021/11/vmware-esxi-7-0-update-3-on-intel-nuc/

```
Add-EsxSoftwareDepot .\VMware-ESXi-7.0U3d-19482537-depot.zip
Add-EsxSoftwareDepot .\Net-Community-Driver_1.2.7.0-1vmw.700.1.0.15843807_19480755.zip
New-EsxImageProfile -CloneProfile "ESXi-7.0U3d-19482537-standard" -name "ESXi-7.0U3d-19482537-NUC" -Vendor "vsphere.mydns.dog"
Add-EsxSoftwarePackage -ImageProfile "ESXi-7.0U3d-19482537-NUC" -SoftwarePackage "net-community"
Export-ESXImageProfile -ImageProfile "ESXi-7.0U3d-19482537-NUC" -ExportToISO -filepath ESXi-7.0U3-18644231-NUC.iso
```

### NUC NICs

To do this I enabled SSH on the ESXi host (F2 > Troubleshooting Options > Enable SSH)

### Enable SSH

Right click the host and choose Services > Enable Secure Shell (SSH).

![](https://i.imgur.com/KypZr8R.png)

### Add the USB NIC drivers

Lastly,

```
# After enabling SSH in the GUI

scp ~/Downloads/ESXi703-VMKUSB-NIC-FLING-55634242-component-19849370.zip root@172.16.6.103:/tmp/
```

SSH in to the host

```
ssh root@172.16.6.103

esxcli system maintenanceMode set -e true
esxcli software component apply -d /tmp/ESXi703-VMKUSB-NIC-FLING-55634242-component-19849370.zip
esxcli network ip set --ipv6-enabled=false
esxcli network vswitch standard add --ports 128 --vswitch-name vSwitch1
esxcli network vswitch standard uplink add --uplink-name=vusb0 --vswitch-name=vSwitch1
esxcli network vswitch standard portgroup remove --portgroup-name="VM Network" --vswitch-name=vSwitch0
esxcli network vswitch standard portgroup add --portgroup-name="VM Network" --vswitch-name=vSwitch1

reboot
# exit
```

I noticed the 1G USB NICs were assigned 100 Mbps instead of 1000. Adding the USB drivers fixes this.

Since VMware doesn't "officially" support USB network adapters for production environments, the drivers must be installed via a fling.

[USB Network Native Driver for ESXi](https://flings.vmware.com/usb-network-native-driver-for-esxi)

Download the file that matches your ESXi version and copy the zip to every ESXi server.

![](https://i.imgur.com/DCcMQzC.png)

The following is my approach to updating the hosts.

```shell
scp ~/Downloads/ESXi703-VMKUSB-NIC-FLING-55634242-component-19849370.zip root@172.16.6.101:/tmp/

# login to the server
ssh root@172.16.6.101

# run the component install
esxcli software component apply -d /tmp/ESXi703-VMKUSB-NIC-FLING-55634242-component-19849370.zip

# REBOOT
reboot
```

Output:

```shell
Installation Result
   Components Installed: VMware-vmkusb-nic-fling_1.10-1vmw.703.0.50.55634242
   Components Removed: 
   Components Skipped: 
   Message: The update completed successfully, but the system needs to be rebooted for the changes to be effective.
   Reboot Required: true
```

## ESXi for NUC11

We needed: 

![](https://i.imgur.com/mHpnK4s.png)

https://www.virten.net/2021/11/vmware-esxi-7-0-update-3-on-intel-nuc/

https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.esxi.install.doc/GUID-C84C5113-3111-4A27-9096-D61EED29EF45.html

```
esxcli software vib install -d /path/to/the offline bundle zip
```

```
dd bs=10M if=VMware-VMvisor-Installer-version_number-build_number.x86_64.iso of=/dev/sda
```

##### Modifying Boot

Today manually adding for 12th gen cpu (https://williamlam.com/2022/02/esxi-on-intel-nuc-12-extreme-dragon-canyon.html)

```
cpuUniformityHardCheckPanic=FALSE
```

Start the host.

When the ESXi installer window appears, press Shift+O to edit boot options.

IMPORTANT: enter this again manually on first boot and then fix permanently below:

> Once ESXi has been successfully installed, you can permanently set the kernel option by running the following ESXCLI command:

```
esxcli system settings kernel set -s cpuUniformityHardCheckPanic -v FALSE
```

## Install by hand

### if we wanted to do cool USB stuff, we probably need to add this:
... Also probably need a fling for that? https://flings.vmware.com/usb-network-native-driver-for-esxi

1. Boot to ISO
1. `<ENTER>` to continue install
2. F11 accept EULA
3. Select Local NVMe (also would ahve been first) to provsion 2 TB
4. (if prompted due to existing install) choose: Install ESXi, overwrite VMFS datastore
5. US Default (kebyoard)
6. root PW > Enter
    7. esxir00tPW!
8. F11 install (confirming overwrite)

```shell
Install complete, remove media and reboot!
```

Repeat for all hosts.

A condensed version ran on other hosts. I'm not sure if this is normal, but my other two hosts had to be rebooted before I was able to do the following.

```
# After enabling SSH in the GUI

scp ~/Downloads/ESXi703-VMKUSB-NIC-FLING-55634242-component-19849370.zip root@172.16.6.102:/tmp/

ssh root@172.16.6.102
```

### Do you need IPV6?

This is more opinion, I don't have IPV6 on my router, why waste the option...


```
esxcli system maintenanceMode set -e true
esxcli software component apply -d /tmp/ESXi703-VMKUSB-NIC-FLING-55634242-component-19849370.zip
esxcli network ip set --ipv6-enabled=false
esxcli network vswitch standard add --ports 128 --vswitch-name vSwitch1
esxcli network vswitch standard uplink add --uplink-name=vusb0 --vswitch-name=vSwitch1
esxcli network vswitch standard portgroup remove --portgroup-name="VM Network" --vswitch-name=vSwitch0
esxcli network vswitch standard portgroup add --portgroup-name="VM Network" --vswitch-name=vSwitch1

reboot
# exit
```

I found myself rebooting an additional time for everything to "work itself out" I'm not sure if I'm just impatient, my local network was broke, or the software wasn't ready, but a second "final" reboot seemed to do the trick (and DHCP worked from there for MGMT)

Log in to IP (https) with "root"

```
esxir00tPW!
```

## Disable IPv6

This step is optional, I haven't had time to consider a IPv6 setup.

```shell
esxcli network ip set --ipv6-enabled=false
```

## reboot

```
reboot
# exit
```

![](https://i.imgur.com/U5HirWo.png)

Single Sign-On domain name 
(vsphere.mydns.dog)

Single Sign-On username

administrator

SSO pw: `VMwadminPW!99`

AND IT's Rolling! 

![](https://i.imgur.com/nqLDGn9.png)

## How to install VCSA (vCenter Server Appliance)

TODO: Explain more about where to find this ISO

Mount the VCSA_all ISO (ex: VMware-VCSA-all-7.0.3-19480866.iso) and find the GUI applicaiton for your workstation.

![](https://i.imgur.com/l1JaadN.png)

The host for the intial install of vCenter must NOT be in matence mode.

![](https://i.imgur.com/N2aTF9X.png)

1. Mount installer
1. click vcsa gui (for mac)
1. chooose "Install", then Stage 1 "Deploy vCenter Server" > Next
1. Accept license agreement
1. Add esxi-0 host info:
    1. ESXi host: `172.16.6.101`
    7. Username: `root`
    1. Password: `esxir00tPW!`
1. Accept certificate warning
1. Set up vCenter Server root PW for VM
    1. Password: `vcsar00tPW!`
    1. Note: Mac installers might fail with: `“ovftool” cannot be opened because the developer cannot be verified.` To avoid, enabled "ovftool" via System Settings > Privacy & Security (scroll down).
    1. ![](https://i.imgur.com/FWmbK7v.png)
1. Tiny deployment (2x12)
1. Enable thin disk and chose root DS....
    1. ![](https://i.imgur.com/lNzpBCC.png)
    1. DELETE ONE: ![](https://i.imgur.com/9RfPwdH.png)
1. Configure network settings
    1. Network: VM Network
    1. IP assignment: DHCP
    1. ![](https://i.imgur.com/jdb2A0j.png)
2. Finish

> NOTE: At this point the VM Network is actually the management network...

![](https://i.imgur.com/lRerzgo.png)

## Stage 2: Set up vCenter Server

![](https://i.imgur.com/7sBkZys.png)

1. vCenter Server Configuration
    2. Time synchronization mode: Disabled
    3. SSH access: Disabled
4. SSO Configuration
    5. Single Sign-On domain name: `vsphere.mydns.dog`
    6. Single Sign-On password: `VMwadminPW!99`
    8. ![](https://i.imgur.com/QHJ6ny1.png)
9. Next > Finish

Once complete, log in to vCenter using the new URL/IP:

![](https://i.imgur.com/bOI8aYm.png)

## Create VMware datacenter and cluster objects

## GUI config for cluster?

![](https://i.imgur.com/U7upy2L.png)

assign nic

![](https://i.imgur.com/UIZAhKt.png)

use vLAN

![](https://i.imgur.com/u9wjDCb.png)

overview:

![](https://i.imgur.com/dPZF8m6.png)

## MAybe the same?

create DC

![](https://i.imgur.com/VHbaJ8r.png)

1. Right click the vCenter > New Datacenter...
    2. ![](https://i.imgur.com/AvQxpWG.png)
    3. Name: `anthos-dc`
4. Right click the Datacenter > New Cluster
    5. Name: `anthos-cluster`
    6. vSphere DRS: enabled
    7. vSphere HA: enabled
    8. vSAN: disabled (default)

![](https://i.imgur.com/K3fdi0j.png)

![](https://i.imgur.com/Xlk3FjA.png)

![](https://i.imgur.com/7VUW7CF.png)

## Add ESXi hosts to new VMware cluster

add hosts

![](https://i.imgur.com/2COLUme.png)

Right click the new cluster > Add Hosts

![](https://i.imgur.com/5dmvjir.png)

Since we used the same password for all 3 hosts, we can cheat a bit here by only entering the credentials once and selecting "Use the same credentials for all hosts"

![](https://i.imgur.com/8VeU9io.png)

Accept all certs from the Security Alert > Ok > Next > Finish

Let's wait to "Configure cluster" (#3 "Quickstart"). I want to get our vDS networking setup first and tidy up the hosts.

## enable ha cluster / DRS?

![](https://i.imgur.com/yEutvOt.png)

![](https://i.imgur.com/SPE9ySb.png)


![](https://i.imgur.com/qGOZCue.png)


![](https://i.imgur.com/z5ll8Xx.png)


![](https://i.imgur.com/wcaJORO.png)


Review? Finish...

## Enable NTP

![](https://i.imgur.com/ius9dr4.png)


```shell
0.pool.ntp.org,1.pool.ntp.org,2.pool.ntp.org,3.pool.ntp.org
```

Enable the NTP daemon:

![](https://i.imgur.com/qDi0yUZ.png)

Do for all 4 hosts...

good article: https://infohub.delltechnologies.com/l/dell-emc-ready-architecture-for-vmware-telco-cloud-platform-1-0/synchronize-esxi-clocks-using-ntp

## Add Licenses

add licenses

manually through gui... then assign with"

![](https://i.imgur.com/8hvpCbU.png)

![](https://i.imgur.com/G1LS6Qv.png)

Use the navigation to find the administration tab

![](https://i.imgur.com/yzGNgVa.png)

From there, let's add the two licenses:

![](https://i.imgur.com/NokLrXP.png)

In vCenter, right click the vCenter host and choose "assign license"

right click each host (including vCenter and choose assign license"

![](https://i.imgur.com/cpaMAtd.png)

![](https://i.imgur.com/EICdICp.png)

It seems more preferential here, I'm enabling stuff as I think would be cool:

![](https://i.imgur.com/XPXGs61.png)

## NTP servers

![](https://i.imgur.com/LRIYC0L.png)

I don't think I need EVM because they are all intel (describe what that means)

## Clean up vsphere warnings

### Remove error on network redundancy

"This host currently has no management network redundancy"

Once we cluster the hosts, we'll get errors if we don't have redundant mgmt ports. There's also errors if there's no heartbeat on a cluster datastore. Let's ignore both for now:

https://kb.vmware.com/s/article/1004700

```
# Deactivates configuration issues created if the host does not have sufficient heartbeat datastores for vSphere HA. Default value is false.

das.ignoreInsufficientHbDatastore to true


das.ignoreRedundantNetWarning to true
```

![](https://i.imgur.com/SoXGddk.png)

Right-click the host and click Reconfigure for vSphere HA.

![](https://i.imgur.com/p23ftFa.png)

### If SSH is enabled still on any hosts, disable it through the UI:

![](https://i.imgur.com/sSeNyh8.png)

## enable DRS for resource pools

![](https://i.imgur.com/9tkUk68.png)


![](https://i.imgur.com/Ph1mFo9.png)

## Networking

I know we have an entire section this in the intro and in part 3, but I wantt o point out a few things:

You'll notice the default networking creates a Management and a VM Network port group for use (prioritizing the mgmt creation):

![](https://i.imgur.com/gKzi0we.png)

The USB NIC is found (in the picture above `vusb0` with the green hardware icon.)

The default "VM Network" thinks it should use the `vmnic0`. We'll change this before deploying vCenter. VM Network default topology:

![](https://i.imgur.com/ncXnMP4.png)

The default "Management" network is correctly configured. I have the physical port's native VLAN set to my vmware-mgmt network (along with other tagged VLANs):

![](https://i.imgur.com/EGQPSJU.png)

## Testing

I manually updated a modified iso file to a datastore and created a vm from it on the home network.

It seemed to come up but my SSH key didn't transfer (looking now).

EMPHASIZE: IT's not that big of a deal.... just upload the VM data to a datastore (VMmotion is our main test, right?)

Live OS + ClickOps is ok

![](https://i.imgur.com/PqopPbi.png)

did click ops, started an infinite ping (ping google com, here's the results during a vMotion):


turn off and unmount ISO (unique to host)

![](https://i.imgur.com/boQQEDs.png)

Results:

I thought I selected "3" but it migrated to 2. Picture:

![](https://i.imgur.com/VZrIX2j.png)


The cool thing though is that the ping never failed once:

![](https://i.imgur.com/orSFggr.png)


Double checking and clearly choosing 3 this time, the same test succeeded (for 103):

![](https://i.imgur.com/jOl4knb.png)


I'll leave ping going (still no drops) and I'll vMotion to 1 and call it a clean install...

Note: It is SIGNIFICANTLY faster going 2.5 -> 2.5 but going 1 -> 2.5 wasn't that bad (as far as timing). I think it took 3 minutes vs. 1.

The most important thing: My SSH session NEVER dropped and neither did my ping on the box:

![](https://i.imgur.com/DS9i73T.png)


## Troubleshooting

```
Check the following:

1. IP address & Subnet mask of your ESXi VMKernel port (management IP Address) and also assigned IP combination for the VCSA in deployment wizard.

2. VLAN IDs if you assigned for the management port group and VM Network.

3. Uplinks of vSwitch for that VM Network, and also its failover order (vmnic). Check in both of vSwitch settings and also port group settings.

4. Connect to the VCSA Bash Shell and ping your client and also the ESXi hosts from this vCenter server and check the results.

5. Deploy a test VM that is connected to the port group that VCSA is still connected to that, then check the network connectivity again.
```

## Clean-up

I deleted the VM networking default created on the other DS switch

## OTHER / TODO

- add a link to: https://docs.vmware.com/en/VMware-vSphere/7.0/vsphere-esxi-703-installation-setup-guide.pdf
- update with: automation via ks

### Troubleshooting

```shell
# dump current config
esxcli network nic list
```

```shell
# put in maintence mode
esxcli system maintenanceMode set -e true
```

Ref: [Configuring vSwitch or vNetwork Distributed Switch from the command line in ESXi/ESX](https://kb.vmware.com/s/article/1008127)


## update vsphere? vCenter? compliance with rules

https://172.16.6.81:5480/#/ui/summary


idk?

![](https://i.imgur.com/Zp9MxMA.png)

???

![](https://i.imgur.com/120bkhI.png)
