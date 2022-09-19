---
title: "Automated VCSA 6.7 Install using CLI"
description: "Quickly deploy vCenter to an ESXi host"
subtitle: "So easy it will leave you feeling warm and fuzzy"
summary: "Quickly deploy vCenter to an ESXi host"
date: 2019-06-26
lastmod: 2019-06-26
#publishDate: You only need to specify this option if you wish to set date in the future but publish the page now.
featured: false
draft: false
authors:
- jimangel
tags:
- vmware
- walkthrough
categories: []
keywords:
- install vcsa on esxi
- vmware
- walkthrough
- vcenter iso install

cover:
  image: /img/automated-vcenter-featured.jpg

slug: "automated-vcsa-vcenter-install"
---

This post is an extension of my [ESXi setup](/posts/scripted-esxi-6-7-install-to-usb), usually what I do after the host is up.

We will use a file to automate 100% of the configuration.

Our goal is to make this process easy, boring, and repeatable.

## Prerequisites
* ESXi 6.7 U2 Host
* Ubuntu or similar PC

## Get the vCenter ISO

Covered in an [earlier post](/posts/scripted-esxi-6-7-install-to-usb#get-vmware-isos). Get the ISO any way you'd like.


{{< notice note >}}
This demo uses: VMware-VCSA-all-6.7.0-13010631.iso
{{< /notice >}}

Put the ISO in your `~/Downloads` folder if you plan on following my exact commands


## Create the config file

First, mount the VCSA ISO locally and create a custom JSON config.

### Mount the ISO

```bash
mkdir /vcsa
sudo mount -o loop ~/Downloads/VMware-VCSA-all-6.7.0-13010631.iso /vcsa
```

We will be using vCenter (VCSA) with an embedded PSC controller. If you're wondering what PCS is, you can learn more about it [here](https://emadyounis.com/vcenter-server-architecture-part-1-the-basics/).

The ISO will contain a few templates for us to copy and modify. You can find VCSA and PCS' other options [here](https://docs.vmware.com/en/VMware-vSphere/6.5/com.vmware.vsphere.install.doc/GUID-A1777A0B-9FD6-4DE7-AC37-7B3181D13032.html). 

### Copy and edit the JSON config

```bash
cp /vcsa/vcsa-cli-installer/templates/install/embedded_vCSA_on_ESXi.json /tmp/config.json

# ! OPTIONAL !
# If you want to start with my exact config:
curl -L https://gist.github.com/jimangel/8d5869a4be139e631a310e2bfe4d8b81/raw > /tmp/config.json
```

### Validate the template without installing
```bash
/vcsa/vcsa-cli-installer/lin64/vcsa-deploy install \
--accept-eula \
--verify-template-only \
/tmp/config.json
```

{{< notice note >}}
If you plan on using FQDN for the vCenter hostname, make sure the address resolves without fail. (ex: `nslookup -nosearch -nodefname _FQDN_or_IP_address_`)
{{< /notice >}}

## Install VCSA to your ESXi host

### Run the installation
```bash
/vcsa/vcsa-cli-installer/lin64/vcsa-deploy install \
--accept-eula \
--acknowledge-ceip \
--terse \
--no-ssl-certificate-verification \
/tmp/config.json
```

If you run into any issues, you can replace `--terse` with `--verbose`.

<!--adsense-->

## Validate vCenter install

Navigate to the vCenter **FQDN_or_IP_address** in your browser and log in. Don't forget to use the proper `domain.local` suffix:

```bash
# The root user for VCSA is `administrator`
User: administrator@hobbyhacks.io  
Password: R00tp@ssw0rd!
```

## Conclusion

You're now ready to deploy some VMs! The biggest reason I set up VCSA is to leverage https://github.com/vmware/govmomi, a goLang API interface to vSphere.

I plan on revisiting this post and adding in LetsEncrypt SSL certificates and VMware licenses in the `config.json`.

Sources:

- https://docs.vmware.com/en/VMware-vSphere/6.7/vsphere-vcenter-server-67-installation-guide.pdf
- https://www.ivobeerens.nl/2018/08/20/vcenter-server-appliance-vcsa-automated-unattended-deployment/
- https://xenappblog.com/2018/automatically-deploy-vmware-vcsa/