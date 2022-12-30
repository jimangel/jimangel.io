---
title: "How to automate Ubuntu 22.04 LTS on a Raspberry Pi 4"
description: "Automate the complete provisioning of Ubuntu 22.04 LTS on a Raspberry Pi 4 using cloud-init"
summary: "Automate the complete install of Ubuntu 22.04 LTS on a Raspberry Pi 4 using cloud-init"
date: 2022-09-19
tags:
- walkthrough
- automation
- homelab
- ubuntu
- cloud-init
keywords:
- ubuntu 22.04 lts
- raspberry pi
- raspberry pi 4
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
draft: false
hidemeta: false
comments: true
ShowWordCount: false
cover:
    image: "img/raspberry-pi-feature.jpg" # image path/url
    alt: "Ubuntu Raspberry Pi Image for 22.04" # alt text

slug: "autoinstall-ubuntu-22-on-raspberry-pi-4"  # make your URL pretty!
---

I discovered that my `cloud-init` solution for my bare metal servers needed to be modified for the Raspberry Pi.

My original post goes to great lengths to explain all the components involved and even includes a section explaining what the [differences are between that approach and this one](/posts/automate-ubuntu-22-04-lts-bare-metal/#bare-metal-vs-raspberry-pi).

## TL;DR

Use a `cloud-init` configuration file on a Ubuntu 22.04 Raspberry Pi image. The end result is a Raspberry Pi host that boots to your exact specification and settings – like trusted SSH public keys.

If you feel lost, check out the longer post for [cloud-init on bare metal](/posts/automate-ubuntu-22-04-lts-bare-metal/).

![Raspberry Pi motherboard with purple cable in a rack of four](/img/pi-cloud-init.jpg)

## Prerequisites

- USB with 4GB+ storage
- An Ubuntu 22.04 LTS host with USB ports

The commands I use are tested on a "real" Ubuntu host.

{{< notice note >}}
I have set up fixed IPs for each of my Pi's. They always rebuild with the same IP and I don't have to update my inventory. Ensure you have a way to learn the IP address or enable SSH.
{{< /notice >}}

## Get the latest image

Go to the 22.04 [releases](https://cdimage.ubuntu.com/releases/22.04/release/) page and scroll down (or `CTRL`+`F`  for `preinstalled-server-arm64+raspi`).

```shell
# set the URL for the file named `ubuntu-VERSION-preinstalled-server-arm64+raspi.img.xz`
export IMG="https://cdimage.ubuntu.com/releases/22.04/release/ubuntu-22.04.1-preinstalled-server-arm64+raspi.img.xz"
wget $IMG
```

## Write the OS image to a USB

Take the downloaded compressed image and write it to a USB. See [my other post](/posts/automate-ubuntu-22-04-lts-bare-metal/#copy-the-bootable-iso-to-a-usb) about identifying which USB device is which.

I use `xz`, a general-purpose data compression tool, to extract the image while writing it to the USB.

```shell
export FILE="ubuntu-22.04.1-preinstalled-server-arm64+raspi.img.xz"

# REPLACE WITH YOUR USB (`lsblk`)
export USB="/dev/sda"
# `-d` decompress `<` redirect $FILE contents to expand `|` sending the output to `dd` to copy directly to $USB
xz -d < $FILE - | dd bs=100M of=$USB
```

{{< notice tip >}}
Using the "pi-imager" with one of the generic SD adapters seemed to TAKE FOREVER. I think it's very worth spending the $10 on a USB 3.0 adapter of your choice and using the CLI.
{{< /notice >}}

The USB is now considered a "bootable" OS disk. Before doing so, we want to change a couple of files to "pre-seed" the installation answers.

When we copied the image, partitions were created, and we're looking for the `system-boot` partition. If you've set up Raspberry Pi's before, this is similar to `boot`.

```shell
# make a directory to mount the USB to
mkdir /tmp/pi-disk
```

## Mount the USB to configure cloud-init

For me, `sda1` appears to be the first partition copied from the image, it's the same as mounting `system-boot`.

```
mount /dev/sda1 /tmp/pi-disk
```

## Create the user-data file

By default, there's a full example user-data file in the root directory (`cat /tmp/pi-disk/user-data`).

When creating a user-data file it's important to understand what parameters are available to you. The official `cloud-init` docs have an awesome [set of complete examples](https://cloudinit.readthedocs.io/en/latest/topics/examples.html).


#### Sample user-data file

```shell
cat <<'EOF' > user-data
#cloud-config
groups:
  - cloud-users

# create user with the name/password of ubuntu/ubuntu
users:
  - name: ubuntu
    primary_group: ubuntu
    groups: users
    lock_passwd: false
    # "ubuntu" - created with `docker run -it --rm alpine mkpasswd --method=SHA-512`
    passwd: "$5$r3Kl6AKBqjA78VCX$4.Vuc56PR2faX3vLuqBxHxF796qiLhxuS4MacXtTt5C"
EOF
```

Feel free to use the above for testing. 

#### My exact user-data file

Warning, the following file installs my public keys as authorized users on the target device. **If you use my exact config, you won't be able to log in**.

{{< gist jimangel 72a4d140e7fbde1b7e7fd64f286a17e8 "pi-user-data" >}}

```shell
# automatically overwrites the default file
curl -fsSL https://gist.githubusercontent.com/jimangel/72a4d140e7fbde1b7e7fd64f286a17e8/raw/b58dbff7a30bf8451019cfcf456392da4afab166/pi-user-data -o /tmp/pi-disk/user-data

# unmount the disk if done
umount /tmp/pi-disk/
```



## Boot the Raspberry Pi

If things go according to plan, boot, and you can SSH in.

{{< notice note >}}
If you're watching the progress on a screen, you might see a login before cloud-init is finished – give it a few minutes before attempting to access.
{{< /notice >}}

## Tips

I ran into a couple of configuration questions that I had to look up.

### Where is config.txt on Ubuntu Pi?

`config.txt`, used like a BIOS to configure Pis, is located in the `/system-boot/` folder partition.

### Where is cmdline.txt on Ubuntu Pi?

`cmdline.txt` a plain text file used by the Raspberry Pi to pass parameters to the kernel. It is also located in the `/system-boot/` folder partition.