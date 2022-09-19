---
title: "How to automate a bare metal Ubuntu 22.04 LTS installation"
description: "Provision physical Ubuntu 22.04 LTS servers, fully automated, with no additional infrastructure to manage using cloud-init and USBs"
summary: "Automate the complete installation of Ubuntu 22.04 LTS on physical servers using cloud-init and USBs"
date: 2022-09-12
tags:
- walkthrough
- automation
- homelab
- ubuntu
- cloud-init
keywords:
- ubuntu 22.04 lts
- usb cloud-init ubuntu
- how to automate Ubuntu 22.04
- walkthrough
- automation
- homelab
- ubuntu
- cloud-init
- what is a live-server
- what is subiquity
- what is cloud-init
- what is curtin
- what is autoinstall
- what is livefs-editor
- what is livefs-edit
- ubuntu live-server USB
- bootable ubuntu
- cloud-init userdata
- subiquity
- modify an iso
- edit ubuntu live iso
- how to modify ubuntu iso
- 22.04 lts
showToc: true
TocOpen: false
draft: true
hidemeta: false
comments: true
ShowWordCount: false
cover:
    image: /img/ubuntu-usb-install-22-04-cover.png # image path/url
    alt: "Ubuntu desktop image for 22.04" # alt text

slug: "automate-ubuntu-22-04-lts-bare-metal"  # make your URL pretty!
---

I want to provision my homelab physical servers, as if they were cloud VMs, with little user interaction.

To acomplish this, I use 2 USB sticks - one for booting a temporary OS and the other for providing the `cloud-init` autoinstall config - for a complete "no touch" installation.

![](/img/ubuntu-usb-install-22-04-USB-rack.jpg)

I found this whole topic pretty confusing when I started to explore it. The first half of this post is a deep-dive into the automation components and the second half is the technical steps - feel free to [jump to the second half](#create-a-bootable-live-server-usb).

After reading this article, you'll have an in depth understanding about how to automate Ubuntu server installations using `cloud-init`.

> ### What is cloud-init?
>
> `cloud-init` is a service that runs at boot to provision a server or VM. `cloud-init` provides the ability to add SSH keys, provision disks, install applications, setup users, and more - all before the first user interaction. `cloud-init` uses [datasources](https://cloudinit.readthedocs.io/en/latest/topics/datasources.html) (for example: GCP, AWS, Azure, NoCloud) as a way to abstract the configurations per cloud provider.
>
> Unless configured to do otherwise, cloud-init runs once; only on the first boot. It tracks the first boot by comparing the instance ID in the cache (`/var/lib/cloud/data`) against the instance ID at runtime.
>
> `cloud-init` attempts to automatically find the datasource; unless something like `ds=DATASOURCE[;key=val;key=val]` is specified on the kernel boot command line. By creating a volume named `CIDATA`, `cloud-init` autodetects the "[NoCloud](https://cloudinit.readthedocs.io/en/latest/topics/datasources/nocloud.html)" datasource.
>
> One **required** configuration object is named **meta-data** (no extension) and is typically used by cloud providers to paramiterize their instance data (left intentionally blank in this demo) and another named **user-data** containing the actual installation instructions for provisioning the server.

After failing to find any configurations, `cloud-init` defaults automatically to the mounted volume <mark>named exactly "CIDATA"</mark> as a [NoCloud](https://cloudinit.readthedocs.io/en/latest/topics/datasources/nocloud.html) datasource ([official docs](https://cloudinit.readthedocs.io/en/latest/topics/datasources/nocloud.html)).

## Prerequisites

- 2 USBs with 4GB+ storage
- An Ubuntu 22.04 LTS host with USB ports

To make the process 100% "no-touch" I also set the host's BIOS to give USB devices boot priority and I setup fixed IP reservations for each host. This way, after plugging in the USBs, a reboot triggers a install and the target host eventually boots with the same IP. However, those steps aren't technically pre-reqs.

## Solution deep-dive

- [Create a bootable live-server USB](#create-a-bootable-live-server-usb) to act as the live OS, in memory, provisioner
- Modify the grub boot file to allow unattended installs (optional)
- [Create another USB for a cloud-init config](#create-cloud-init-files) to launch our [autoinstall module](https://cloudinit.readthedocs.io/en/latest/topics/modules.html#ubuntu-autoinstall).<sup>1</sup>
- [Plug in both USBs](#insert-both-usbs-and-power-on-your-server)
- Boot to an auto-provisioned OS

One USB boots a temporary live-server OS in memory :cd: and discovers the install config on the other (CIDATA) USB, triggering the install on the targets _best disk available._<sup>2</sup>

> ### What is a live-server (temporary OS)?
>
> A live-server refers to a special Ubuntu ISO, or installation media, used to install and configure Ubuntu servers.
>
>The live-server ISO is special because it is preconfigured to boot in memory (from USB) and comes prepackaged with installation software.

![cloud-init boot process via usb](/img/cloud-init-overview.svg#center)

> <sup>1</sup> (not pictured) autoinstall leverages `subiquity` to act as the provisioning controller; watching for events. The bulk of `subiquity` is interfacing with `curtin`, a "smart installer" that handles the important tasks such as creating disks, connecting to networks, etc.
>
> <sup>2</sup> (not pictured) <mark>curtin selects the best suitable disk to format as the main install _target_ for the OS.</mark> It defaults to largest non-cidata / non-livecd disk. If this is too spooky, you may specify exact partitions or volumes in the user-data file.

{{< notice tip >}}
Notice after the "autoinstall:" key in user-data, all of the sub-values are indented as childern of autoinstall. While this is a cloud-init configuration, there is a top-level configuration for the live-server and an indented, limited, cloud-init configuration for the target host used by autoinstall.
{{< /notice >}}

### Bare metal vs. Raspberry Pi

My homelab consists of Intel NUCs and Raspberry Pis. I was hoping to share the same process for both installs but realized I needed to approach them slightly different. This is because Raspberry Pi's are traditionally ran off of a USB that already has an OS image installed.

The two step process solution for bare metal is (pictured below):
- Boot a temporary OS to memory
- Remotely provision the target host disk (via cloud-init [#1])
  - The remote provisioning includes generating a new `cloud-init` for the future host disk's first boot (via `cloud-init` [#2]).

> Notice there's multiple "first boots" and layers to our automated install. Understand that `cloud-init` runs once on the live-server (finding the `autoinstall` values) and again on the `target harddrive` first boot.

![diagram depicting cloud-init as a cloud and the boot process from live-server to target hard drive as colored shapes and arrows](/img/overview-components.jpg)

{{< notice info >}}
Pay attention to the underlined components, they are important topics covered in the solution deep-dive. If you're feeling lost, jump to the [solution deep-dive](#solution-deep-dive) for additional context and then come back here.
{{< /notice >}}

However, since the Pi installation is directly on disk, we need to copy the bootable disk image to USB and then modify some of the startup scripts. As a result, the USB (pictured as a hard drive) plugs in and is the primary boot device for the Pi _forever_.

![diagram of booting a hard drive with cloud init, depicted as a cloud, being the only config](/img/pi-chart.jpg)

The key takeaway is, the bare metal solution configures a "meta" `cloud-init` to launch autoinstall (which then generates a second `cloud-init` config for the host) and the method for a Raspberry Pi is using traditional, stand-alone, `cloud-init` without autoinstall because we're editing the primary `cloud-init` boot device.

If you're interested in this alternative approach, only using cloud-init (no autoinstall) by directly imaging a disk, I created a post on how to [automate Rasperry Pi 4 installs of Ubuntu 22.04](/posts/autoinstall-ubuntu-22-on-raspberry-pi-4/).

### Power-state trickery

Since I want to provision servers with no screen or keyboard, I needed to know when to remove the USB. Otherwise, each reboot would relaunch the live OS - causing a continuous install loop.

The solution I came up with is adding in "power off" events at key times.

The first power off is in the user-data's late commands to be executed by the live-server. This gives me indication it's time to remove the USBs because cloud-init/autoinstall has completed the initial provisioning.

The second one is after the target host performs the first boot (set by autoinstall's generated config). Letting me know that it boot successfully and ran my first boot instructions.

> ### What is Ubuntu's autoinstall?
> 
> autoinstall lets you answer all those configuration questions ahead of time with an autoinstall config and lets the installation process run without any interaction.
> 
> The live-server will use autoinstall directives to seed answers to configuration prompts during system install to allow for a “touchless” or non-interactive Ubuntu system install. ([source](https://cloudinit.readthedocs.io/en/latest/topics/modules.html#ubuntu-autoinstall))

{{< notice warning >}}
The most important thing to understand, above everything else:

autoinstall has a configuration _similar to_ cloud-init but they are not the same.

They both are technically cloud-init files, starting with `#cloud-config`, but the key difference is, cloud-init configurations don't have `autoinstall:` as the first argument.

```shell
#cloud-config
autoinstall:
  version: 1
```

This means, not all `cloud-init` [options](https://cloudinit.readthedocs.io/en/latest/topics/examples.html) can be set in `autoinstall` or vice versa. When in doubt, validate the option exists in the [offical refernce doc](https://ubuntu.com/server/docs/install/autoinstall-reference).

To make matters more confusing, the first "thing" to trigger ALL of the automation is cloud-init; reading a cloud-init file. However, cloud-init's first directive is to launch autoinstall which runs the automation controller - subsequently via _a different_, new, cloud-init bootstrap on your target disk.

And your target disk run's a third "first boot" cloud-init once fully provisioned. :sweat_smile:
{{< /notice >}}

> When any system is installed using the server installer, an autoinstall file for repeating the install is created at `/var/log/installer/autoinstall-user-data`.

### autoinstall vs. cloud-init

The biggest gap for me was learning that [autoinstall](https://ubuntu.com/server/docs/install/autoinstall) is _very close_ to cloud-init but not exactly cloud-init. In fact, "The `autoinstall config` is provided via `cloud-init` configuration." The [autoinstall quickstart](https://ubuntu.com/server/docs/install/autoinstall-quickstart) guide leaves a lot to be desired, the biggest problem for me is the use of a VM. It's not a "real world" example, there's no consideration for the complexities to leverage autoinstall with no context.

To make things more confusing, you can specify user-data for autoinstall in your user-data file... This changes where the init happens.

On the first cloud-init boot, when “autoinstall” directives are provided in either #cloud-config user-data or /etc/cloud/cloud.cfg.d cloud-init validates that the minimal autoinstall schema exists and emit a warning if the live-installer is not present.

The live-installer will use autoinstall directives to seed answers to configuration prompts during system install to allow for a “touchless” or non-interactive Ubuntu system install. ([source](https://cloudinit.readthedocs.io/en/latest/topics/modules.html#ubuntu-autoinstall))

## Additional components

Let's get a bit deeper into the weeds.

> ### What makes the live-server boot?
>
> I started to think about what triggered our installation. I know `cloud-init`... but what first runs _that_ - how does it "know"? How can one USB default to finding another. As we know, the boot menu options are only for autoinstall - not `cloud-init`. To answer this, we need to look at how the live-server boots.
> 
> `casper` looks for media containing a `/casper` directory where root filesystems are stored (`cd_amd64/casper/installer.squashfs`). When found, `casper` creates a writable environment to boot in-memory. You can find [examples of people modifying the squashfs](https://discourse.ubuntu.com/t/please-test-autoinstalls-for-20-04/15250/25).

```shell
# ls -lah
total 36K
dr-xr-xr-x 1 root root 2.0K Aug  9 11:48 .
drwx------ 7 root root 4.0K Sep 16 01:42 ..
dr-xr-xr-x 1 root root 2.0K Apr 15 17:08 boot
-r--r--r-- 1 root root 2.0K Aug  9 11:48 boot.catalog
dr-xr-xr-x 1 root root 4.0K Aug  9 11:48 casper
dr-xr-xr-x 1 root root 2.0K Aug  9 11:48 .disk
dr-xr-xr-x 1 root root 2.0K Aug  9 11:48 dists
dr-xr-xr-x 1 root root 2.0K Apr 15 17:08 EFI
dr-xr-xr-x 1 root root 2.0K Aug  9 11:48 install
-r--r--r-- 1 root root  12K Aug  9 11:48 md5sum.txt
dr-xr-xr-x 1 root root 2.0K Aug  9 11:48 pool
lr-xr-xr-x 1 root root    1 Aug  9 11:48 ubuntu -> .
```

Inside casper:

```shell
filesystem.manifest
filesystem.size
initrd
install-sources.yaml
ubuntu-server-minimal.manifest
ubuntu-server-minimal.size
ubuntu-server-minimal.squashfs
ubuntu-server-minimal.squashfs.gpg
ubuntu-server-minimal.ubuntu-server.installer.generic.manifest
ubuntu-server-minimal.ubuntu-server.installer.generic.size
ubuntu-server-minimal.ubuntu-server.installer.generic.squashfs
ubuntu-server-minimal.ubuntu-server.installer.generic.squashfs.gpg
ubuntu-server-minimal.ubuntu-server.installer.manifest
ubuntu-server-minimal.ubuntu-server.installer.size
ubuntu-server-minimal.ubuntu-server.installer.squashfs
ubuntu-server-minimal.ubuntu-server.installer.squashfs.gpg
ubuntu-server-minimal.ubuntu-server.manifest
ubuntu-server-minimal.ubuntu-server.size
ubuntu-server-minimal.ubuntu-server.squashfs
ubuntu-server-minimal.ubuntu-server.squashfs.gpg
vmlinuz
```

>
> `initrd` and `vmlinuz` (a compressed kernel) provide the bootable layer to give "life" to the unsquashed root filesystem. `installer.squashfs` contains the entire Ubuntu Live Server OS, including a `cloud-init` and `systemd` configuration. This is why everything "just works" - `cloud-init` runs on every boot (finding our 'CIDATA' volume for setup).
>
> It's not critical to understand this, but it's cool to understand the context of how the automation works.

I tried to sketch out a different view of how the components interact. It reads from the top to bottom; from boot to provisioned host. Pay attention towards the bottom (`subiquity` & `curtin`) because those are covered in subsequent sections.

![rough sketch of all the components in use to install ubuntu](/img/component-sketch.png#center)

{{< notice info >}}
As of Ubuntu 20.04, a top-level `autoinstall:` key can be provided in `#cloud-config` from user-data to trigger an autoinstall (`subiquity`).
{{< /notice >}}

> ### What is subiquity?
> 
> [Subiquity](https://github.com/canonical/subiquity) is a python client-server application. By default, `subiquity` is installed through snap on the live-server ISO. Subiquity opens up an API [socket](https://github.com/canonical/subiquity/blob/main/subiquity/cmd/tui.py#L117) (`/run/subiquity/socket`) and runs [python-based] controllers to respond to events.
>
> Subiquity is mostly defined / constrained by the curtin config. Once the app is running and the configurations are generated (including a new `cloud-init`), the subiquity controller "only" sits between curtin and the new target host.
([source](https://github.com/canonical/subiquity/blob/main/DESIGN.md#development-process))

#### Subiquity stages

1. Checks for an `autoinstall` config (with a `cloud-init`-like format) and runs any early commands.
1. Waits for all the model objects that feed into the `curtin` config to be configured.
1. Waits for confirmation.
1. Runs `curtin install` (in multiple steps) and waits for that to finish.
1. Waits for the model objects that feed into the `cloud-init` config to be configured.
1. Creates the `cloud-init` config for the first boot of the installed system.
1. If there's a network connection, it downloads and installs security updates.
1. Runs any late commands. ([source](https://github.com/canonical/subiquity/blob/main/DESIGN.md#the-server-state-machine))

It's worth getting in to this level of detail, because you'll occassionally need to debug errors that come from screens that look like:

![subiquity install arguments on a terminal calling curtin install](/img/subiquity-curtin.png)

When I was first debugging my installation errors, I felt like I was running in circles.

> ### What is curtin?
>
> [curtin](https://curtin.readthedocs.io/en/latest/topics/overview.html) is intended to be a bare bones “installer.” Its goal is to take data from a source, and get it onto disk as quick as possible and then boot it.
>
> The key difference from traditional package based installers is that curtin assumes the thing its installing is intelligent and will do the right thing.

{{< notice tip >}}
Search (`CTRL + F`) for the term `curtin` on Ubuntu's official [autoinstall-reference](https://ubuntu.com/server/docs/install/autoinstall-reference) to see the areas managed by curtin such as disk selection ([additonal curtin docs](https://curtin.readthedocs.io/en/latest/topics/config.html)).
{{< /notice >}}

### Summary

A live OS is booted to memory via casper; triggering cloud-init to launch subiquity, a bunch of python controllers, to generate a cloud-init configuration for the new host and to lunch `curtin install` for provisioning the host's new - future - disk.

**Now**, let's begin the actual tutorial! :sweat_smile:

## Create a bootable live-server USB

### Download the latest ISO

Find the latest live-server ISO at the bottom of the 22.04 [releases page](https://releases.ubuntu.com/22.04/).

```shell
sudo su -
export ISO="https://releases.ubuntu.com/22.04/ubuntu-22.04.1-live-server-amd64.iso"
wget $ISO
```

### Disable installer prompts (optional)

> Even if a fully noninteractive autoinstall config is found, the server installer will ask for confirmation before writing to the disks <mark>unless _"autoinstall"_ is present on the kernel command line.</mark> This is to make it harder to accidentally create a USB stick that will reformat a machine it is plugged into at boot. ([source](https://ubuntu.com/server/docs/install/autoinstall))

Since I want the process to be 100% automated, let's update the boot file (`grub.cfg`). It sounds simple but it's harder than it should be.

ISO's have a very strict format and packaging structure that make them notoriously difficult to modify.  To work around this, manually extract the files from the mounted read-only ISO. Then use livefs-editor to rebuild a new ISO.

{{< notice warning >}}
To skip this section and leave the ISO as-is, jump to creating a [bootable USB from live-server](#make-a-bootable-usb-from-iso) and remember to [override the live-server boot menu options](#override-the-live-server-boot-menu-options).
{{< /notice >}}

#### Mount the ISO locally to copy files

Create a directory named `mnt` and unpack the ISO contents locally.

```shell
export ORIG_ISO="ubuntu-22.04.1-live-server-amd64.iso"
mkdir mnt
mount -o loop $ORIG_ISO mnt
```

#### Copy the existing boot file to `/tmp/grub.cfg`

```shell
cp --no-preserve=all mnt/boot/grub/grub.cfg /tmp/grub.cfg
```

Modify `/tmp/grub.cfg` in the first section "Try or Install Ubuntu Server" to include 'autoinstall quiet' after 'linux /casper/vmlinuz.'

```shell
sed -i 's/linux	\/casper\/vmlinuz  ---/linux	\/casper\/vmlinuz autoinstall quiet ---/g' /tmp/grub.cfg
```

> #### What do the 'autoinstall' & 'quiet' parameters do?
> 
> **autoinstall** -- a parameter that `subiquity` checks before destructively modifying disks, if the string is not present, user confirmation is required.
>
> **quiet** -- a linux kernel parameter to disable most log messages. ([source](https://github.com/torvalds/linux/blob/master/Documentation/admin-guide/kernel-parameters.txt#L4536))


{{< notice tip >}}
Instead of `cidata`, you can declare a different file path for the configuration in the linux boot command line. For example, to use `/cdrom/server/`:

```shell
       linux   /casper/vmlinuz autoinstall quiet ds=nocloud\;s=/cdrom/server/ ---
```
{{< /notice >}}


#### Reduce the boot menu timeout

The reduced timeout means that the boot menu prompt is only up for 1 second before moving forward with the 'autoinstall quiet.'
 
```shell
sed -i 's/timeout=30/timeout=1/g' /tmp/grub.cfg
```

Reference file: [example gist](https://gist.githubusercontent.com/jimangel/72a4d140e7fbde1b7e7fd64f286a17e8/raw/52b67667acbbb879b20a8b4e22ef4989fb1f22c5/grub.cfg)

#### Rebuild the modified ISO

After many failed attempts to rebuild the ISO, I found an incredible tool on [this fourm](https://discourse.ubuntu.com/t/a-tool-to-modify-live-server-isos/22195) called livefs-editor.

Looking back, I think [this askubuntu.com answer](https://askubuntu.com/questions/1390827/how-to-make-ubuntu-autoinstall-iso-with-cloud-init-in-ubuntu-21-10/1391309#1391309) would have allowed me to build the ISO using `xorriso` but I didn't grasp the post when I first found it ([similar solution](https://gist.github.com/s3rj1k/55b10cd20f31542046018fcce32f103e) and [full example](https://gist.github.com/s3rj1k/55b10cd20f31542046018fcce32f103e)).

> #### What is livefs-editor?
> 
> [livefs-editor](https://github.com/mwhudson/livefs-editor) is a python CLI tool used to edit an existing live-server ISO. `livefs-edit` takes arguments for instrucitons on how to modify an ISO.

#### Setup livefs-editor

Install dependencies for `livefs-editor` then clone and install using `pip`

```shell
apt install xorriso squashfs-tools python3-debian gpg liblz4-tool python3-pip -y

git clone https://github.com/mwhudson/livefs-editor

cd livefs-editor/

python3 -m pip install .
```

#### Use livefs-edit to create a newly modified ISO

Copy the updated `/tmp/grub.cfg` file over using the `--cp` (copy) argument.

{{< notice note >}}
After writing this article, I noticed there's also a `--autoinstall` argument to combine the user-data and live-server on one usb. I believe it would accept our `user-data` file and automatically update the kernel arguments - but have not tested.
{{< /notice >}}

```shell
# copy command exactly as is, it appends `-modded` to the new filename
export MODDED_ISO="${ORIG_ISO::-4}-modded.iso"
livefs-edit ../$ORIG_ISO ../$MODDED_ISO --cp /tmp/grub.cfg new/iso/boot/grub/grub.cfg
```

{{< notice warning >}}
The `new/iso` path is the [relative path](https://github.com/mwhudson/livefs-editor#directory-structure) `livefs-edit` automatically uses as a destination. **Do not change this.**
{{< /notice >}}

### Copy the bootable ISO to a USB

Plug in the USB and find it with `lsblk`.

```shell
lsblk
```

For example, mine is `sda` (and the underlying `sda1` partition). I know this because the other disk is my OS and the size is close to what I expect. Output:

```shell
NAME                      MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0                       7:0    0  61.9M  1 loop /snap/core20/1405
loop1                       7:1    0    62M  1 loop /snap/core20/1587
loop2                       7:2    0  79.9M  1 loop /snap/lxd/22923
loop3                       7:3    0    47M  1 loop /snap/snapd/16292
loop4                       7:4    0  44.7M  1 loop /snap/snapd/15534
loop5                       7:5    0   1.4G  0 loop /root/livefs-editor/mnt
sda                         8:0    1 114.6G  0 disk 
└─sda1                      8:1    1 114.6G  0 part 
nvme0n1                   259:0    0 465.8G  0 disk 
├─nvme0n1p1               259:1    0     1G  0 part /boot/efi
├─nvme0n1p2               259:2    0     2G  0 part /boot
└─nvme0n1p3               259:3    0 462.7G  0 part 
  └─ubuntu--vg-ubuntu--lv 253:0    0 462.7G  0 lvm  /
```

Copy the ISO to the USB using the `dd` command.

```shell
# ensure the USB is not mounted.
sudo umount /dev/sda /dev/sda1

# NOTE: If you skipped the above steps, consider using the $ORIG_ISO variable instead.
sudo dd bs=4M if=../$MODDED_ISO of=/dev/sda conv=fdatasync status=progress
```

Output:

```shell
351+1 records in
351+1 records out
1474353152 bytes (1.5 GB, 1.4 GiB) copied, 20.6316 s, 71.5 MB/s
```

<!--adsense-->

The hard part of creating the bootable ISO is over. Next, let's create a volume to host our `cloud-init` user-data configuration.

## Create a USB named CIDATA for a cloud-init datasource

{{< notice warning >}}
It's important that the USB is named "CIDATA" and that it's FAT32 formatted. If either of those are not met, the install proceeds but has no custom config.
{{< /notice >}}

First, unplug the ISO from earlier and plug in a new, second, USB.

Format the disk.

```shell
# ensure the NEW USB is not mounted
sudo umount /dev/sda

# format using the FAT32 (`-F 32`) format and name (`-n`) the volume 'CIDATA' (`-I` for ignoring safety checks)
sudo mkfs.vfat -I -F 32 -n 'CIDATA' /dev/sda
```

Validate the label name worked with the following command. The `/dev/disk/by-label/` directory contains all mounted USB volumes by their assocatied names.

```shell
# copied as-is
ls /dev/disk/by-label/
```

Output:

```shell
 CIDATA  'Ubuntu-Server\x2022.04.1\x20LTS\x20amd64'
```

Mount the new USB to the `/tmp/cidata` directory for file creation.

```shell
mkdir /tmp/cidata
sudo mount /dev/sda /tmp/cidata
```

### Create the meta-data file on CIDATA

```shell
cd /tmp/cidata
touch meta-data
```

{{< notice warning >}}
cloud-init doesn't work if the meta-data file is absent. Even an empty file meets the requirement.
{{< /notice >}}

### Create the user-data file on CIDATA

The user-data file is the heart of all of our automation configuration. For starters, we'll use my complete user-data file.

We want to configure the following parameters on every server:

- Install SSH server, so I can login remotely
- Disable password based SSH logins, since I'm copying my SSH keys over
- Randomly generate a hostname
- Display the IP at login prompt, so I can diagnose quickly after plugging in a monitor
- Expand the primary host volume to 100% free disk space
- Disable the root account
- Set timezone to America/Chicago
- Skip upgrading packages, since I'll do it with Ansible afterwards
- Create the `jangel` user
  - Add to sudo group
  - Disable SSH password, since I'm copying my SSH keys
  - Set shell to `/bin/bash` (probably not needed)
  - Add `ssh_authorized_keys:` for my local mac and one of my other servers
  - Allow for passwordless sudo

>  The ‘user-data’ under the autoinstall config applies to the installed system not the installer environment. ([source](https://discourse.ubuntu.com/t/how-to-poweroff-autoinstall-instead-of-reboot/17449/5))

```shell
curl -fsSL https://gist.githubusercontent.com/jimangel/72a4d140e7fbde1b7e7fd64f286a17e8/raw/52b67667acbbb879b20a8b4e22ef4989fb1f22c5/user-data -o user-data
```

When creating a user-data file it's important to understand what parameters are available to you. The official docs have an awesome [example file that shows off most features](https://ubuntu.com/server/docs/install/autoinstall).

> WRITE ABOUT THIS AND HOW IT WORKS: https://askubuntu.com/a/1347830 (subiquity + cloud-init)

My user-data file contents:

{{< notice warning >}}
Cloud-init requires that the `cloud-data` file begins with `#cloud-config` in line 1.
{{< /notice >}}

{{< gist jimangel 72a4d140e7fbde1b7e7fd64f286a17e8 "user-data" >}}

{{< notice note >}}
I have the late-command `shutdown -h now` to shutdown the host after provisioning (to prevent an endless loop).
{{< /notice >}}

## Alternatives to a USB-based CIDATA cloud-init datasource

### Create an ISO volume instead of a USB

If you're interested in trying my solution on VMware, you could create an ISO from the two files instead of the formatted USB with one command: `genisoimage  -output seed.iso -volid cidata -joliet -rock user-data meta-data`. [genisoimage](https://wiki.debian.org/genisoimage) creates a file named `seed.iso` with the volume-id of `cidata` containing the two configuration files - ready for mounting.

### Use a HTTP server as the datasource

To use a HTTP server as a datasource you could host a user-data file at http://192.168.1.100/user-data and an empty meta-data file at http://192.168.1.100/meta-data. To direct cloud-init to use that datasource, enter the following string in your grub boot config (`/boot/grub/grub.cfg`):

```shell
# Source modifed from: https://discourse.ubuntu.com/t/cloud-init-and-the-live-server-installer/14597
menuentry "Try or Install Ubuntu Server" {
       set gfxpayload=keep
       linux   /casper/vmlinuz autoinstall quiet ds=nocloud-net\;s=http://192.168.1.100/ ---
       initrd  /casper/initrd
}
```

> I think it would be cool to test out pubically hosting those files, like a [Netlify](https://www.netlify.com/) static website, [GitHub pages](https://pages.github.com/), or [Cloud Run](https://cloud.google.com/run). You could even have subdomains to split user-data configs like `https://golden-config.example.com/user-data` and `https://just-for-hacks.example.com/user-data`. Just try to be careful about what data is included in the user-data file :stuck_out_tongue_winking_eye:
>
> The official quickstart guide has a [basic http server example](https://ubuntu.com/server/docs/install/autoinstall-quickstart) using python.

## Insert both USBs and boot

Assuming everything is configured properly, we're basically done at this point. But there are a couple things to look out for.

### Select the live-server USB as a boot option (optional)

If your BIOS isn't configured to automatically boot from a USB device, configure the "boot options" menu. The live-server USB drive name might not be obvious, in my case it was `UEFI: USB, Partition 2`.

### Override the live-server boot menu options (optional)

{{< notice warning >}}
This step is optional. Skip this step if you are using a modified ISO.
{{< /notice >}}

Not to be confused with the USB being selected as the media to boot from, we now need to choose how Ubuntu lanches from the USB. If you didn't configure a custom ISO to auto-boot and autoinstall, you'll need to enter a few parameters when prompted to select your Ubuntu boot option.

1. Ensure the "Try or Install Ubuntu Server" option is highlighted using the up or down arrows.
1. Press `e` to edit the grub commands (launches a new screen)
1. Using the arrow keys, insert `autoinstall quiet` in the line that says `linux   /casper/vmlinuz ---` before the dashes resulting in the full line appearing as: `linux   /casper/vmlinuz autoinstall quiet ---`
1. Press `F10` to save and exit

> If you run into any issues, check out the log fies in `/var/log/installer` or `/var/crash`. Most of the time my issues were formatting or not escaping characters properly in the user-data file.

## Complete! :tada::tada::tada:

The installation takes around 15-30 minutes depeding on your internet speed and use of `cloud-init`. Usually for good measure, once complete, I'll unplug both USBs - to prevent any reinstallation - and reboot the server. This can be done the disruptive way (physical button) or, if you know the IP, SSH in and `sudo reboot`. Test your access with `ssh jangel@[IPADDR]`.

I can boot (and reboot) my bare metal servers into a freshly provisioned machine whenever I want. I'll probably look switching from my NoCloud datasource to some network-based datasource so I can manage less and copy less each time. For now, I have exactly what.

I enjoy keeping `cloud-init` limited to the OS setup and using configuration management tools like Ansible for server config. Howwever, I do think it would be cool to into the possiblities of using `cloud-init` to create specific "flavors" of fully configured bootable Ubuntu hosts. For example, I could have a `cloud-init` setup for Kubernetes control plane hosts and another setup for Kubernetes workers. I need to think about it more, but it might be possible to have things boot and auto-join the cluster.

Autoinstall has a key called [early-commands](https://ubuntu.com/server/docs/install/autoinstall-reference#early-commands) that allows commands to be ran against the default autoinstall config file located at `/autoinstall.yaml`. For example, I could have the string "HOSTNAME" replaced by an `early-commands:` of `- sed -i -e "s/HOSTNAME/$(openssl rand -hex 3)/" /autoinstall.yaml` instead of overriding the default with `late-commands:`. I also found a cool example of creating an additional cloud-config, outside of autoinstall, on the target host:

```shell
#cloud-config
autoinstall:
  ...
  late-commands:
    - |
      cat <<EOF > /target/etc/cloud/cloud.cfg.d/80_my.cfg
      hostname: $(openssl rand -hex 3)
      manage_etc_hosts: true
      preserve_hostname: false
      EOF
```

Alternately, I could create pre-configured images based on the [Ubunutu OS pre-reqs](https://cloud.google.com/anthos/clusters/docs/bare-metal/latest/installing/configure-os/ubuntu) for rapid build/rebuilding tests of [Anthos clusters on bare metal](https://cloud.google.com/anthos/clusters/docs/bare-metal/latest/concepts/about-bare-metal).

Let me know if you do anything cool with this info!

## Bonus: Real-life homelab demo

This post covered _a lot_ of ground and I think that leads to things appearing more complex than they are.

Sometimes, these topics can get noisey and you might wonder what the actual process looks like. Here's what my server automation process - looks like managing 7 servers - today.

![usbs plugged in a hub](/img/autoinstall-usb.png)

### Modifying the liver-server ISO

```shell
wget "https://releases.ubuntu.com/22.04/ubuntu-22.04.1-live-server-amd64.iso"
export ORIG_ISO="ubuntu-22.04.1-live-server-amd64.iso"
rm -rf mnt && mkdir mnt && mount -o loop $ORIG_ISO mnt
cp --no-preserve=all mnt/boot/grub/grub.cfg /tmp/grub.cfg
sed -i 's/linux	\/casper\/vmlinuz  ---/linux	\/casper\/vmlinuz autoinstall quiet ---/g' /tmp/grub.cfg
sed -i 's/timeout=30/timeout=1/g' /tmp/grub.cfg
export MODDED_ISO="${ORIG_ISO::-4}-modded.iso"
livefs-edit $ORIG_ISO $MODDED_ISO --cp /tmp/grub.cfg new/iso/boot/grub/grub.cfg
```

### Copying the ISO to all usbs

The following command looks long and ugly because of the disk names. I felt like using the `/by-id/` was safer.

```shell
# copy USBs (takes 30 seconds) - tip: `ls /dev/disk/by-id/ | grep '0:0$'` for names - used read/write speed to guess BS
dd bs=1M if=$MODDED_ISO iflag=fullblock | tee >(dd bs=1M iflag=fullblock oflag=direct of=/dev/disk/by-id/usb-Samsung_Flash_Drive_FIT_0329022060003582-0:0) >(dd bs=1M iflag=fullblock oflag=direct of=/dev/disk/by-id/usb-Samsung_Flash_Drive_FIT_0361222060003162-0:0) >(dd bs=1M iflag=fullblock oflag=direct of=/dev/disk/by-id/usb-Samsung_Flash_Drive_FIT_0373422060007246-0:0) >(dd bs=1M iflag=fullblock oflag=direct of=/dev/disk/by-id/usb-Samsung_Flash_Drive_FIT_0374622050002220-0:0) >(dd bs=1M iflag=fullblock oflag=direct of=/dev/disk/by-id/usb-Samsung_Flash_Drive_FIT_0374722050002291-0:0) >(dd bs=1M iflag=fullblock oflag=direct of=/dev/disk/by-id/usb-Samsung_Flash_Drive_FIT_0374822050002193-0:0) | dd bs=1M iflag=fullblock oflag=direct of=/dev/disk/by-id/usb-Samsung_Flash_Drive_FIT_0375022050002144-0:0
```

### Copying the cloud-init data to all usbs

After swapping with the other set of USBs.

```shell
# change USBs for user-data & create cidata drives, create one-by-one:
mkdir /tmp/cidata
for i in /dev/sda /dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf /dev/sdg; do \
partprobe $i && umount $i || \
mkfs.vfat -I -F 32 -n 'CIDATA' $i && \
mount $i /tmp/cidata && touch /tmp/cidata/meta-data && \
curl -fsSL https://gist.githubusercontent.com/jimangel/72a4d140e7fbde1b7e7fd64f286a17e8/raw/52b67667acbbb879b20a8b4e22ef4989fb1f22c5/user-data \
-o /tmp/cidata/user-data && umount /tmp/cidata; done
```

Now, I'm ready to wipe / rebuild each host, it should take me less than 20 minutes to do all 7. Once complete, I have some house keeping on my local laptop / ansible.

- Boot from the USB (wait for cloud-init to trigger autoinstall)
- After it shuts off, unplug the usb
- Boot again (wait for the second cloud-init to trigger host first-run provisioning)
- After it shuts off, provisioning is complete
- Boot for the last time to start

### Clean up my local machine's known_hosts

```shell
for i in $(echo "192.168.65.11 192.168.80.38 192.168.126.60 192.168.74.115 192.168.68.65 192.168.93.163 192.168.127.21"); do ssh-keygen -R $i && ssh-keyscan -H $i >> ~/.ssh/known_hosts; done
```

### Check ansible connections

> The ansible commands are ran in a directory that already contained an inventory file that provided my username (`ansible_user: jangel`) and other SSH parameters (`ansible_connection: ssh`).

```shell
ansible all -m ping
```

#### Confirm install success based on stats

```shell
# OS version
ansible all -m shell -a 'cat /etc/os-release | grep -i version='

# creation date
ansible all -m shell -a "stat / | awk '/Birth: /{print $2}'"

# bonus stats
ansible all -m setup -a 'filter=ansible_distribution,ansible_distribution_version,ansible_memfree_mb,ansible_memtotal_mb,ansible_processor_cores*,ansible_architecture' 2>/dev/null
```

From here I'll run upgrade scripts etc.. cheers!