---
# not too long or too short (think G-search)
title: "VMware homelab [Part 2]: How to install a vSphere cluster at home"
date: 2023-02-04
# description is usually what's used in a google snippet
# informs and interests users with a short, relevant summary of what a particular page is about.
# They are like a pitch that convince the user that the page is exactly what they're looking for.
description: "Installing ESXi and vCenter (VCSA) on 3 Intel NUCs"
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
    image: "img/vmware-lab-featured2-p2.jpg"
    alt: "A AI generated image of building blocks" # alt text
# check config.toml for some of the default options / toggles

# contain keywords relevant to the page's topic, and contain no spaces, underscores or other characters. You should avoid the use of parameters when possible, as they make URLs less inviting for users to click or share. Google's suggestions for URL structure specify using hyphens or dashes (-) rather than underscores (_). Unlike underscores, Google treats hyphens as separators between words in a URL.
slug: "vmware-series-p2-installation"  # make your URL pretty!

---

## Intro from Part 1:

In the fall of 2022, I decided to build a VMware homelab so I could explore [Anthos clusters on VMware](https://cloud.google.com/anthos/clusters/docs/on-prem/latest/overview) a bit closer. A few jobs back I administered VMware and in 2017 I blogged about [creating a single node VMware homelab](/posts/vmware-homelab-build-2017). I thought it _couldn't be that hard_ to build a multi-node VMware homelab with a few Intel NUCs. I was wrong.

> The difference in settings up a single node ESXi host vs. a cluster of 3 ESXi hosts was staggering. Mainly the networking design required.

At first I was going to update my older VMware install posts but, after hitting enough issues, it was clear I needed to start over. My goal is to start with an overview of things to consider before jumping in. Reading my series should save you many hours of problems if you have similar ambitions to build a multi-node lab.

This is **Part 2** of a **3** part series I've called **VMware homelab**:

- [[Part 1]: Introduction & Considerations](/posts/vmware-series-p1-considerations/)
- [Part 2]: How to install a vSphere cluster at home
- [[Part 3]: How to configure vSphere networking and storage](/posts/vmware-series-p3-network-storage/)

---

**TL;DR:** Watchout for NIC / USB driver compatibility issues which require a custom ISO otherwise installation should be "normal."

## High level overview

We need to do the absolute bare minimum to get the hosts running and vCenter (VCSA) installed.

Based on the official docs, and compromises required by using unsupported hardware, we perform the following steps:

1) Build a custom ESXi installer ISO
1) Install ESXi on multiple hosts
1) Install VCSA on a single ESXi host

Once that is configured, <mark>the rest of the setup can be scripted (in Part 3) because VCSA presents an API / SDK for managing VMware objects</mark>.

## Prerequisites

This post assumes you have a few things already:

- A source `VMware-ESXi-#########-depot.zip` file (or ISO) for installing ESXi OS
- Software bundle `VMware-VCSA-all-7.0.3-#########.iso` for launching the VCSA install
- Physical switch configured properly

I also assigned fixed IPs to my hosts, so DHCP "knows" my 3 hosts initially. If you don't perform this step, ensure you have a way to get the IPs of the hosts.

{{< notice warning >}}
I thought DHCP was going to make my life easier, but actually I think having static IPs might be a bit more forgiving when it comes to moving hosts around & configuring VMKernel NICs.
{{< /notice >}}

For reference, my VLANs are:

Purpose            | VLAN       | Interface | Range
-------------------|------------|-----------|----------------
Management Network | 0 (native) | `vmnic0`    | `172.16.6.0/24`
Storage            | 4          | `vmnic0`    | `172.16.4.0/24`
vMotion            | 5          | `vmnic0`    | `172.16.5.0/24`
VM Network         | 64         | `vusb0`      | `192.168.64.0/18`

{{< notice note >}}
In my homelab, each host has 2 NICs that are different speeds (1G and 2.5G). I made the choice to **build the entire lab** on the foundation of **all** operations happening on the 2.5 NIC and **all** VM traffic happen on the 1G.

<mark>If I were to rebuild everything, I might consider running both NICs at 1G and using a single virtual switch with redundant NICs per best practices.</mark>
{{< /notice >}}

Desired state:

![diagram of 3 nucs and 1 qnap NAS networked together with various vLANs described for VMware](/img/vmware-homelab-2022.svg)


## Build a custom ESXi installer ISO

When I started to build my homelab, I used the default ISO and I was attempting to combine it with any flavor of automation. No matter what I tried, I could not get it to install. It took me _far_ too long to realize that VMware does not support the 2.5G NIC on the 11th generation NUCs.

The good news is, there's a workaround. A VMware fling [Community Networking Driver for ESXi](https://flings.vmware.com/community-networking-driver-for-esxi) that adds this functionality.

The fling is downloaded and then packed into the downloaded zip file to generate a new ISO for ESXi. Navigate to the fling and download the latest one available.

For the exact steps:

1. [Install PowerCLI](https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.esxi.install.doc/GUID-F02D0C2D-B226-4908-9E5C-2E783D41FE2D.html) ([for mac](/posts/vmware-powercli-install-on-mac/))
1. [Add a the fling to an ESXi ISO with PowerCLI](/posts/vmware-powercli-install-on-mac/#build-a-custom-iso-test)
1. [Create a bootable USB](/posts/vmware-powercli-install-on-mac/#extra-credit-copying-the-iso-to-a-bootable-usb)

## Install ESXi on multiple hosts

To install the OS, I plug in a USB-C monitor and USB keyboard. It'd be great to automate in the future, but for now, it's only a handful of options to select.

Once the USB is selected as the boot option:

1. `<ENTER>` to continue install
1. `F11` accept end-user license agreement
1. Select the disk to install the OS on (if prompted, choose "overwrite VMFS datastore")
1. `US Default (keyboard)` > Enter
1. "root" password (`esxir00tPW!`) > Enter
1. `F11` install > (if prompted, confirm overwrite)

Once complete you should see:

```shell
Install complete, remove media and reboot!
```

Press Enter and unplug the installer USB so it doesn't re-trigger an install on reboot.

Repeat the above process for all ESXi hosts.

## Install VCSA (vCenter Server Appliance)

VCSA is the main interface (VM/API/SDK) to manage ESXi clusters and hosts. It's also a requirement for using virtual distributed switches (vDS). Once VCSA is installed we can automate the rest of the configuration with Ansible.


INSTALLING VCSA IS A TWO STEP PROCESS: MOVE VM, CONFIGURE VCSA

> The ISO for VCSA is a bundle of various installers. Do not confuse this with an ESXi ISO that requires a bootable USB.

## Stage 1: Deploy new vCenter Server

1. Download the ISO file from VMWare - it should say "all" in the title (ex: `VMware-VCSA-all-7.0.3-19480866.iso`). It's around 9GB so the download might take some time.

1. (optional) If you're using a Mac, configure Apple to trust the ISO (inspired by [this](https://williamlam.com/2020/02/how-to-exclude-vcsa-ui-cli-installer-from-macos-catalina-security-gatekeeper.html)):

    ```
    sudo xattr -r -d com.apple.quarantine ~/Downloads/VMware-VCSA-all-7.0.3-19480866.iso
    ```

1. Mount the VCSA_all ISO and find the UI installer application for your workstation.

    ![](https://i.imgur.com/l1JaadN.png)

1. Click vcsa-ui-installer (mac) > Double-click Installer
1. Choose Install, then Next
1. Accept End User License Agreement
1. Add ESXi-1 info:
    - ESXi host: `172.16.6.101`
    - username: `root`
    - password: `esxir00tPW!`
    - Accept certificate warning
1. Set up vCenter Server root PW for VM
    - Password: `vcsar00tPW!` > Confirm
1. Tiny deployment (2x12)
1. Enable thin disk and chose primary datastore
    ![](https://i.imgur.com/lNzpBCC.png)
1. Configure VCSA Network settings
    - Network: VM Network
    - IP assignment: DHCP
1. Next > Finish

{{< notice note >}}
At this point, the **VM Network** is actually the same as the **Management Network**. This is because the hosts only see the onboard NIC at boot; so the single NIC shares all responsibilities by default. We'll install the USB NIC drivers in Part 3.
{{< /notice >}}

Once complete you should see a similar screen to:

![](https://i.imgur.com/plNe3nK.png)

## Stage 2: Set up vCenter Server

In the same application, the second stage should now appear. Click Next to proceed to the vCenter Server Configuration Setup Wizard.

1. vCenter Server Configuration > Next
    - Time synchronization mode: Disabled
    - SSH access: Disabled
1. SSO Configuration
    - Single Sign-On domain name: `vsphere.mydns.dog` (can be anything or left default)
    - Single Sign-On password: `VMwadminPW!99`
1. Next > Join CEIP > Finish > "OK"

Once complete, log in to vCenter using the VCSA URL/IP:

![](https://i.imgur.com/bOI8aYm.png)

> Single Sign-On username: `administrator@vsphere.mydns.dog`
> SSO pw: `VMwadminPW!99`

## Next steps

We now have 3 hosts with management IPs (default). We also have a VCSA appliance configured on the same network.

Most importantly, we have an API to automate the rest of the configuration and setup in Part 3 of the series using Ansible.

Check out Part 3 here: [[Part 3]: How to configure vSphere networking and storage](/posts/vmware-series-p3-network-storage/)