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

## Intro from Part 1:

In the fall of 2022, I decided to build a VMware homelab so I could explore [Anthos clusters on VMware](https://cloud.google.com/anthos/clusters/docs/on-prem/latest/overview) a bit closer. A few jobs back I administered VMware and in 2017 I blogged about [creating a single node VMware homelab](/posts/vmware-homelab-build-2017). I thought it _couldn't be that hard_ to build a multi-node VMware homelab with a few Intel NUCs. I was wrong.

> The difference in settings up a single node ESXi host vs. a cluster of 3 ESXi hosts was staggering. Mainly the networking design required.

At first I was going to update my older VMware install posts but, after hitting enough issues, it was clear I needed to start over. My goal is to start with an overview of things to consider before jumping in. Reading my series should save you many hours of problems if you have similar ambitions to build a multi-node lab.

This is **Part 3** of a **3** part series I've called **VMware homelab**:

- [[Part 1]: Introduction & Considerations](/posts/vmware-series-p1-considerations/)
- [[Part 2]: How to install a vSphere cluster at home](/posts/vmware-series-p2-installation/)
- [Part 3]: How to configure vSphere networking and storage

---

**TL;DR:** If external networking is configured properly with vLANs, trunks, and routes, it should be a matter of configuring each hosts networking through VCSA via Ansible.

## High level overview

Now that we have a vCenter API and multiple ESXi hosts booted, we should be able to complete the rest in an more automated fashion.

1) Bootstrap ESXi hosts for automation
1) Use Ansible to:
    - add USB NIC support
    - create the vCenter layout (datacenter / clusters / folders) and add ESXi hosts
    - create the networking setup
    - create the storage setup
    - reboot

Selfishly, the rest of this post is specific for my environment, but I hope it's written in a way that you feel comfortable adopting.

## Prerequisites

99% of the Ansible commands for VMWare delegate (run) on your localhost. I'm using a mac and use `brew` (a package manager) to install the following pre-reqs:

- Ansible (`brew install ansible`)
- Python (`brew install python`)

> I configured my `~/.zshrc` to include:
> ```
> eval "$(/opt/homebrew/bin/brew shellenv)"
> export PATH="/opt/homebrew/opt/python@3.10/libexec/bin/:${PATH}"
> ```
>
> I don't recall if this is required... 🤷

## Ansible overview and setup

A core principle of Ansible: I should be able to run my playbooks at anytime without fear of disruption. Ansible should ensure desired state. If you cannot run a playbook without fear, 

I have this step first because it enables us to do bulk actions like enable SSH or copy files.

I don't consider my Ansible approach to follow best practices, however, I attempted to keep my layout easy to adopt. There a lot of best practices skipped for the preference of comfort and ease of adoption / documentation.

The flat repo structure (12 files):

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

There are no Ansible roles, only playbooks (collections of Ansible tasks), and <mark>the "inventory.yml" file contains both host **AND** custom variable information.</mark> Allowing for repeatable, desired-state, management of clusters. I hope this design enables you to easily understand what's being done and how to adopt it.

I could delete, and combine, some of the files if I did not approach this in a verbose way.

If you haven't used Ansible before, the repository I created uses a `ansible.cfg` in the root of the directory to define where my inventory file is (`inventory.yml`). This saves a lot of repetitive commands traditionally required for `ansible-playbook`.

{{< notice tip >}}
The module we use most ([community.vmware](https://docs.ansible.com/ansible/latest/collections/community/vmware/index.html)) is actually an API/SDK integration. This means that almost all playbooks are executed on your localhost.

This is important to understand: we are not managing the hosts, we are running API commands to vCenter. As such, you'll see many playbooks "delegate" to localhost, on purpose.
{{< /notice >}}

To get started, clone my public repository:

```shell
git clone git@github.com:jimangel/ansible-managed-vmware-homelab.git

cd ansible-managed-vmware-homelab
```

Update `inventory.yml` variables:

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

The following steps are automated with Ansible, but I hope to explain them clear enough that the tooling doesn't matter.

## Enable SSH on the ESXi hosts

This can be done via my helper playbook `99-enable-ssh.yml` and disabled with `99-disable-ssh.yml`. ESXi automatically turns off SSH when it reboots - unless the SSH service policy is changed.

The following playbook runs a single task, for each ESXi host, named "Start SSH service setting for all ESXi Hosts" to do just that. It runs on a loop over all ESXi hosts and uses the provided `esxi_username` & `esxi_password` variable to authenticate.

```shell
# there's also 99-disable-ssh.yml
ansible-playbook 99-enable-ssh.yml
```

### Copy SSH keys to each host

Copying your SSH keys to the ESXi hosts allow us to use Ansible directly on the hosts for one-off commands opposed to using the VMware SDK.

To copy the zip file of USB drivers, we do need to "properly" configure SSH so Ansible can SCP files over.

I didn't use Ansible to copy the file / apply it to each ESXi host because it didn't seem obvious. Using the native shell, I can require less dependencies.

Using the shell:

```shell
export server_list=(172.16.6.101 172.16.6.102 172.16.6.103)

# if needed, create a new VMware SSH
# ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_vmware

# Copy the public key the right place on the ESXii host
for i in "${server_list[@]}"; do cat ~/.ssh/id_rsa_vmware.pub | ssh root@${i} 'cat >>/etc/ssh/keys-root/authorized_keys'; done

# manually enter the password `esxir00tPW!` as it prompts
```

Output similar to:

```shell
(root@172.16.6.101) Password: 
(root@172.16.6.102) Password: 
(root@172.16.6.103) Password: 
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

We've made it pretty far with a single NIC on the default Management Network. We now need to add the USB NIC which enables our ability to setup the vDS.

To add the drivers, we'll use the [USB Network Native Driver for ESXi](https://flings.vmware.com/usb-network-native-driver-for-esxi) fling. Downloaded the zip file somewhere on the Ansible local machine for future use.

{{< notice warning >}}
It is important to select the proper vSphere version in the drop-down menu for the fling.
{{< /notice >}}

The following playbook runs 3 tasks, on each ESXi host, to:

- `SCP` the zip file based on the `source_usb_driver_zip` and `dest_usb_driver_zip` variables.
- Use the `shell` module to execute `esxcli software component apply -d '{{ dest_usb_driver_zip }}'`
- Reboot the hosts based on a `Y/N` prompt

```shell
# also enables SSH but assumes a reboot will disable after
ansible-playbook 00-add-usb-fling-to-hosts.yml 
```

{{< notice warning >}}
It takes ESXi about 10 real minutes to start up.

I also found myself having to reboot twice. Once via the Ansible scripts above and another I just used the power button physically on the NUCs to hard-crash reboot them.

I haven't found a way around this, but just a heads up. I think this is why I need to ensure VCSA is on (upcoming section)
{{< /notice >}}

Once completed, log into your host and ensure your network cards show the proper negotiation speed:

![](https://i.imgur.com/UWGIdSj.png)

On the far right side, you'll notice that ESXi has found both NICs and they are the proper speed.

## Get the VCSA IP

Ensure that the VCSA is powered on before starting since we rebooted the servers. The following playbook checks the physical ESXi host running vCenter, set by `vcenter_esxi_host:` in `inventory.yml`.

There is no harm in running this playbook ASAP and as frequently as you'd like.

The following playbook has a single task, delegated to localhost, that checks if a VM named "Ensure VCSA is on" that ensures the state of a VM named "VMware vCenter Server" is on.

```shell
# running this multiple times is harmless, it's either on or it's not
ansible-playbook 99-power-on-vcsa-vm.yml
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

### Update `inventory.yml` variable

- `vcenter_hostname: "172.16.6.81"`

### Create the DC/cluster/hosts


Confirm there's no existing setup via the GUI. In my case, I'll browse to the vCenter IP `172.16.6.89`, launch vsphere client (html5), and attempt to login.

- `vcenter_username: "administrator@vsphere.mydns.dog"`
- `vcenter_password: "VMwadminPW!99"`

We can confirm we have nothing. No datacenter, no cluster, no folders, no hosts.

![](https://i.imgur.com/GPxR1Nu.png)

The following playbook runs about 12 tasks, all delegated to localhost, that include:

- Ensure Python is configured with proper modules for vmware community usage
- Create Datacenter - '{{ datacenter_name }}'
- Create Cluster - '{{ cluster_name }}'
- Add ESXi Host(s) to vCenter
- Set NTP servers for all ESXi Hosts in '{{ cluster_name }}' cluster
- Disable IPv6 for all ESXi Hosts in '{{ cluster_name }}' cluster
- Add a new vCenter license
- Add ESXi license and assign to the ESXi host
- Enable vSphere HA with admission control for '{{ cluster_name }}'
- Enable DRS for '{{ cluster_name }}'
- Add resource pool named '{{ resource_pool_name }}' to vCenter

```shell
ansible-playbook 01-vcsa-and-esxi-init.yml
```

Confirm it worked via the gui:

![](https://i.imgur.com/V8vllZw.png)

## VMware Networking 101

FUNDAMENTALS

![](https://i.imgur.com/yEVNgnL.png)
> From: [vSphere Distributed Switch Architecture](https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.networking.doc/GUID-B15C6A13-797E-4BCB-B9D9-5CBC5A60C3A6.html)

vds vs. vss: (call out license issue)
![](https://i.imgur.com/cEC5kUp.png)

Good pic / explaination of what we do: https://www.youtube.com/watch?v=eDJ3OfXTkLs
![](https://i.imgur.com/WoSKDDT.png)

Explain like im 5 networking, use mermaid to break this diagram down to what we're doing:

The name Virtual Distributed Switch, vSphere Distributed Switch (VDS), or Distributed vSwitch (DVS, dvswitch) are used somewhat interchangeably. 

THROW TO THE MAIN ARTICLE WHERE POSSIBLE
DIVE INTO TEH COMPONENTS
OVERVIEW HERE (hackmd?)
INCLUDE SWITCHING TRUTHS
- Networking
    - focus vDS on GUI
    - Delete the management vSS network? (already been migrated)
    - Traffic misconceptions: https://devstime.com/2021/07/19/misconception-about-vmotion-traffic-usage/

I ultimately want to use vDS which can only be fully configured in vSphere. To make the migration easy, I want to use a redundant vSwitch so I can easily split things up later as vDS.

> NOTE: PHysical NICs Can't Share uplinks*** (so of course vmnic0 can't take the same uplink as usb0 - preventing the shared migration....).

### starting point overview

Go over exact migration plan and why


For reference, my VLANs are:

Purpose            | VLAN       | Interface | Range
-------------------|------------|-----------|----------------
Management Network | 0 (native) | `vmnic0`    | `172.16.6.0/24`
Storage            | 4          | `vmnic0`    | `172.16.4.0/24`
vMotion            | 5          | `vmnic0`    | `172.16.5.0/24`
VM Network         | 64         | `vusb0`      | `192.168.64.0/18`

Switch configuration:

A vSS with 1 uplink (2G NIC) and 2 port groups. A VM port group (no IP / vmk) and a mgmt port group with the default vmk0.

![](https://i.imgur.com/rD1BfKb.png)

Physical NICs and throughput:

![](https://i.imgur.com/THUzcln.png)

You'll notice the default networking creates a Management and a VM Network port group for use (prioritizing the mgmt creation):

![](https://i.imgur.com/gKzi0we.png)

The USB NIC is found (in the picture above `vusb0` with the green hardware icon.)

The default "VM Network" thinks it should use the `vmnic0`. We'll change this before deploying vCenter. VM Network default topology:

![](https://i.imgur.com/ncXnMP4.png)

The default "Management" network is correctly configured. I have the physical port's native VLAN set to my vmware-mgmt network (along with other tagged VLANs):

![](https://i.imgur.com/EGQPSJU.png)

{{< notice tip >}}
Nutanix wrote a great article on [recreating the "default" vSS configuration](https://portal.nutanix.com/page/documents/kbs/details?targetId=kA032000000CifmCAC). I would recomend keeping the link handy in case you find yourself locked out. 
{{< /notice >}}

### vDS Migration (the plan - or the problem?)

EXPLAIN BETTER (edit)

It's a nested problem. First of all,

Keeping in mind that the vmk0 is the "thing" that gets the IP address for your host. The physical NIC (vmnic0 and usb0) does nothing but provide uplink to your network. Lastly, we only have 2 uplinks where a "real" vSphere environment might have more room for error.

The Foundation of the problem is:

- I want to run all management operations on my 2.5G (vmnic0) network using a virtual Distributed Switch (vDS)
- The default mgmt vmk0 that has been assigned DHCP from the host is linked to the vSS (need to move, but can't move until there's a new switch)
- VCSA runs within the same portgroup on the vSS
- You can't move a physical uplink (vmnic0) without first disconnecting it from the vSwitch0 (default vSS)

Possible solutions:

- Leave vSS as the default
    - Pros: Easy
    - Cons: Independent management, No QoS, and less "production" like
- Boot the "default" management ESXi install to the USB nic, leaving vmnic0 to 


MAYBE MIX THIS WITH THE ARTICLE AND ADD TO REPO TOO

Before (pic)
drawing / physical nics / switches


/img/starting.svg

/img/phase-one.svg

/img/phase-two.svg


During (pic)

After state (pic)

### DO THE THING HERE!?!?!? - cut so much bullshit above

WHY 1 uplink vs. active/standby? I want the NetIO to only impact one NIC.

TODO: OVERVIEW
- create 2 vds switches
- 4 port groups
- migrates vmk0 whstever

The following playbook runs about 18 tasks, all delegated to localhost, that include:

- Create operations Distributed vSwitch - '{{ ops_dvs_switch_name }}'
- Create DVS Uplink portgroup - "DVS-MGMT-Uplinks"
- Gather all registered dvswitch
- Add Hosts '{{ physical_nic_2 }}' to '{{ ops_dvs_switch_name }}' <mark>temporarily</mark>
- Create new Management Network port group on vlan 0 - "DVPG-Management Network"
- Create vMotion port group on vlan 5 - "DVPG-vMotion"
- Create storage portgroup on vlan 4 - "DVPG-Storage"
- Add vMotion "vmk1" VMKernel NIC
- Add storage "vmk2" VMKernel NIC
- Migrate Management "vmk0" to {{ ops_dvs_switch_name }}' vDS
- <mark>Migrate VCSA to vDS to not disrupt VCSA</mark>
- Delete the default "vSwitch0" vSwitch to allow moving the '{{ physical_nic_1 }}' to '{{ ops_dvs_switch_name }}'
- Creating VM Network Distributed vSwitch - '{{ vm_dvs_switch_name }}'
- Create DVS Uplink portgroup - "DVS-VM-Uplinks"
- Create VM Network portgroup - "DVPG-VM Network"


```shell
ansible-playbook 02-networking.yml
```

temp uses usb0 for the new vds switch which allows us to keep everything up whiel removing the vSS.
COMFORT: It might be hairy, but this can be reverted using hte above nutanix article on each esxi host.

End result:

Operations vDS:
![](https://i.imgur.com/aVK9XOs.png)

VM vDS:
![](https://i.imgur.com/flrAsIW.png)

The fact that I was able to take the picture is a good sign things are working!

## THE SWAP

We need to swap out our physical NICS (vmnic0 and vusb0) so the 2.5G NIC is on the operations switch and the 1G NIC is on the VM switch.

The following playbook runs 2 tasks, all delegated to localhost, that include:

- Replace hosts physical nic with '{{ physical_nic_1 }}' on VDS '{{ ops_dvs_switch_name }}'
- Add Hosts '{{ physical_nic_2 }}' to '{{ vm_dvs_switch_name }}'

```shell
ansible-playbook 02.5-networking.yml
```

It is safe to Reset to Green "Network connectivity lost" - this is understood when moving physical uplinks with no redundancy.

### Test Networking

```shell
# ssh to one of the hosts

# use vmkping to see if things are working to another host
vmkping -I vmk0 172.16.6.102

# to outside
vmkping -I vmk0 google.com

# to storage appliance
vmkping -I vmk0 192.168.7.19
```

## Creating datastores (NFS, iSCSI) and storage

- Storage
    - ensure to cover the datastore mount to other hosts
    - Since my other vmks can access iSCI network, I might not need to create the vmk
    - RECOMENDATION: ignore heart beat datastores leave to reader (how to disable)
    - iSCSI - dicovery is easier than static... 
    - explain that VMs that are on iSCSI can be reconnected to a new host in the event of a failure (or entire vSphere rebuild)

## How to configure an iSCSI datastore VMware ESXi

for iscsi explain how we need to enable a service, bind (walk the ansible)

Good doc on iscsi: https://vdc-repo.vmware.com/vmwb-repository/dcr-public/24be7af7-d9cd-48d9-bab8-8c91614be19d/0ca33108-8017-4b40-86b9-f066456894ea/doc/GUID-8E8481F7-9506-4437-94F1-2DAEEE8A6053.html

validate adapter:

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


### LUN planning



TRIM A LOT OF THIS...
KEEP IT HIGH LEVEL




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

The QNAP LUN autopopulated and I nexted my way throught the addition.

Once created, verify it's configured on multiple hosts.

> Note: In production, probably not recomended, but for now, I'll use mutliple vmdk's on the same VMFS lun.


NOTE: it was kind of strange, I rebooted all esxi hosts and when they came back up only a single ESXi host was connected. Luckily, re-running my playbook helped but it's worth checking if you run into issue down the road.

## How to configure an NFS datastore VMware ESXi 7.0

WHAT TO UPDATE IN ANSIBLE?

Had to putz with permissions but I got NFS to work"
![](https://i.imgur.com/M3EQt8z.png)

I'm not going to add a ton of detail here, just adding a NFS server that I created on another NAS:

![](https://i.imgur.com/XmilXkl.png)


The following playbook runs about 5 tasks, all delegated to localhost, that include:

- Mounting NFS datastore '{{ nfs_server_ip }}' to all ESXi hosts
- Enable iSCSI on all ESXi hosts
- Add a dynamic target to iSCSI config on all ESXi hosts
- Add VMKernels to iSCSI config on all ESXi hosts
- Rescan datastores for a given cluster - all found hosts will be scanned

```shell
ansible-playbook 03-storage.yml
```

Success:

![](https://i.imgur.com/0S4ah2p.png)

That's it! We're done! You can optionally do a full reboot of everything:

```shell
#  reboot all hosts
ansible-playbook 99-reboot-all-hosts.yml

# ensure VCSA is up still
ansible-playbook 99-power-on-vcsa-vm.yml
```

## Conclusion

I tried to keep this down to the core essentials that would replicate a production environment (kinda). In addition, I wanted to add some folders / rename datastores but didn't think it was worth including check out <FILE> (to run: `ansible-playbook 04-on-top.yml`)

I ignored updating vcsa on pupose. I really hope I rebuild the env more than I update the hosts / VMs... If you're curious, here's how you update the vCenter. (link)

DO A DEEPER WRAP UP ON THE WHOLE SERIES (part 1 is considerations, 2 is manual os / bootstrap, 3 is automation configuration). Built in a way that explains my problems / solutions and is solved in a way that the process can be modified for your own needs.


{{< notice tip >}}
If possible, having a ESXi host that:

- meets the [VMware Compatibility Guide](https://www.vmware.com/resources/compatibility/search.php)
  - specifically CPU, NIC, and memory
- has a minimum of 4 supported NICs onboard (not USB)
  - has shared NIC speed across all NICs on each host (like 10GB)

would cut down SO MUCH of this series. I could also update the Ansible playbooks to be more idempotent. The biggest blocker is migrating the Management Network when there's only a single NIC free with little downtime. By having 4 NICs, I could set desired state and run the complete playbook to bootstrap VMware.

This would cut my rebuild process down to only 3 commands and I could use the upstream ISOs without modifications.
{{< /notice >}}

If you want to see what it looks like end-to-end (10 commands after ESXi and VCSA install), you can [checkout my gist that I use to re-provision my homelab](https://gist.github.com/jimangel/5bd4f5d19380f487c9c82c4b5405ab42).

Let me know if you