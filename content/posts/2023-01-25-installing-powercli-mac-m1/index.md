---
# not too long or too short (think G-search)
title: "How to install and use VMware's PowerCLI on a M1 Mac"
date: 2023-01-25
# description is usually what's used in a google snippet
# informs and interests users with a short, relevant summary of what a particular page is about.
# They are like a pitch that convince the user that the page is exactly what they're looking for.
description: "A step-by-step walkthrough using PowerCLI to customize ESXi installer ISOs"
summary: "VMware's PowerCLI tool now supports mac and Linux in version 13. I'll walk through how to configure and use PowerCLI on a MacBook Pro"
tags:
- vmware
- homelab
- walkthrough
- powershell
keywords:
- PowerCLI
- M1
- M2
- Apple silicon
- arm
- PowerShell
- brew
- VMware ESXi
- ISO creation
- python3.7
- macbook pro
- VMware
- ESXi 7.0 U3
- VCSA
- homelab
- VMware PowerCLI
- custom VMware ISO

showToc: true
TocOpen: false

# !! DON'T FORGET: https://medium.com/p/import
# !! DON'T FORGET: https://medium.com/p/import
draft: false
# !! DON'T FORGET: https://medium.com/p/import
# !! DON'T FORGET: https://medium.com/p/import

cover:
    image: "img/vmware-powercli-featured.jpg"
    alt: "building that look like boxes stacked together like an abstract cityscape" # alt text
# check config.toml for some of the default options / toggles

# contain keywords relevant to the page's topic, and contain no spaces, underscores or other characters. You should avoid the use of parameters when possible, as they make URLs less inviting for users to click or share. Google's suggestions for URL structure specify using hyphens or dashes (-) rather than underscores (_). Unlike underscores, Google treats hyphens as separators between words in a URL.
slug: "vmware-powercli-install-on-mac"  # make your URL pretty!

---

VMware PowerCLI contains modules of cmdlets based on Microsoft PowerShell for automating vSphere. VMware PowerCLI provides a PowerShell interface to the VMware product APIs.

With PowerCLI you could:
- Add custom networking drivers to an ESXi ISO
- Manage a fleet of Virtual Machines with PowerShell scripts
- Write a custom health check script that prunes snapshots

The possibilities are endless, and now they can be ran on any platform. After reading this article, you'll be able to run PowerCLI on a mac with an Apple silicon processor.

## Why?

PowerCLI, before version 13 (Released Nov 2022), was only available on Windows. This meant adding [Vmware Flings](https://flings.vmware.com/) to an ESXi ISO required me to switch from my mac to a Windows machine. Today I'll run everything locally on my mac!

I'm using Intel NUCs as VMWare hosts and the specific ones I use don't have networking drivers supported by VMware. There is a VMware Fling (a software package) that includes the non-supported drivers. I need to add networking drivers to the ESXi ISO so my Intel NUC hosts can automatically configure networking (DHCP) at first boot.

## Overview

The docs mention "multi-platform" in the release notes but then don't really discuss how to do it on other platforms. The short summary is, you must install PowerShell and Python 3.7 - first - and then the rest seems to fall together.

1) Install PowerShell 7.0
1) Install Python 3.7
1) Install the PowerCLI module
1) Configure PowerCLI to use Python 3.7
1) Build a custom ISO (test)

There are many ways to install the various requirements. To keep it simple, I'll use `brew` a macOS package manager ([install docs](https://brew.sh/)) and `pyenv`.

{{< notice note >}}
The official documentation has a "compatibility matrix" that includes `.NET Core 3.1` which I don't explicitly install. I'm not sure if it came down as a dependency or if the modules I use don't require it. Either way, if you run into issues, try installing `.NET Core 3.1` first (`brew install --cask dotnet-sdk3-1-400`).
{{< /notice >}}

## Install PowerShell 7.0

```bash
brew install --cask powershell
```

To enter PowerShell, type `pwsh`. Type `exit` to leave. Confirm the PowerShell version with `$Host.Version` or `$PSVersionTable.PSVersion`.

## Install Python 3.7

This was the biggest issue I ran into. `brew` normally does a great job at porting active packages to arm (M1), however, Python 3.7 is not available for arm. Many folks [leverage rosetta and aliases to install x86 versions of software side-by-side](https://stackoverflow.com/a/70327233) with arm versions.

I found an interesting solution that used `pyenv`. `pyenv` lets you easily switch between multiple versions of Python. And most importantly, brew can install `pyenv` for M1/arm macs. Install `pyenv`:

```bash
brew install pyenv
```

Install python 3.7:

```bash
pyenv install 3.7
```

The output contains the directory that the version was installed in, for example, `Installed Python-3.7.16 to /Users/jimangel/.pyenv/versions/3.7.16`. Also note that `pyenv` can be used to switch or install multiple versions (`pyenv versions` and `pyenv local X.X.X` to use that version locally). `pyenv` also installs `pip3.7`. Install the pip packages:

```bash
/Users/jimangel/.pyenv/versions/3.7.16/bin/pip3.7 install six psutil lxml pyopenssl
```

Now you're ready to install the PowerCLI module as if you're on windows!

{{< notice warning >}}
You must restart your terminal session before the newly installed Python is recognized.
{{< /notice >}}

## Install the PowerCLI module

Launch a new PowerShell terminal with: `pwsh`

```powershell
<# This example downloads and installs the newest version of a module, only for the current user. #>
Install-Module VMware.PowerCLI -Scope CurrentUser
```

## Configure PowerCLI to use Python 3.7

`Set-PowerCLIConfiguration` allows for configuring how the PowerCLI module works, depending on your `-Scope` settings can persist per user, session, or all users. Replace my `-PythonPath` with your exact file location, it must be the actual python executable - not a directory.

```powershell
<# Set PythonPath. The "-Scope User" ensures that PythonPath is used for the current user only. #>
Set-PowerCLIConfiguration -PythonPath "/Users/jimangel/.pyenv/versions/3.7.16/bin/python3.7" -Scope User
```

Validate the PowerCLI configuration is set with `Get-PowerCLIConfiguration | select *`

## Build a custom ISO (test)

The entire reason I started this blog post was so I could add [Vmware Flings](https://flings.vmware.com/) to ESXi ISOs on my M1 mac. My homelab consists of Intel NUCs (11th generation) and the onboard NIC driver is _not_ included with ESXi. I looked into many ways to modify ESXi ISOs and I kept consistently coming back to PowerCLI. Before version 13, I used to upload everything to a Windows computer, create the ISO, and copy it all back. Let's now do it all natively on my M1 mac!

If you're following along, you'll need to download:
- `ESXi-7.0U3*-depot.zip` (same location as the downloadable ESXi installer ISO)
- [Community Networking Driver for ESXi](https://flings.vmware.com/community-networking-driver-for-esxi) zip file

We'll import the ESXi, and the Networking driver, depot files to our PowerCli session. Then we'll create a new `imageProfile` using the ESXi depot as the base. Lastly, we'll add the `SoftwarePackage` "net-community" to add the driver.

Navigate to the directory where the two files are copied and run the following commands:

```powershell
<# adds the ESX software "ESXi-7.0U3d-19482537-standard" depot ZIP to the current PowerCLI session #>
Add-EsxSoftwareDepot "/Users/jimangel/Downloads/VMware-ESXi-7.0U3d-19482537-depot.zip"

<# Adds "net-community" driver ZIP file to the current PowerCLI session #>
Add-EsxSoftwareDepot "/Users/jimangel/Downloads/Net-Community-Driver_1.2.7.0-1vmw.700.1.0.15843807_19480755.zip"

<# creates an image profile using the depot ZIP as a base #>
<# the "name" / "vendor" flags are required but can be any string #>
<# ensure the CloneProfile string matches the depot ZIP version numbers (7.0U3d-19482537) #>
New-EsxImageProfile -CloneProfile "ESXi-7.0U3d-19482537-standard" -name "ESXi-7.0U3d-19482537-NUC" -Vendor "vsphere.mydns.dog"

<# add the "net-community" software package to the imageProfile to support the NUC #>
Add-EsxSoftwarePackage -ImageProfile "ESXi-7.0U3d-19482537-NUC" -SoftwarePackage "net-community"
```

Ensure the `-CloneProfile` matches the `SoftwareDepot` version string. Also ensure the `-ImageProfile` patches the `-name` set. Next use `Export-ESXImageProfile` to build the ISO locally on disk. I chose to use my Downloads folder.

```powershell
Export-ESXImageProfile -ImageProfile "ESXi-7.0U3d-19482537-NUC" -ExportToISO -filepath "/Users/jimangel/Downloads/ESXi-7.0U3-MODDED-NUC.iso"
```

Bummer, I received the following error:

```shell
Export-EsxImageProfile: Can not instantiate 'certified' policy: VibSign module missing.
```

It appears that this error can be ignored with `–NoSignatureCheck`. I have a feeling that this might be growing pains with the new multi-platform support. In the future, always run without the workaround to see if it's fixed. For now, let's skip it and see if it works:

```powershell
Export-ESXImageProfile -ImageProfile "ESXi-7.0U3d-19482537-NUC" -ExportToISO -filepath "/Users/jimangel/Downloads/ESXi-7.0U3-MODDED-NUC.iso" -NoSignatureCheck
```

Appears to have worked! 🎉 Let's check the file size on disk:

```bash
PS /Users/jimangel/Downloads> ls -lah | grep MODDED
-rw-r--r--    1 jimangel  staff   396M Jan 26 22:42 ESXi-7.0U3-MODDED-NUC.iso
```

`396M` seems reasonable for an OS ISO. As a final step, let's copy the ISO to a bootable USB.

## Extra Credit: Copying the ISO to a bootable USB

I'm using the `dd`, a unix command to copy files to hardware. If you'd prefer to use a GUI, I have really enjoyed using Balena's Etcher (https://www.balena.io/etcher). As a bonus, Etcher is cross-platform too.

First, find the correct USB on your mac using the terminal. As you'll see, mine is `/dev/disk4`.

```shell
# find the disk label or name (like /dev/sba or /dev/disk2)
diskutil list

# unmount the USB disk
sudo diskutil unmountDisk /dev/disk4

# copy the ISO to the USB
sudo dd bs=10M if=/Users/jimangel/Downloads/ESXi-7.0U3-MODDED-NUC.iso of=/dev/disk4
```

There shouldn't be any magic required to make it "bootable" as the ISO format and how `dd` copies data (directly) to the device should be enough. I have seen some issues with USB formats being more forgiving than others. If the above commands don't work, I highly recomend trying to format the USB and retrying with [etcher](https://www.balena.io/etcher).

## Additional Resources

- [Official PowerCLI user guide](https://developer.vmware.com/docs/15315/powercli-user-s-guide/GUID-2F2AC097-C02C-4F05-81D9-D1D99CB7FED1.html)