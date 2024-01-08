---
# not too long or too short (think G-search)
title: "VMware homelab [Part 3]: How to configure vSphere networking and storage"
date: 2023-02-06
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
- ESXi 8.0 U1
- vCenter 8.0 U1
- VCSA
- homelab
- NUC11PAHi7
- NUC11PAHi5
- Intel NUC 11 Pro
- NUC 11 Canyon

# !! DON'T FORGET: https://medium.com/p/import
# !! DON'T FORGET: https://medium.com/p/import
draft: false
# !! DON'T FORGET: https://medium.com/p/import
# !! DON'T FORGET: https://medium.com/p/import

#comments: false
# from https://unsplash.com/photos/ute2XAFQU2I
cover:
    image: "img/vmware-lab-featured-p3.jpg"
    alt: "Hands above a laptop keyboard with a black screen" # alt text
    #caption: ""
    relative: true
# check config.toml for some of the default options / toggles

# contain keywords relevant to the page's topic, and contain no spaces, underscores or other characters. You should avoid the use of parameters when possible, as they make URLs less inviting for users to click or share. Google's suggestions for URL structure specify using hyphens or dashes (-) rather than underscores (_). Unlike underscores, Google treats hyphens as separators between words in a URL.
slug: "vmware-series-p3-network-storage"  # make your URL pretty!

---
**TL;DR:** If external networking is configured properly with vLANs, trunks, and routes, it should be a matter of configuring each hosts networking through VCSA via Ansible.

## Intro from Part 1 ([skip](#overview)):

In the fall of 2022, I decided to build a VMware homelab so I could explore [Anthos clusters on VMware](https://cloud.google.com/anthos/clusters/docs/on-prem/latest/overview) a bit closer. A few jobs back, I administered VMware and in 2017 I blogged about [creating a single node VMware homelab](/posts/vmware-homelab-build-2017). I thought it _couldn't be that hard_ to build a multi-node VMware homelab with a few Intel NUCs. I was wrong.

> The difference in settings up a single node ESXi host vs. a cluster of 3 ESXi hosts was staggering. Mainly the networking design required.

At first I was going to update my older VMware install posts but, after hitting enough issues, it was clear I needed to start over. My goal is to start with an overview of things to consider before jumping in. Reading my series should save you many hours of problems if you have similar ambitions to build a multi-node lab.

This is **Part 3** of a **3** part series I've called **VMware homelab**:

- [[Part 1]: Introduction & Considerations](/posts/vmware-series-p1-considerations/)
- [[Part 2]: How to install a vSphere cluster at home](/posts/vmware-series-p2-installation/)
- [Part 3]: How to configure vSphere networking and storage

![learning plan outlined into three steps of planning, foundation, and automation](/img/steps.png)

---

## Overview

Now that we have a vCenter API and multiple ESXi hosts booted, we should be able to complete the remaining steps in an more automated fashion.

1) Bootstrap ESXi hosts for automation
1) Use Ansible to:
    - add USB NIC support
    - create the vCenter layout (datacenter / clusters / folders) and add ESXi hosts
    - create the networking setup
    - create the storage setup

Selfishly, the rest of this post is specific for my environment, but I hope it's written in a way that you feel comfortable adopting.

## Prerequisites

I'm using a mac and use `brew` to install the following pre-reqs:

- Python (`brew install python3`)
- Ansible (`python3 -m pip install ansible`)
- PyVmomi (`python3 -m pip install PyVmomi`)

{{< notice tip >}}
The module used most, [community.vmware](https://docs.ansible.com/ansible/latest/collections/community/vmware/index.html), is actually an API/SDK integration. This means that almost all playbooks are executed on your localhost.

We are not managing the hosts directly via SSH, we are running API commands to vCenter. As such, you'll see many playbooks "delegate" to localhost, on purpose.
{{< /notice >}}

## Ansible setup

Clone the repository:

```shell
git clone git@github.com:jimangel/ansible-managed-vmware-homelab.git

cd ansible-managed-vmware-homelab
```

The file(s):

```shell
├── 00-add-usb-fling-to-hosts.yml
├── 01-vcsa-and-esxi-init.yml
├── 02-networking.yml
├── 02.5-networking.yml
├── 03-storage.yml
├── 04-on-top.yml
├── 99-disable-ssh.yml
├── 99-enable-ssh.yml
├── 99-power-on-vcsa-vm.yml
├── 99-reboot-all-hosts.yml
├── README.md
├── ansible.cfg
└── inventory.yml
```

There are no Ansible roles, only playbooks (which are collections of Ansible tasks), and <mark>the "inventory.yml" file contains both host **AND** custom variable information.</mark> Allowing for repeatable, desired-state, management of clusters.

If you haven't used Ansible before, the repository uses a `ansible.cfg` in the root of the directory to define where my `inventory.yml` file is. This saves a lot of repetitive commands traditionally required for `ansible-playbook`.



Update `inventory.yml` variables for example:

```shell
"ansible_host:"         # for all hosts
"esxi_license:"         # or delete the task in 01-vcsa-and-esxi-init.yml
"vcenter_license:"      # or delete the task in 01-vcsa-and-esxi-init.yml
"vcenter_hostname:"     # !! fill in later
"vcenter_username:" 
"center_password:" 
"vcenter_esxi_host:" 
"esxi_username:" 
"esxi_password:" 
```

One final manual change is needed then the rest is automated.

## Manually enable SSH on the ESXi hosts

1. In the browser, go to the ESXi host's IP
1. Login (`root` / `esxir00tPW!`)
1. Right Click Manage > Services > Enable SSH
1. Repeat for all other hosts

### Copy SSH keys from local to remote host(s)

While most of the automation uses the VMware SDK, there's a few times we want to bootstrap each machine directly. Mainly when copying the zip file of USB drivers over SCP.

Using the local shell:

```shell
export server_list=(172.16.6.101 172.16.6.102 172.16.6.103)

# if needed, create a new VMware SSH
# ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_vmware

# Copy the public key the right place on the ESXii host
for i in "${server_list[@]}"; do cat ~/.ssh/id_rsa_vmware.pub | ssh root@${i} 'cat >>/etc/ssh/keys-root/authorized_keys'; done

# manually enter the password `esxir00tPW!` as it prompts
```

{{< notice tip >}}
If running this for a new install on old configured hosts, this command resets your `~/.ssh/known_hosts` file with the new host SSH identities:

- `ssh-keygen -R` removes the known host
- `ssh-keyscan -H $i >> ~/.ssh/known_hosts` adds the new key(s) to `~/.ssh/known_hosts`

```shell
for i in "${server_list[@]}"; do ssh-keygen -R $i && ssh-keyscan -H $i >> ~/.ssh/known_hosts; done`
```
{{< /notice >}}

## Add support for the USB NICs

We've made it pretty far with a single NIC on the default Management Network. ESXi recognizes the USB NIC as a networking device but without the drivers, it cannot properly set the link speed (1G, full duplex). Before we can configure our network stack, we need to install the drivers.

To add the drivers, use the [USB Network Native Driver for ESXi](https://flings.vmware.com/usb-network-native-driver-for-esxi) fling. Download the zip file somewhere on your local machine for future use.

{{< notice warning >}}
It is important to select the proper vSphere version in the drop-down menu for the fling.
{{< /notice >}}

The playbook `00-add-usb-fling-to-hosts.yml` runs 3 tasks, on each ESXi host, to:

- `SCP` the zip file based on the `source_usb_driver_zip:` and `dest_usb_driver_zip:` variables in `inventory.yml`.
- Use the `shell` module to remotely execute `esxcli software component apply -d `{{ dest_usb_driver_zip }}``
- Reboot the hosts based on a `Y/N` prompt

```shell
# also enables SSH but assumes a reboot disables
python3 $(which ansible-playbook) 00-add-usb-fling-to-hosts.yml 
```

{{< notice warning >}}
It takes ESXi about 10 **real** minutes to start up.

I also found myself having to reboot twice. Once via the Ansible scripts above and another I just used the power button physically on the NUCs to hard-crash reboot them.

I haven't found a way around this, but just a heads up. I think the hard power off crash is why I needed to restart VCSA (covered in future section)
{{< /notice >}}

Once completed, log in the UI and ensure your network cards show the proper link speed:

![](https://i.imgur.com/UWGIdSj.png)

On the far right side, you'll notice that ESXi has found both NICs and they are the proper speed.

## Get the vCenter Appliance (VCSA) IP

Ensure that the VCSA is powered on before starting since we rebooted the servers. The following playbook checks the physical ESXi host running vCenter, set by `vcenter_esxi_host:` in `inventory.yml`.

There is no harm in running this playbook ASAP and as frequently as you'd like ([view source](https://github.com/jimangel/ansible-managed-vmware-homelab/blob/main/99-power-on-vcsa-vm.yml)).

The following playbook has a single task, delegated to localhost, that checks if a VM named "Ensure VCSA is on" that ensures the state of a VM named "VMware vCenter Server" is on.

```shell
python3 $(which ansible-playbook) 99-power-on-vcsa-vm.yml
```

Output:

```shell
# indicates it's on
ok: [localhost]

# indicates it was just turned on
changed: [localhost]
```

{{< notice note >}}
If it was `changed:` it could take upwards of 10 minutes to fully boot depending on resources.
{{< /notice >}}

Update `inventory.yml` variable (`vcenter_hostname: "YOUR.IP.ADDRESS.###"`)

## Create the Datacenter, Cluster, and Host VCSA objects

Confirm there's no existing setup via the GUI. In my case, I'll browse to the vCenter IP `172.16.6.89`, Launch vSphere Client:

- `vcenter_username: "administrator@vsphere.mydns.dog"`
- `vcenter_password: "VMwadminPW!99"`

We can confirm we have nothing. No datacenter, no cluster, no folders, no hosts.

![](https://i.imgur.com/GPxR1Nu.png)

The [01-vcsa-and-esxi-init.yml](https://github.com/jimangel/ansible-managed-vmware-homelab/blob/main/01-vcsa-and-esxi-init.yml) playbook runs about 12 tasks, all delegated to localhost, that include:

- Ensure Python is configured with proper modules for vmware community usage
- Create Datacenter - `{{ datacenter_name }}`
- Create Cluster - `{{ cluster_name }}`
- Add ESXi Host(s) to vCenter
- Set NTP servers for all ESXi Hosts in `{{ cluster_name }}` cluster
- Disable IPv6 for all ESXi Hosts in `{{ cluster_name }}` cluster
- Add a new vCenter license
- Add ESXi license and assign to the ESXi host
- Enable vSphere HA with admission control for `{{ cluster_name }}`
- Enable DRS for `{{ cluster_name }}`
- Add resource pool named `{{ resource_pool_name }}` to vCenter

```shell
python3 $(which ansible-playbook) 01-vcsa-and-esxi-init.yml
```

Confirm it worked via the gui:

![](https://i.imgur.com/V8vllZw.png)

## VMware networking review, problems, and solutions

{{< notice note >}}
Most of this stuff you don't really need to know, but a lot more of my networking choices makes sense after reading "why."
{{< /notice >}}

### VSS vs. VDS review

VMware can be configured with 2 types of networking/switch architectures:

1. vSphere Standard Switch (VSS or vSS - the default)
1. vSphere Distributed Switch (VDS or vdswitch)

Since we took the defaults, our environment currently uses 1 NIC and vSphere Standard Switch.

Both approaches allow for all of the VMware goodness (HA/DR, failover, vMotion, etc) but differ when it comes to setup/management.

The Distributed Switch deploys a control plane on all ESXi hosts that adds a layer to automate management on all existing, or future, hosts and configure the VMware cluster networking once for all hosts. VDS enables for QoS and advanced traffic routing.

The Standard Switch must be configured, in matching ways, on each host separately.

Lastly, VDS requires an Enterprise License (which I have with VMug Advantage) and could be a limiting factor.

### VMware networking review

I struggled with this longer than I should have; I couldn't understand why certain things were using a VLAN or why certain networking objects had dependencies on others.

I found this picture to be a helpful start:

![](https://i.imgur.com/WoSKDDT.png)

You can start to see how certain resources can share groups or why we need a port group associated with a vmk (so we can assign VLAN). Let's look at what each object _actually_ is:

- **VMkernel network interface (vmk)**
  - Generated "fake" virtual NIC running on the ESXi host kernel
  - Usually the "thing" that gets an IP from DHCP
  - `vmk0` is traditionally management traffic (your ESXi host IP)
- **Distributed Port Groups**
  - Mainly VLAN settings that can be assigned to vmks (fake NICs)
- **Uplink Port Group**
  - Map real NICs to uplinks on the virtual switch
  - Can have multiple uplinks (1 per host)
  - Can set failover and load balancing policies
- **vmnic0 or vusb0**
  - Real NIC on the host (could also be USB)

After editing for my use case, here's a better view (the red line down the middle indicates that we are splitting management and VM traffic):

![](/img/diagram_vm_nic_edit.png)

### The problem

You can't move a physical uplink (vmnic0) without first disconnecting it from the vSwitch0 (default vSS).

The default mgmt `vmk0` assigned DHCP from the host is linked to the vSS (need to move, but can't move until there's a new switch).

As a result, I cannot move the real `vmnic0` to a VDS uplink group without first removing it from the VSS uplink group (breaking all management connectivity).

**`vmk0` is the virtual NIC representing my REAL ESXi management NIC.**

Which also means, I would lose access to VCSA and my ability to configure anything else.

Short of doing command-line surgery, or adding more NICs, we'll have to do this migration in phases.

Here's the VSS starting setup:

![](/img/starting.svg)

In the VCSA UI:

![](https://i.imgur.com/rD1BfKb.png)

### Solution

We'll do the network configuration in 2ish phases, temporarily move management NIC to vusb0 & configure VDS, configure networking, move management NIC back.

The first phase, moves the management `vmk0` virtual NIC from the 2.5G NIC to the 1G NIC temporarily.

![](/img/phase-one.svg)

This allows us to maintain connectivity to VCSA and management while migrating the 2.5G NIC to a vDS architecture.

### Temporarily move management NIC to vusb0 & configure VDS

The following playbook runs about 18 tasks, all delegated to localhost, that include:

- Create operations Distributed vSwitch - `{{ ops_dvs_switch_name }}`
- Create DVS Uplink portgroup - "DVS-MGMT-Uplinks"
- Gather all registered dvswitch
- Add Hosts `{{ physical_nic_2 }}` to `{{ ops_dvs_switch_name }}` <mark>temporarily</mark>
- Create new Management Network port group on vlan 0 - "DVPG-Management Network"
- Create vMotion port group on vlan 5 - "DVPG-vMotion"
- Create storage portgroup on vlan 4 - "DVPG-Storage"
- Add vMotion "vmk1" VMKernel NIC
- Add storage "vmk2" VMKernel NIC
- Migrate Management "vmk0" to `{{ ops_dvs_switch_name }}` vDS
- <mark>Migrate VCSA to vDS to not disrupt VCSA</mark>
- Delete the default "vSwitch0" vSwitch to allow moving the `{{ physical_nic_1 }}` to `{{ ops_dvs_switch_name }}`
- Creating VM Network Distributed vSwitch - `{{ vm_dvs_switch_name }}`
- Create DVS Uplink portgroup - "DVS-VM-Uplinks"
- Create VM Network portgroup - "DVPG-VM Network"

```shell
python3 $(which ansible-playbook) 02-networking.yml
```

At this point we have our VDS configured.

### Move management NIC back

The second phase involves configuring our physical NICS (vmnic0 and vusb0) so the 2.5G NIC is on the operations switch and the 1G NIC is on the VM switch.

![](/img/phase-two.svg)

The following playbook runs 2 tasks, all delegated to localhost, that include:

- Replace hosts physical nic with `{{ physical_nic_1 }}` on VDS `{{ ops_dvs_switch_name }}`
- Add Hosts `{{ physical_nic_2 }}` to `{{ vm_dvs_switch_name }}`

```shell
ansible-playbook 02.5-networking.yml
```

> If you see an error "Network connectivity lost" in the vCenter UI it can be safely reset back to green. This is understood when moving physical uplinks with no redundancy.

### Test VMWare networking

```shell
# (enable and) ssh to one of the hosts
ssh root@ESXIHOSTIP

# use vmkping to see if things are working to another host
vmkping -I vmk0 172.16.6.102

# to outside
vmkping -I vmk0 google.com

# to storage appliance
vmkping -I vmk0 192.168.7.19
```

## ESXi storage overview

I have a QNAP TS-253-4G with a few SSDs that I use for my homelab. My plan is to use NFS for ISO / file shares and iSCSI for vmdks (VM host disk).

The details are more specific to my use case, but I wanted to share any highlights:

- I'm not using vSAN so I wanted some shared filesystem for HA / vMotion
- Since it's not truly HA, I disabled some of the heartbeat checks
- If using iSCSI, discovery is easier than static to manage
- When creating LUNs (slices of an iSCSI Storage Array), consider whether to span multiple:

![](https://i.imgur.com/YDmYqmL.png)

One of the other reasons to use a shared storage, is the ability to quickly rebuild my environment. With some planning, I can keep my VMs while rebuilding the surrounding infrastructure.

### QNAP iSCSI setup

Since we have 4 hosts and I have 2TBs, I'll create one giant LUN that all hosts share as a VMFS ([official docs](https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.storage.doc/GUID-52DC7277-5321-4BB5-86B4-D73D258F6529.html)).

How it looks in VMware:

![](https://i.imgur.com/4WyxfcZ.png)

On the storage appliance, create the target:

![](https://i.imgur.com/dGWzV7D.png)

Skipping chap auth for now, but worth doing if in production.

![](https://i.imgur.com/PCEAMRt.png)

Upon applying, the LUN creation wizard pops up. I chose to provision a thick Lun:

![](https://i.imgur.com/VPRi0Vh.png)

Created a 1TB lun named `terralun`

![](https://i.imgur.com/fTnFkf1.png)

Since I used the wizard, it automatically maps the lun to my iSCSI target.

![](https://i.imgur.com/UaYHuOH.png)

Once created, verify it can be discovered on your ESXi hosts.

### Troubleshooting iSCSI on VMware

Good [doc on iSCSI from VMware](https://vdc-repo.vmware.com/vmwb-repository/dcr-public/24be7af7-d9cd-48d9-bab8-8c91614be19d/0ca33108-8017-4b40-86b9-f066456894ea/doc/GUID-8E8481F7-9506-4437-94F1-2DAEEE8A6053.html) here

Validate the ESXI adapter exists:

```shell
# check for iscsi adapters
esxcli iscsi adapter list
```

Output:

```
Adapter  Driver     State   UID            Description
-------  ---------  ------  -------------  -----------
vmhba64  iscsi_vmk  online  iscsi.vmhba64  iSCSI Software Adapter
```

### Configure a NFS datastore VMware ESXi

I also added a NFS datastore that I granted permission based on IP address.

I'm not going to add a ton of detail here, just adding a NFS server that I created on another NAS:

![](https://i.imgur.com/XmilXkl.png)

Dealing with permissions:

![](https://i.imgur.com/M3EQt8z.png)

### All together in a storage playbook

The following Ansible playbook runs 5 tasks, all delegated to localhost, that include:

- Mounting NFS datastore `{{ nfs_server_ip }}` to all ESXi hosts
- Enable iSCSI on all ESXi hosts
- Add a dynamic target to iSCSI config on all ESXi hosts
- Add VMKernels to iSCSI config on all ESXi hosts
- Rescan datastores for a given cluster - all found hosts will be scanned

```shell
ansible-playbook 03-storage.yml
```

Validating it worked in the UI:

![](https://i.imgur.com/0S4ah2p.png)

That's it! We're done! You can optionally do a full reboot of everything:

```shell
#  reboot all hosts
ansible-playbook 99-reboot-all-hosts.yml

# ensure VCSA is up still
ansible-playbook 99-power-on-vcsa-vm.yml
```

## Conclusion

I attempted to keep this to the core essentials that would replicate a production environment. Once the environment is up, I run `ansible-playbook 04-on-top.yml` to create some folders / rename datastores.

I ignored updating vcsa on purpose. I really hope I rebuild the env more than I update the hosts / VMs.

{{< notice tip >}}
If possible, having a ESXi host that:

Meets the [VMware Compatibility Guide](https://www.vmware.com/resources/compatibility/search.php), specifically CPU, NIC, and memory, AND has a minimum of 4 supported NICs onboard (not USB).

It would cut down **SO MUCH** of this series. It would also allow for easier automation (no networking juggling or ISO modifications).
{{< /notice >}}

If you want to see what it looks like end-to-end (10 commands after ESXi and VCSA install), you can [checkout my gist that I use to re-provision my homelab](https://gist.github.com/jimangel/5bd4f5d19380f487c9c82c4b5405ab42).

Thanks for reading!

##  Helpful resources:
- https://devstime.com/2021/07/19/misconception-about-vmotion-traffic-usage/
-  Nutanix wrote a great article on [recreating the "default" vSS configuration](https://portal.nutanix.com/page/documents/kbs/details?targetId=kA032000000CifmCAC).