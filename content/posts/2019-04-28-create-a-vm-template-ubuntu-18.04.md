---
title: "Create a VM Template for Ubuntu 18.04 LTS"
subtitle: "Script the Boring Stuff"
summary: "Walk through creating a Ubuntu template on VMware"
date: 2019-04-28
lastmod: 2019-04-28
featured: false
draft: false
authors:
- jimangel
tags:
- ubuntu
- vmware
- images
categories: []
keywords:
- virt sysprep ubuntu
- ubuntu
- vmware
- images

cover:
  image: /img/ubuntu-18-04-template-featured.jpg

slug: "create-a-vm-template-for-ubuntu-18-04-lts"
---

## Why?
Creating a template in vSphere allows for rapid deployment of VMs. You can add or update custom software and build the perfect server to consistently deploy in your environment.

I aim to create a VM, add VMware tools, and strip out any unique data.

---

## Before We Start
* Download the ISO of [Ubuntu 18.04 LTS](https://releases.ubuntu.com/18.04/ubuntu-18.04.6-live-server-amd64.iso)
* Upload the Ubuntu 18.04 ISO to a vSphere datastore.
* Create a VM using that ISO (including full post-install / OS setup)
* SSH into the newly created VM

---

## Customize The Template

I've included the manual steps below that are needed to clean up your template. If you want to take the fast track, you can just run [this script](https://github.com/jimangel/ubuntu-18.04-scripts/blob/master/prepare-ubuntu-18.04-template.sh) and skip to the next section.

### Update All Packages

```bash
# use caution when using -y (automatic "yes")
sudo apt -y update
sudo apt -y upgrade
```

### Install VMware Tools

```bash
# most likely is already installed
sudo apt -y install open-vm-tools
```

### Strip Out Unique Data

```bash
# stop services for cleanup
sudo service rsyslog stop

# clear audit logs
if [ -f /var/log/wtmp ]; then
    truncate -s0 /var/log/wtmp
fi
if [ -f /var/log/lastlog ]; then
    truncate -s0 /var/log/lastlog
fi

# cleanup /tmp directories
rm -rf /tmp/*
rm -rf /var/tmp/*

# cleanup current ssh keys
rm -f /etc/ssh/ssh_host_*

# add check for ssh keys on reboot...regenerate if necessary
cat << 'EOL' | sudo tee /etc/rc.local
#!/bin/sh -e
#
# rc.local
#
# dynamically create hostname (optional)
#if hostname | grep localhost; then
#    hostnamectl set-hostname "$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')"
#fi
#
# check for SSH keys and create if not present
test -f /etc/ssh/ssh_host_dsa_key || dpkg-reconfigure openssh-server
exit 0
EOL

# make sure the script is executable
chmod +x /etc/rc.local

# reset hostname
# prevent cloud-init from preserving the original hostname
sed -i 's/preserve_hostname: false/preserve_hostname: true/g' /etc/cloud/cloud.cfg
truncate -s0 /etc/hostname
hostnamectl set-hostname localhost

# cleanup apt
apt clean

# set DHCP to use mac - keying off of a default line is a little bit of a hack to insert the replacement text, but we need the replaced text inserted under the active nic settings
# also look in /etc/netplan for other config files
sed -i 's/optional: true/dhcp-identifier: mac/g' /etc/netplan/50-cloud-init.yaml

# cleans out all of the cloud-init cache/logs - this is mainly cleaning out networking info
sudo cloud-init clean --logs

# cleanup shell history
cat /dev/null > ~/.bash_history && history -c
history -w

# shutdown
shutdown -h now
```

### Optional Configuration For `kubeadm`

```bash
# disable swap
sudo swapoff --all
sudo sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

# If you want to create a hostname dynamically, uncomment the below from /etc/rc.local:
# dynamically create hostname (optional)
#if hostname | grep localhost; then
#   hostnamectl set-hostname "$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')"
#fi
```

### Add As A Template To vSphere

At this point, we've customized the VM, and should shut it off.

{{< notice warning >}}
Make sure to disconnect the CDROM and the NIC before adding as the image as a template  
Right Click VM > Edit Settings > deselect...
{{< /notice >}}

* Right Click VM > convert to template

## Conclusion

That's it! I plan on using these VM templates for my Kubernetes clusters.
