---
title: "How to autoinstall Ubuntu 22.04 LTS on a Rasperry Pi 4"
description: "Automate the complete provisioning of Ubuntu 22.04 LTS on a Rasperry Pi 4 using cloud-init"
summary: "Automate the complete install of Ubuntu 22.04 LTS on a Rasperry Pi 4 using cloud-init"
date: 2022-09-13
tags:
- walkthrough
- automation
- homelab
- ubuntu
- cloud-init
keywords:
- ubuntu 22.04 lts
- rasperry pi
- rasperry pi 4
- usb cloud-init ubuntu
- how to automate Ubuntu 22.04
- walkthrough
- automation
- homelab
- ubuntu
- cloud-init
- cloud-init userdata
- modify an iso
- edit ubuntu live iso
- how to modify ubuntu iso
- 22.04 lts
showToc: false
TocOpen: false
draft: true
hidemeta: false
comments: true
ShowWordCount: false
cover:
    image: /img/raspberry-pi-feature.png # image path/url
    alt: "Ubuntu Raspberry Pi Imager for 22.04" # alt text

slug: "autoinstall-ubuntu-22-on-raspberry-pi-4"  # make your URL pretty!
---

## TL;DR

Use a `cloud-init` configuration file to launch `autoinstall` on a Ubuntu 22.04 Raspberry Pi image. The end result is a fully configured Rasberry Pi server with all my settings like trusted SSH public keys.

The details about how `cloud-init` and `autoinstall` work can be found on the original blog post ("[How to automate bare metal Ubuntu 22.04 LTS installs via USB](/posts/automate-ubuntu-22-04-lts-bare-metal)"). The reason this requires a seperate post is because we have to unpack the OS image and modify the configration directly on the installation media vs. using a live-server to handle the installation (in memory).

## High-level steps

1. flash img
1. enable ssh
1. transfer key(s)
1. ansible ...

# Why Ubuntu?

I think there's a strong argument to stick with Rasbian / PiOS. It's purpose built to run on the Pi, by the creators of the Pi, and tested specfically for capabilities on various Pi's. Unless you have a valid reason not to, I think PiOS is a better starting point.

I'm choosing Ubuntu because I also have a rack of Intel NUCs. By using the same OS, I can share Ansible playbooks and approach their lifecycles similarly.

Depending on where my homelab ends up, I might end up forking my Ansible playbooks and going back to Raspian.

# Flash

Instrucitons here: https://ubuntu.com/tutorials/how-to-install-ubuntu-on-your-raspberry-pi#1-overview

![](https://i.imgur.com/chiK5T5.png)

For this, I used a mac and imaged following the instructions.

## New method (because the above is slow and GUI-y):

go to the [releases](https://cdimage.ubuntu.com/releases/22.04/release/) (scroll down or CTRL+F "preinstalled-server-arm64+raspi"). Copy the URL for the file named "ubuntu-[ VERSION ]-preinstalled-server-arm64+raspi.img.xz" with the description, "Preinstalled server image for Raspberry Pi Generic (64-bit ARM) computers (preinstalled SD Card image)"


```shell
# example: Download https://cdimage.ubuntu.com/releases/22.04/release/ubuntu-22.04-preinstalled-server-arm64+raspi.img.xz

# uncompress the file (open in the GUI or use the CLI)

# mount image to OS
# a volume called "system-boot" appears

# make file edits and save (rasberry image is writable)
cd /Volumes/system-boot/

cat << 'EOF' | sudo tee user-data
#cloud-config

# This is the user-data configuration file for cloud-init. By default this sets
# up an initial user called "ubuntu" with password "ubuntu", which must be
# changed at first login. However, many additional actions can be initiated on
# first boot from this file. The cloud-init documentation has more details:
#
# https://cloudinit.readthedocs.io/

# Disable password authentication with the SSH daemon
ssh_pwauth: false

## On first boot, use ssh-import-id to give the specific users SSH access to
## the default user
# ssh_import_id:
#- lp:my_launchpad_username
#- gh:my_github_username

## Add users and groups to the system, and import keys with the ssh-import-id
## utility
#groups:
#- robot: [robot]
#- robotics: [robot]
#- pi

users:
  - name: jangel
    groups: [sudo]
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDTK3YYoKho9SvTejt9430NRwu5ZQpwtAQGBbX8piLvLfsrJzzXxWljTvmC63VMAbCy3ii/Z4yReeCt4h7JiFNf+4ggfUmG+SN+6WvRlfKdaQBXKqojNNxVDg/M73CYF/CYjifJYombA1WIFYoZwMSnd4pzuS7pSiMFKEYTznmImgqa40uZfK6My98KTFpbuebeRvF1u/2Q2ISEYRQmHbm79NAj2WPoI73vNDtkKOPn8NU13xQgC4EMlk/Yu0p36THYlMl30iJePhFgNNBTxXBZL41+nn6W9wgfwo78VDNSa0A2Cambad/lYEerSWevsPATU7bf2an7RsDJhvCx58hI4BMl0KQ3/R0MT2OSGU+GHjBzL/T9UHIxN1FynzmwYpI96MEmEqETjG2DzboO93Oo5EkuX/e6wo/ptQ1g9Qarmk66E0shYpTtwQn2mz0Lhv8PD9C/CbZl9QqcQ43yah1MD9PH/OaCj32FpBqDNJp+NuyYbjBDhG5TgGza4yrgww8= jimangel@Jims-MacBook-Pro.local"
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC0b+HAT0Q9az/AlHEk/Xfuci8NGYRriFHOXErxU4saJ jangel@ubuntu-host-5b6bab"

## Update apt database and upgrade packages on first boot
# package_update: true
# package_upgrade: true

## Install additional packages on first boot
#packages:
#- avahi-daemon
#- rng-tools
#- python3-gpiozero
#- [python3-serial, 3.5-1]

## Run arbitrary commands at rc.local like time
runcmd:
 - printf "ubuntu-host-$(openssl rand -hex 3)" > /etc/hostname
 - printf "Ubuntu 22.04 LTS \nIP - $(hostname -I)\n" > /etc/issue

# Capture all subprocess output into a logfile
# Useful for troubleshooting cloud-init issues
output: {all: '| tee -a /var/log/cloud-init-output.log'}
EOF
```

Write updated img to SD card via Mac OSX gui.

Insert the sd reader and identify the card with `diskutil list`. Output similar to:

```shell
/dev/disk5 (internal, physical):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:     FDisk_partition_scheme                        *511.9 GB   disk5
   1:             Windows_FAT_32 ⁨system-boot⁩             268.4 MB   disk5s1
   2:                      Linux ⁨⁩                        3.7 GB     disk5s2
                    (free space)                         507.9 GB   -
```

I matched the disk based on size and the process of elimination. Now that I know the SD card is /dev/disk5 (top left path), unmount and copy the image.

```shell
# unmount the sd card (replacing "/dev/disk2" with correct path)
diskutil unmountDisk /dev/disk5

sudo dd bs=1m if=$HOME/Downloads/ubuntu-22.04-preinstalled-server-arm64+raspi.img of=/dev/disk5
```
************************************
************************************
************************************
CURRENT WINNER (ABOVE) ************************************
************************************
************************************
************************************
************************************

## try 1 (default reader)

```shell
5:28 start

> 3755+0 records in
> 3755+0 records out
> 3937402880 bytes transferred in 571.155304 secs (6893752 bytes/sec)
> GASP: 9.5 minutes

To safely remove the SD card and make it ready for use, type the following command `diskutil eject /dev/disk5`

> Note: the SD card was 128GB, on a 32GB card, the process took ~6.6m
```

## try 2 (using cat)

Yes, cat ubuntu.iso >/dev/usb is exactly equivalent. There is no magic in dd, it's just a tool to copy its input to its output.

MAybe try that?

```
diskutil unmountDisk /dev/disk5
sudo su -
time cat /Users/jimangel/Downloads/ubuntu-22.04-preinstalled-server-arm64+raspi.img > /dev/disk5
```

No real change

```
time cat /Users/jimangel/Downloads/ubuntu-22.04-preinstalled-server-arm64+raspi.img > /dev/disk5

real	9m36.993s
user	0m0.223s
sys	0m8.023s

9.4m
```

## try 3 (increasing dd blocksize / bs to 4MB)

Test disk write speed with a fake write (to create a better block size)

```
diskutil unmountDisk /dev/disk5

# CAREFUL with this command
diskutil eraseDisk FAT32 TEST /dev/disk5

# It should auto-mount as /Volumes/TEST

# test write speed
sudo time dd if=/dev/zero bs=1024k of=/Volumes/TEST/tstfile count=1024 2>&1 | awk '/sec/ {print $1 / $5 / 1048576, "MB/sec" }'

# 37.4241 MB/sec
```

```
diskutil unmountDisk /dev/disk5
sudo time dd if=/Users/jimangel/Downloads/ubuntu-22.04-preinstalled-server-arm64+raspi.img of=/dev/disk5 bs=4M status=progress
```

Lol, it got longer (9.6m)

## try 3.5 (use PV directly for cloning)

```
# brew install pv (progress bar, can be left out)
# revisiting this later yet: after some conversation with the author of pv, I discovered that you can avoid the speed penalty by taking dd out of the equation entirely:

# the "new" disk is disk4 based on `diskutil list`
sudo su -
diskutil unmountDisk /dev/disk5
diskutil unmountDisk /dev/disk4
time /opt/homebrew/bin/pv < /dev/disk5 > /dev/disk4

# looks like around 12 MB/s vs 5ish seen with dd.
```

This failed due to the drives not all being the same size. I think it would be in my best interest to use the same size drives + cloning vs. dd (more to come...)

## try 4 (using the USB 3.0 reader)

> Check SD card speeds

## try 5 (copy from one sd to another using dd (compare to pv))

Using the sd reader - is it faster to clone vs. copy img?

<!--adsense-->

## Tips

Using the "pi-imager" with one of the generic SD adapaters seemed to TAKE FOREVER. I think it's very worth spending the $10 on a USB 3.0 adapater of your choice and using the CLI.

## Other
Open the Terminal app
Get disk list with the diskutil list
To create the disk image: dd if=/dev/DISK of=image.dd bs=512
To write the disk image: dd if=image.dd of=/dev/DISK

https://www.jeffgeerling.com/blog/2021/taking-control-pi-poe-hats-overly-aggressive-fan

# Questions I had

> Where is config.txt in Ubunutu Pi?

```
# callout config.txt
Optionally, edit the config.txt to reduce the speed of the POE hat fans. If you do this step and you don't have a POE hat, I don't think it impacts anything? ...

vi /system-boot/config.txt

# add the following (from: https://www.jeffgeerling.com/blog/2021/taking-control-pi-poe-hats-overly-aggressive-fan)
```

> Where is cmdline.txt in Ubunutu Pi?
same spot different name