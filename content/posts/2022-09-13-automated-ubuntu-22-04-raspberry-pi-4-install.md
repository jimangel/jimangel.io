---
title: "How to automate Ubuntu 22.04 LTS on a Rasperry Pi 4"
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

This post is a direct result of trying to automate my homelab. I discovered the process I used for my bare metal servers was slightly different than Raspberry Pi.

You can read the full details, and additional context of components, LINK


in my original post "[How to automate bare metal Ubuntu 22.04 LTS installs via USB](/posts/automate-ubuntu-22-04-lts-bare-metal)"

## TL;DR

Use a `cloud-init` configuration file on a Ubuntu 22.04 Raspberry Pi image. The end result is a fully configured Rasberry Pi server with all my settings like trusted SSH public keys.

There's an overly detailed post about what `cloud-init` and `autoinstall` are on my original blog post ("[How to automate bare metal Ubuntu 22.04 LTS installs via USB](/posts/automate-ubuntu-22-04-lts-bare-metal)").

The biggest difference is, we aren't going to use Ubuntu's `autoinstall:` key in the `cloud-init` user-data configuration. We use the top-level `cloud-init` configuration to provision the host.

![diagram of booting a hard drive with cloud init, depicted as a cloud, being the only config](/img/pi-chart.jpg)

To put it another way, for a Reasperry Pi we are creating the actual hard drive that runs the OS and must configure `cloud-init` as such.

![meme of caveman spongebog saying no power off only power on](/img/only-power-on.jpg)

> Confused on what approach to use? When you are able to directly write to the host's real hard drive (such as a Raspberry Pi's USB) use "raw" cloud-init and disk images. If you don't have access to the intended host target's hard drive, it makes sense to use the "autoinstall" cloud-init method with live-boot (such as physical servers).

{{< notice warning >}}
The biggest drawback to this approach is, you're editing the actual hard drive. There's not a concept of reinstalling with a reboot. The reinstall must be re-ran (performing the exact same steps below) on each USB.
{{< /notice >}}

## Prerequisites

- USB with 4GB+ storage
- An Ubuntu 22.04 LTS host with USB ports

The commands I use are tested on a "real" Ubuntu host.

## Get the latest image

Go to the 22.04 [release](https://cdimage.ubuntu.com/releases/22.04/release/) page and scroll down (or CTRL+F "preinstalled-server-arm64+raspi"). Copy the URL for the file named "ubuntu-[ VERSION ]-preinstalled-server-arm64+raspi.img.xz"

{{< notice tip >}}
Using the "pi-imager" with one of the generic SD adapaters seemed to TAKE FOREVER. I think it's very worth spending the $10 on a USB 3.0 adapater of your choice and using the CLI.
{{< /notice >}}

```shell
export IMG="https://cdimage.ubuntu.com/releases/22.04/release/ubuntu-22.04.1-preinstalled-server-arm64+raspi.img.xz"
wget $IMG
```

## Write the OS image to a USB

Take the downloaded compressed image and write it to a USB. See my other post about identifying which USB device is which.

I use xz (installed by default) to extract the image while writing it to the USB.

```shell
export FILE="ubuntu-22.04.1-preinstalled-server-arm64+raspi.img.xz"

# REPLACE WITH YOUR USB (`lsblk`)
export USB="/dev/sda"
xz -d < $FILE - | dd bs=100M of=$USB
```

> `xz` is a general-purpose data compression tool and the `-d` flag stands for decompress. We redirect the file contents (`$FILE -`) into `xz` to expand the image. The resulting output (piped) uses `dd`, a disk copying utility, to copy the images to the `$USB`.

## Mount the USB to manually configure

The USB is now considered a "bootable" OS disk. Before doing so, we want to change a couple files to "pre-seed" the installation answers.

When we copied the image, partion's were created and we're looking for the `system-boot` partition. If you've setup Raspberry Pi's before, this is similar to `boot`.

```shell
mkdir /tmp/pi-disk
# sda1 is the first partition copied from the image, it's the same as mounting `system-boot`
mount /dev/sda1 /tmp/pi-disk
```

## Create cloud-init configuration

By default, there's a full example user-data file in the root directory (`cat /tmp/pi-disk/user-data`).

{{< notice note >}}
I have setup fixed IPs for each of my Pi's. Meaning they always rebuild with the same IP and I don't have to update my inventory. Ensure you have a way to learn the IP address or enable SSH.
{{< /notice >}}

```shell
# automatically overwrites the default file
curl -fsSL https://gist.githubusercontent.com/jimangel/72a4d140e7fbde1b7e7fd64f286a17e8/raw/b58dbff7a30bf8451019cfcf456392da4afab166/pi-user-data -o /tmp/pi-disk/user-data

# unmount the disk if done
umount /tmp/pi-disk/
```

{{< gist jimangel 72a4d140e7fbde1b7e7fd64f286a17e8 "pi-user-data" >}}

# breakdown each section or add comments in.

(more cloud-init [configuration examples](https://cloudinit.readthedocs.io/en/latest/topics/examples.html))

<!--adsense-->

## Boot the Rasbperry Pi

If things go according to plan, things boot and you can SSH.

Note, if you're watching the progress on a screen, you might see a login before cloud-init is finished - give it a few minutes before attempting to access.

## Tips

I ran into a couple configuration issues and had to lookup

### Where is config.txt in Ubunutu Pi?

`config.txt`, used like a BIOS to configure Pis, is located in the `/system-boot/` folder partition.

### Where is cmdline.txt in Ubunutu Pi?

`cmdline.txt` a plain text file used by the Raspberry Pi to pass parameters to the kernel. It is also located in the `/system-boot/` folder partition.

### New install clean up

After re-imaging all the servers, run the following commands on your localhost for SSH.

```shell
# replace with your IPs
for i in $(echo "192.168.91.96 192.168.92.46 192.168.90.218 192.168.121.214 192.168.105.237"); do ssh-keygen -R $i && ssh-keyscan -H $i >> ~/.ssh/known_hosts; done
```

Note: mihht be able to use aitoinstall wiyth more devidese

