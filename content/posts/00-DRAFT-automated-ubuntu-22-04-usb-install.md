---
title: "Automated bare metal Ubuntu 22.04 installs via USB"
description: "Never touch a keyboard again while provisioning bare metal servers."
summary: "Auto-provision bare metal Ubuntu servers from 2 USB sticks"
date: 2022-08-24T11:51:56-05:00
tags:
- walkthrough
- automation
- homelab
- ubuntu
- cloud-init
showToc: false
TocOpen: false
draft: true
hidemeta: false
comments: true
ShowWordCount: false
cover:
    image: /img/ubuntu-usb-install-22-04-cover.png # image path/url
    alt: "Ubuntu desktop for 22.04" # alt text
---

this post outlines using xyz resulting xyz

using this posrt as foiundation, i did the same for pi:

- Automated install of Ubuntu 22.04 LTS on RasperryPi using cloud-init

## TL;DR

Automatically provision Ubuntu 22.04 LTS servers by performing the following steps:

* Create bootable Ubuntu live server USB from ISO
* Create another USB named "CIDATA" containing 2 cloud-init files
* Plug in both USBs -> boot to a new provisioned OS

{{< notice tip >}}
I'm chasing my dream of booting up a server without a keyboard and resulting with a newly provisioned machine.

The bulk of this post is adjusting a grub file on the live ISO to automatically trigger the autoinstaller. Making it truely **zero touch.**

An alternative would be to use a keyboard at boot time to modify the grub file. This would be the **single touch** and the rest would be automated. If you like this option better, skip to the [cloud-init section](#cloud-init)!
{{< /notice >}}

If you want to skip the additional context, [click here](#prerequisites) to jump to the prerequisites.

## My dream

I like to wipe and reinstall my homelab servers semi-frequently. I didn’t find the pain bad enough to automate, so I just clicked through the defaults each time I needed.

This approach goes against my loosly held beliefs, that, “anything done more than 3 times should be automated” and “servers should be treated like cattle, not pets.”

> I want to treat bare metal servers like cloud servers without having to increasing my homelab tech-debt (like maintaining custom [DHCP](https://en.wikipedia.org/wiki/Dynamic_Host_Configuration_Protocol) / [TFTP](https://en.wikipedia.org/wiki/Trivial_File_Transfer_Protocol) / [PXE boot](https://en.wikipedia.org/wiki/Preboot_Execution_Environment) infrastructure).

I just want to hack on clusters and "reset" them with low effort. The biggest perk is the ability pre-seed SSH public keys. Allowing for further config automation via tools like Ansible.

To acomplish this, we **only** need to understand *[autoinstall](https://ubuntu.com/server/docs/install/autoinstall)*, er, *[cloud-init](https://cloudinit.readthedocs.io/en/latest/)*, I mean; *[subiquity](https://github.com/canonical/subiquity)* - but I think that's, uh, really *[curtin](https://curtin.readthedocs.io/en/latest/topics/config.html)*? This topic gets really confusing. Let's try to untangle some of it...

## Key Understandings

UNWIND KEY DEFINITIONS, KEY UNDERTSANDINGS, (move any details to the walk trhough), show image

This whole topic is confusing with spotty documentation. I hope this doc meets your need, but if not, at least I can try to leave you better off...

cloud-init > DS

boot > ISO

USB > boot able 

UEFI vs. not

maybe kill this section or move to the end. Or trim to "need to understand at sysdmin 101 - me at AU?"

cutain, "Curtin is intended to be a bare bones “installer”. Its goal is to take data from a source, and get it onto disk as quick as possible and then boot it. The key difference from traditional package based installers is that curtin assumes the thing its installing is intelligent and will do the right thing." (mainly) > 'The key difference from traditional package based installers is that curtin assumes the thing its installing is intelligent and will do the right thing.'

* Install Environment boot
* Early Commands
* Partitioning
* Network Discovery and Setup
* Extraction of sources
* Hook for installed OS to customize itself
* Final Commands

At the moment, curtin doesn’t address how the system that it is running on is booted. It could be booted from a live-cd or from a pxe boot environment. It could even be booted off a disk in the system (although installation to that disk would probably break things).

Curtin’s assumption is that a fairly rich Linux (Ubuntu) environment is booted.

The installer kicks off automatically and finds the CIDATA volume for the configuration. The process chooses that best disk for the install and completely wipes the drive and all contents. The process adds my SSH keys to the hosts, so I disable password based login for SSH. Lastly, the SSH key for Ansible is added for server provisioning.

I try to keep my automated OS installs to purely *the OS* (to avoid compatability issues installing or using in the future). It's worth mentioning, cloud-init can be used to do MASSIVE configuration of your server and the options should be explored if they fit your use case.

My goal is to quickly bootstrap a server and then let Ansible manage the config. I should be able to complete this without the need to ever SSH into a server or use a monitor / keyboard.

As far as I can tell, autoinstall wraps some (not all) of cloud-init's functionality, so some things that might work for cloud-init do NOT work for autoinstall, even though they are the same? ...

FIX ^^


Overview via pic:

![](https://i.imgur.com/9dbVpKz.png#center)

## Prerequisites

{{< notice warning >}}
An existing Ubuntu install / CLI is **required**
{{< /notice >}}

I tried so hard to avoid this chicken-and-egg issue, but having a single OS/shell requirement allows for more reliable docs.

Worst case scenario, configure a server manually, setup the USBs and then use them the automate reformat.

{{< notice tip >}}
I recently found these USB 3.0 sticks that have 2 ends (USB-A & USB-C) for the same on-chip data. This is awesome as I exchange this drive between machines for creating, editing, or launching installs. (INSERT LINK HERE)

Also, if limited on front facing USBs, I found that using an adapater helps. I plug both USBs and a keyboard dongle in the same adapater. (INSERT LINK HERE)
{{< /notice >}}

## Create bootable Ubuntu live server USB

The reason we can't unpack / repack the ISO easily has a lot to do with the ISO format limitations when it comes to modifying data. Which makes sense considering it would be even more challenge to modify a "real" CD.

As a result, we get the ISO, unpack it for the latest file, and use a tool `livefs-edit` to inject the file. The ending result is a modified, bootable, Ubuntu ISO.

### Get the latest live server ISO

We have to use the live server ISO because our plan is to boot the live OS from the USB stick (in memory) and provision the host from the live server. As far as I know, other Ubuntu ISOs aren't capible of live booting off a USB.

Scroll to the bottom on the release page to get links to the latest ISOs: https://releases.ubuntu.com/22.04/

Ensure we run the following commands with a root user or leverage `sudo`.

```
sudo su -
export ISO="https://releases.ubuntu.com/22.04/ubuntu-22.04.1-live-server-amd64.iso"
wget $ISO
```

### (Optional) Modify the GRUB boot menu file

When the live server ISO is booted, the first prompt is a menu to select what type of boot should be performed. For example, one option is for launching the live OS in memory and another is to install the OS on the system.

We want the bootable ISO to know we are providing it a configuration and it should automatically boot and install.

This configuration step is more complex than it seemed initially. Mainly due to the ISO standard and standards around bootable media. There's a very specific format that is required to maintain ISO integrity. I spent the most of my time finding the best / easiest tool for the job. At somepoint, I would love to containerize this process.

If this step is skipped, there's a pain free way to add the configuration at boot (covered below).

To ensure we're using the latest `grub.cfg` file, let's copy the exact one from the image. To acomplish this, create a directory named `mnt` and unpack the ISO contents locally.

```
export ORIG_ISO="ubuntu-22.04.1-live-server-amd64.iso"
mkdir mnt
mount -o loop $ORIG_ISO mnt
```

The output similar to:

```
mount: /root/mnt: WARNING: source write-protected, mounted read-only.
```

Copy the existing boot file to `/tmp/grub.cfg`. Use `--no-preserve` so the file inherits your user's permissions.

```
cp --no-preserve=all mnt/boot/grub/grub.cfg /tmp/grub.cfg
```

Open the `/tmp/grub.cfg` file with your favorite editor and modify the first section *"Try or Install Ubuntu Server"* to include `autoinstall quiet` after `linux /casper/vmlinuz` and optionally reduce the timeout (on the top line) to 1 second. The reduced timeout means the prompt is only up for 1 second before moving forward with the autoinstall. Alternately run the following commands to make the changes.

```
sed -i 's/timeout=30/timeout=1/g' /tmp/grub.cfg
sed -i 's/linux	\/casper\/vmlinuz  ---/linux	\/casper\/vmlinuz autoinstall quiet ---/g' /tmp/grub.cfg
```

The resulting file should look similar to:

```
set timeout=1

loadfont unicode

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "Try or Install Ubuntu Server" {
        set gfxpayload=keep
        linux   /casper/vmlinuz autoinstall quiet ---
        initrd  /casper/initrd
}
grub_platform
if [ "$grub_platform" = "efi" ]; then
menuentry 'Boot from next volume' {
        exit 1
}
menuentry 'UEFI Firmware Settings' {
        fwsetup
}
else
menuentry 'Test memory' {
        linux16 /boot/memtest86+.bin
}
fi
```

### Repack the ISO with your modified grub file

I don't want to get into the weeds on ISO standards, but please trust me, it's complicated. One thing I kept running into was applications crashing when trying to rewrite the ISO because they tried to maintain everything in memory. I believe there's challenges or limitations of how the data in handled.

After many failed attempts, I found an AWESOME tool on [this fourm](https://discourse.ubuntu.com/t/a-tool-to-modify-live-server-isos/22195) called [livefs-editor](https://github.com/mwhudson/livefs-editor). It is a Python3 utitlity that has defined ISO operations that allow changes to be performed in an ISO compliant way.

Install dependancies for livefs-editor.

```
apt install xorriso squashfs-tools python3-debian gpg liblz4-tool python3-pip -y
```

Clone and install livefs-editor using pip.

```
git clone https://github.com/mwhudson/livefs-editor
cd livefs-editor/
python3 -m pip install .
```

Copy the updated `/tmp/grub.cfg` file over using the `livefs-edit` command.

```
# Usage: livefs-edit $source.iso $dest.iso [actions]
export MODDED_ISO="${ORIG_ISO::-4}-modded.iso"
livefs-edit ../$ORIG_ISO ../$MODDED_ISO --cp /tmp/grub.cfg new/iso/boot/grub/grub.cfg
```

{{< notice warning >}}
The "new/iso" path is the relative path `livefs-edit` automatically uses as a destination. Do not change this.
{{< /notice >}}

## Make a bootable USB from ISO

Plug in the USB stick for the ISO (min size 4GB). Find the USB with `lsblk`.

```
lsblk
```

For example, my USB is `sda` (and the underlying `sda1` partition). I know this because the other disk is my OS and the size is close to what I expect. Output looks similar to:

```
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

Ensure the USB is not mounted.

```
# !! CAREFUL HERE !!
# add other mount points as needed
sudo umount /dev/sda /dev/sda1
```

Copy the ISO to the USB using the `dd` command.

```
# NOTE: If you skipped the above steps, consider using the $ORIG_ISO variable instead.
sudo dd bs=4M if=../$MODDED_ISO of=/dev/sda conv=fdatasync status=progress
```

Output looks similar to:

```
351+1 records in
351+1 records out
1474353152 bytes (1.5 GB, 1.4 GiB) copied, 20.6316 s, 71.5 MB/s
```

As a sanity check, I sometimes look at the GB size copared to the original ISO size for rough idea that things worked as planned.

## Create a FAT32 USB named “CIDATA”

ISO's are exact images of disks. When we used `dd` to copy the Ubuntu ISO to disk, it creates a mirror image of the intended state. This state includes the desired partition format. The `CIDATA` USB is a little more tricky as we're going to create a mounted media that matches the exact specs that cloud-init scans for by default (FAT32 volume with the name `CIDATA`)

{{< notice warning >}}
It's important that the USB is named "CIDATA" and that it's FAT32 formatted. If either of those are not met, the install proceeds but has no custom config.
{{< /notice >}}

First, unplug the ISO from earlier and plug in the data USB.

The section above calculates how to get the disk information using `lsblk`. In our case, the USB was mounted again under `sda`. Format the disk:

Ensure the NEW USB is not mounted.

```
# !! CAREFUL HERE !!
# add other mount points as needed
sudo umount /dev/sda
```

Use the FAT32 format (`-F 32`) and name (`-n`) the volume `CIDATA` (`-I` for ignoring safety checks)

```
sudo mkfs.vfat -I -F 32 -n 'CIDATA' /dev/sda
```

Validate the named label with `ls /dev/disk/by-label/` (copied exactly as-is). This directory contains all mounted USB volumes and their assocatied names. The output should look simiar to:

```
 CIDATA  'Ubuntu-Server\x2022.04.1\x20LTS\x20amd64'
```

Mount the newly formamted USB to the `/tmp/cidata` directory for file creation.

```
mkdir /tmp/cidata
sudo mount /dev/sda /tmp/cidata
```

## Create cloud-init files

### Create the `meta-data` file

The meta-data file, traditionally, is used as inputs / variables for cloud-data. In our case, our cloud-data is generic and we don't care to leverage meta-data. However, we still need a file present for `cloud-init` to use the data.

```
cd /tmp/cidata
touch meta-data
```

{{< notice warning >}}
Without this file, `cloud-init` will not work. Do not skip this step.
{{< /notice >}}

Traditionally the meta-data file is used by cloud providers to dynamically provision machine details. Think of it like an API for random machine configs. However, at my scale (small), I don't need to parameratize my machines. The one area where this might be cool would be for hostnames, but I generate a random one and Ansible updates it later.

### Create the `user-data` file

This file is "where the magic happens." I'll cover what each section does below, but for now let's copy it to the USB. The following can be copy & pasted as one huge command. Once you have a working user-data file it becomes easier to tune.

```
cat << 'EOF' | sudo tee user-data
#cloud-config
autoinstall:
  version: 1

  ssh:
    install-server: true
    # option "allow-pw" defaults to `true` if authorized_keys is empty, `false` otherwise.
    allow-pw: false

  # "[late-commands] are run in the installer environment with the installed system mounted at /target."
  late-commands:
    # randomly generate the hostname & show the IP at boot
    - echo ubuntu-host-$(openssl rand -hex 3) > /target/etc/hostname
    # dump the IP out on reboot / login screen
    - echo "Ubuntu 22.04 LTS \nIP - $(hostname -I)\n" > /target/etc/issue
    # storage was a pain in the ass and merged multiple things, I just want a 100% use of the fs. I don't think this should work, but it does. I'm guessing subiquity mounts the LV's at somepoint. (alternative option if this breaks: https://gist.github.com/anedward01/b68e00bb2dcfa4f1335cd4590cbc8484#file-user-data-L97-L199)
    - lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
    - resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv

  # The following section replaces the requirements for an "identity section" (ref: https://ubuntu.com/server/docs/install/autoinstall-reference#user-data)
  user-data:
    disable_root: true
    timezone: America/Chicago
    package_upgrade: true
    users:
      - name: jangel
        primary_group: users
        groups: sudo
        lock_passwd: true
        # password is "changeme" - created with `mkpasswd --method=SHA-512`
        passwd: "$6$ol5eZ78uIUEOPngX$OeCr5WbZrFodopbG/eJHkKt.c3BbNFGxXhwzYqQzM7r6TkQVFsL5g6FolJ80gBxyrvqw7495QoSwUP63SymC30"
        shell: /bin/bash
        # use cat ~/.ssh/id_rsa.pub or generate to get your public key
        ssh_authorized_keys:
          - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDTK3YYoKho9SvTejt9430NRwu5ZQpwtAQGBbX8piLvLfsrJzzXxWljTvmC63VMAbCy3ii/Z4yReeCt4h7JiFNf+4ggfUmG+SN+6WvRlfKdaQBXKqojNNxVDg/M73CYF/CYjifJYombA1WIFYoZwMSnd4pzuS7pSiMFKEYTznmImgqa40uZfK6My98KTFpbuebeRvF1u/2Q2ISEYRQmHbm79NAj2WPoI73vNDtkKOPn8NU13xQgC4EMlk/Yu0p36THYlMl30iJePhFgNNBTxXBZL41+nn6W9wgfwo78VDNSa0A2Cambad/lYEerSWevsPATU7bf2an7RsDJhvCx58hI4BMl0KQ3/R0MT2OSGU+GHjBzL/T9UHIxN1FynzmwYpI96MEmEqETjG2DzboO93Oo5EkuX/e6wo/ptQ1g9Qarmk66E0shYpTtwQn2mz0Lhv8PD9C/CbZl9QqcQ43yah1MD9PH/OaCj32FpBqDNJp+NuyYbjBDhG5TgGza4yrgww8= jimangel@Jims-MacBook-Pro.local"
          - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7ljLsqYsf/ESyBLUvqyRKo3UZJh/zWHifTjxrEcMcBtGNiu5HMa9oAP2B03iBAu5NGLUXIFDibykq2IeSADrbM/7zzi9bcAMSH6HICRhRzyoxhZ8lMRiH4u3eL0RJLtbH6vQIptJvOrnJgrG85tt5mIfSn1+u9qfCaWTZzEOqNLY1QaRNWuO08gAevrXKHaChw3Li7su262eB4jNhge/+LFulDLoReiUYTgzoVicf+Lrih/hy8TqHw+AHnNsT+t4Wn9z5fS8fNK3mh+1OJtVGC7nqJQg+C9U09XbQTuTQZk32SYqUYSvR0JBpwFL3N1KI0wKJlguAziOQ/1gvrG6NuJpueE8aT7/px8erBdbjyyOGqzFEDkqxMH8skzLnn0wwmw+HrcG/l9WPcQWgaDFZzIgKN/LxRuJOplA1QQHjeqwrgu6JF0iQX2zjBnawwQ9BOn+/KcdH6bxtX+WShrl7Wa1uS1zsE2d7Pw2rOQVNbAN2X9DTM9rZTMggd5XzXYVyuXctub+gtIDYSe2CSU37d3Fq316ihXTxwreGpdkbdEGIqrPLzUA0AIyxTMskB3BPfxn/B55WF1OHkLIP3/7954/M22YJepXBnKZmkz7ZDF9aqP9UbMlb80vlbbDSIjCvpVNuT5VlLBNU9/WxUFRVM3TSK1HNkrZ7O6OIrzEZkQ== jangel@inwin-6x12-32gb-4650-1"
        sudo: ALL=(ALL) NOPASSWD:ALL
EOF
```

### Config breakdown

The autoinstall version is default (1).

SSH is enabled and password login is disabled.

```
  ssh:
    install-server: true
    allow-pw: false
```

`late-commands` are run in the installer environment with the installed system mounted at /target.

```
  late-commands:
    # randomly generate the hostname & show the IP at boot
    - echo ubuntu-host-$(openssl rand -hex 3) > /target/etc/hostname
    # dump the IP out on reboot / login screen
    - echo "Ubuntu 22.04 LTS \nIP - $(hostname -I)\n" > /target/etc/issue
    # storage was a pain in the ass and merged multiple things, I just want a 100% use of the fs. I don't think this should work, but it does. I'm guessing subiquity mounts the LV's at somepoint. (alternative option if this breaks: https://gist.github.com/anedward01/b68e00bb2dcfa4f1335cd4590cbc8484#file-user-data-L97-L199)
    - lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
    - resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv
```

User identity is created, root user is disabled, and my known public keys are shared. Sudo allows access without password for users (me) in the sudo group.

```
  user-data:
    disable_root: true
    timezone: America/Chicago
    package_upgrade: true
    users:
      - name: jangel
        primary_group: users
        groups: sudo
        lock_passwd: true
        # password is "changeme" - created with `mkpasswd --method=SHA-512`
        passwd: "$6$ol5eZ78uIUEOPngX$OeCr5WbZrFodopbG/eJHkKt.c3BbNFGxXhwzYqQzM7r6TkQVFsL5g6FolJ80gBxyrvqw7495QoSwUP63SymC30"
        shell: /bin/bash
        # use cat ~/.ssh/id_rsa.pub or generate to get your public key
        ssh_authorized_keys:
          - "ssh-rsa ..."
          - "ssh-rsa ..."
        sudo: ALL=(ALL) NOPASSWD:ALL
```

### Back to the setup

{{< notice tip >}}
Once we have crafted the CIDATA USB / files, future edits can be done on any computer that can read a FAT32 USB (almost all of them). Once I completed this setup, I modified the CIDATA USB on my Mac with no issues.

Quick edits are great for adding / updating SSH keys etc.

This also comes in handy if you did want to automate zero-touch installs but wanted to update each run with a new user-data for things like hostnames. Understand that this is exactly what the `meta-data` file is for, but also understand that you're a single person not a cloud provider.
{{< /notice >}}

Validate the required files are present and things look good with `ls`, output should look similar to:

```
meta-data  user-data
```

Check that the data in user-data is groovy:

```
cat user-data
```

Output should not look mangled in anyway.

{{< notice warning >}}
Cloud-init requires that the `cloud-data` file begins with `#cloud-config` in line 1.
{{< /notice >}}

### Change out of the mounted directory and unmount the USB

If you're in the directory (/tmp/cidata), you can't unmount it. Let's change to the `/` directory.

```
cd /
sudo umount /tmp/cidata
```

## Insert both USBs and power on your server

In a perfect word, you do nothing and you walk up to find a fresh install of ubuntu. Unfortunately there's a few things keeping us away from that.

### Choose bootable USB in BIOS menu 

When you power on your server you need to select the live server USB as a boot option. To get to the menu, press the function key required to select the USB. On my Intel NUC the funciton key to access the boot options is `F10` (`F11` on my ASRock). Please note that the USB drive name might not be obvious, in my case it was `UEFI: USB, Partition 2`.

{{< notice tip >}}
I take my dream one step further by configuring my BIOS to auto-boot from USB. I used `F2` on my NUC to launch the BIOS settings and I modified hte boot order to prioritize my USB ports. (F2 > Boot (section) > Boot Priority > [check box] Boot USB Devices First > Save and Exit [`F10`])

This is potentially dangerous if I boot while the magical USBs are inserted or boot the wrong USB. Considering I don't care if that happens, let's do it!

In the future, I can plug in these USBs, reboot, and have a fresh install.
{{< /notice >}}

### Override Ubuntu grub options (manual method)

{{< notice note >}}
Skip this step if you are using a modified ISO, as it jumps into action 1 second after the USB is selected to boot.
{{< /notice >}}

Not to be confused with the USB being selected as the media to boot from, we now need to choose how Ubuntu lanches from the USB. If you didn't configure a custom ISO to auto-boot and autoinstall, you'll need to enter a few parameters when prompted to select your Ubuntu boot option.

1. Ensure the "Try or Install Ubuntu Server" option is highlighted using the up or down arrows.
1. Press `e` to edit the grub commands (launches a new screen)
1. Using the arrow keys, insert `autoinstall quiet` in the line that says `linux   /casper/vmlinuz ---` before the dashes resulting in the full line appearing as: `linux   /casper/vmlinuz autoinstall quiet ---`
1. Press `F10` to save and exit (launches the autoinstaller)

### After low-touch install is complete

The install takes around 15-30 minutes depeding on your internet speed and use of cloud-init. Usually for good measure, once complete, I'll unplug both USBs to prevent any reinstallation and reboot the server. This can be done the disruptive way (physical button) or, if you know the IP, you can SSH in and modify.

Part of my user-data updates the login prompt to display the IP (at time of creation). This way, if you have a monitor, you're a reboot away from seeing the IP; without ever logging in.

{{< notice tip >}}
With DHCP reservations in place, my machine always has the correct IP and my SSH key.

Again, following my dream, I also configured DHCP reservations for each of my machines. Setting this up is out of scope for this guide but should be possible to search.
{{< /notice >}}

For the final test, can I access the machines with no changes to my Ansible inventory:

```

```

## Real life

I created 6 sets of USB sticks so I could reformat multiple computers at the same time. I plug them all in and watch the last one to complete (+ some buffer for the USB 2.0 installers). I think in a perfect world they would be identical USB sticks so I could cut my time closer.

Without watching the format process, I don't always know when it rebooted or not and I can't manually boot it without forcing it to go into an install loop (with my auto-trigger).

Here are the steps for me (after creating my media):

1) Plug in USBs > power on (manually)
1) [...wait...]
1) Unplug > reboot (manually)
1) Clean up local SSH keys
    ```
    for i in $(echo "192.168.65.11 192.168.80.38 192.168.126.60 192.168.74.115 192.168.68.65 192.168.93.163 192.168.127.21"); do ssh-keygen -R $i && ssh-keyscan -H $i >> ~/.ssh/known_hosts; done
    ```
1) Check ansible connection
    ```
    ansible all -m ping
    ```
1) Confirm install based on stats
    ```
    # OS version
    ansible all -m shell -a 'cat /etc/os-release | grep -i version='

    # Creation date
    ansible all -m shell -a "stat / | awk '/Birth: /{print $2}'"

    # Bonus stats
    ansible all -m setup -a 'filter=ansible_distribution,ansible_distribution_version,ansible_memfree_mb,ansible_memtotal_mb,ansible_processor_cores*,ansible_architecture' 2>/dev/null
    ```
1) Run OS updates (apps and distro) on all hosts
    ```
    ansible-playbook update-apt-and-distro.yml
    ```
1) Create a software LB for Kubernetes
    ```
    ansible-playbook envoy/install-envoy.yaml
    ```
1) Install kubernetes
    ```
    # installs a new kubernetes cluster across 6 nodes
    ansible-playbook cluster.yml
    ```

The ansible commands are ran in a directory that already contained my inventory (IPs and labels) and an ansible.cfg configuration file that passed my username and other SSH parameters. As a result, I do a lot less hacking on hardware to wipe and restore my homelab. I also get to expand my learnings without fear of making an irreverable change.

## Wrap-up

This was a lot of work, but now I can boot (and reboot) my bare metal servers into a freshly provisioned machine whenever I want. I created multiple copies of the USB sticks and provision multiple hosts at once.

![](/img/ubuntu-usb-install-22-04-USB-rack.jpg)

I do want to acknoweldge there's a way to consolidate the USBs to one, but I felt like that committed me to do modifying the ISO contents every single time I wanted to rebuild my servers. If I'm in a rush, or if my method stops working, I can use the manual grub modification method for automating my installs (and this whole process becomes easier).

With everything completed, future updates should be:

1) create a new live-iso
2) (re)boot

The biggest challenge with this setup is understanding all the moving parts and testing. Testing isn't hard, it's just time consuming. I wish there was a way to lint / validate the cloud-init and ISO configurations without waiting for everything to go through.

Other opitons (pxe boot) (iso virtual whatever)

Future releases can use the same cidata (read the release nodes)

Servers can be completely wiped and rebuilt with low effort

Might look at creating a meta data based install for more automation of the config? idk...

Since we're modifying the ISO, we potentially _could_ jam the CIDATA on the ISO and reduce the amount of USBs. I would rather have the flexibility of seperate USBs, as you saw earlier how big of a pain it is to edit an ISO. Lastly, by not combing the process, I can skip the first step and jump strait into using my CIDATA for booting a new server.

# TODO:
- I should probably try `curtin in-target --target=/target -- lvextend ...`
- backup my own working data and add a note for my config tweaks.

While not required, here's a quick "ssh key purge" script:

for i in $(echo "192.168.65.11 192.168.80.38 192.168.126.60 192.168.74.115 192.168.68.65 192.168.93.163 192.168.127.21"); do ssh-keygen -R $i; done

sudo $HOME/.ssh/known_hosts

# -R removes assicaited hosts
ssh-keygen -R $i