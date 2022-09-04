---
title: "Bypassing AT&T's fiber gateway on Unifi Dream Machine Pro using WPA supplicant"
subtitle: "I can't believe there's not a better answer in 2021."
summary: "Step by step instructions for bypassing AT&T"
date: 2021-01-08
lastmod: 2021-01-08
#publishDate: You only need to specify this option if you wish to set date in the future but publish the page now.
featured: false
draft: false
authors:
- jimangel
tags:
- unifi
- ubiquiti
categories: []
# SEO
keywords:
- att login router
- unifi
- ubiquiti
- at&t login to router
- can i replace at&t router with my own
- how to ssh into udm pro
- can i use my own router with att uverse
- what modem does at&t fiber use
- how to reset att router bgw210
- how to reset at&t router bgw210
- can i use my own router with att fiber
- udm pro ssh login
- best router for att fiber
- how to remove at&t fiber box
- at&t optical network terminal
- udm pro podman
- unifi os shell commands
- ssh to udm pro
- can i buy my own router for at&t
- udm pro fiber
- what modem does att fiber use

cover:
  image: /img/bypassing-att-fiber-gateway-featured.jpg

slug: "bypassing-att-fiber-gateway-on-udmp"

---

The fundamental problem is: 

{{< notice info >}}
AT&T does not allow you to remove their residential gateway, even if you'd prefer to use something better.
{{< /notice >}}

You must use AT&T's provided residential gateway, such as an NVG5x9, BGW210, or 5268AC, to authenticate to AT&T's fiber internet service.

Considering that AT&T's gateway handles all inbound and outbound traffic, it can cause problems if you run another router gateway behind it. Some AT&T gateways have a mode called "IP passthrough" to prevent managing traffic twice. IP passthrough allows you to specify a different device to act as the WAN gateway, and the original gateway forwards all traffic to it without interfering. Even with IP passthrough, you're limited by AT&T's gateway NAT table size and you *still* have an extra hop.

{{< notice tip >}}
Even with the NAT limitations, I would recommend using the IP passthrough mode as a first choice to bypass AT&T for most folks due to ease of setup.
{{< /notice >}}

To be honest, I haven't had many issues using IP passthrough mode, but I couldn't resist downsizing my network devices and hacking on some hardware.

I've always been on the fence about "bypassing" AT&T's device because I didn't understand how I could revert if I got stuck. It turns out that the bulk of the work is prep. You can get to the very end and revert everything on the UDM Pro by running the following commands:

```shell
# stop the wpa_supplicant-udmpro container
podman stop wpa_supplicant-udmpro

# delete the copied data and boot script
rm -rf /mnt/data/podman/wpa_supplicant /mnt/data/on_boot.d/10-wpa_supplicant.sh
```

If you want a "clean" reset, download backups, factory reset, and restore.

## How does AT&T Fiber work?

Before getting started, let's understand exactly what the problem is. Below is a traditional NVG589 setup with [802.1X](https://www.securew2.com/solutions/802-1x/) EAP-TLS details.

![](/img/bypassing-att-fiber-gateway-LSniStq.png#center)

The Optical Network Terminal, ONT, converts "light" data (fiber) to electrical signal to pass through ethernet wires in your home. The actual optical network terminal is the white box (top right).

{{< notice info >}}
For AT&T Fiber to work, the ONT port must *also* provide EAP-TLS 802.1X authentication to AT&T.
{{< /notice >}}

![](/img/bypassing-att-fiber-gateway-2s8OU3K.png#center)

802.1X is usually used for enterprise WiFi authentication. AT&T fiber uses 802.1X to authenticate their customer's residential gateway.

Let's break down what 802.1X is; only three components are needed for 802.1X authentication.

* A supplicant or client (NVG589 ONT) to initiate 802.1X negotiation
* A controller (???) to handle access before and after 802.1X authentication
* A RADIUS server (AT&T) to authenticate the client.

A [supplicant](https://en.wikipedia.org/wiki/Supplicant_(computer)) is an entity at one end of a point-to-point LAN segment that seeks to be authenticated by an authenticator attached to the other end of that link.

![](/img/bypassing-att-fiber-gateway-9nnDG82.png#center)

In AT&T's default setup, we have:
* **NVG589**: The supplicant (client)
* **???**: The controller handling authentication access
* **AT&T RADIUS Server**: Based on hardware AT&T TLS certificates

The NVG589 ONT port (**1**) handles 802.1X authentication (**2**), allowing for internet (**3**) traffic.

Steps (**1**) and (**2**) are EAP. EAP stands for Extensible Authentication Protocol and is how AT&T gateways authenticate.

{{< notice note >}}
One very significant factor about EAP-TLS is that it requires mutual TLS (mTLS). Notice a couple of pictures above that AT&T provides identification (TLS) and the NVG589 (TLS).
{{< /notice >}}

![](/img/bypassing-att-fiber-gateway-zEACvlp.png#center)

## How do we bypass the AT&T gateway?

We now know what the problem is: AT&T requires 802.1X authentication using certificates only available on their gateways. How can we bypass the gateway altogether if certificates are required?

There's a handful of accepted methods with varying degrees of complexity. It also matters what your goal is and what devices you have.

{{< notice note >}}
I'm testing this on a **UDM Pro (v1.8.5)**

This article focuses on using `wpa_supplicant`, but it's worth understanding what alternatives exist and why. Let's start with the easiest option.
{{< /notice >}}

### The "dumb switch" method

This is a way to trick your AT&T connection using a switch and MAC spoofing. You trick the optical network terminal into thinking your WAN network interface is the ONT interface on your AT&T gateway. There's more detailed information in this [dslreports.com post](https://www.dslreports.com/forum/r32491796-bypass-att-pace-gateway) or this [unifi post](https://community.ui.com/questions/How-to-eliminate-ATandT-gateway-from-a-UniFi-setup/6f471739-7694-4512-9bb9-d1c8728d929f?page=4). The process is, authenticate with the NVG589 then swap gateway cables to your WAN spoofed uplink. Once completed, the connection operates as intended until reset or rebooted.

![](/img/bypassing-att-fiber-gateway-hVt3jAy.png#center)

It's a [blue-green deployment](https://en.wikipedia.org/wiki/Blue-green_deployment) for WAN uplinks. It seems very simple to test but not easy to maintain long term.

{{< notice warning >}}
Note: AT&T is currently installing fiber infrastructure that uses different authentication methods. If you're in one of those areas, none of these bypass methods will work. See [this thread](https://www.dslreports.com/forum/r32839785-AT-T-Fiber-Gateway-bypass-with-WPA-supplicant-stopped-working-2-days-ago) for more info.
{{< /notice >}}

### The EAP proxy method

This method proxies EAP packets between network interfaces for authentication, leaving other packets alone for a direct connection. The proxy is ran as a process, or a container, on your gateway. It looks for EAP traffic and forces it to talk to the NVG589.

![](/img/bypassing-att-fiber-gateway-EdVc7Vz.png#center)

The EAP proxy listens on both interfaces for EAP over LAN frames and forwards EAP packets between interfaces. It works well because there is no need for an advanced setup.

The negative is, that you're still taking up a port and relying on a running gateway at all times for authentication. Find more details [here](https://github.com/jaysoffian/eap_proxy).

### The `netgraph` method

Made popular by GitHub user MonkWho, [this option](https://github.com/MonkWho/pfatt) is mainly used by pfSense users and involves using [netgraph](https://www.freebsd.org/cgi/man.cgi?netgraph(4)) to bridge 802.1X traffic to the NVG589 ONT port. The result is a similar solution to the EAP proxy, only using a different tool. This solution still requires relying on a running gateway at all times for authentication.

### The WPA supplicant method

This is the method we're implementing. Earlier I mentioned that 802.1X only needs a supplicant, controller, and RADIUS server to work. If the AT&T gateway certificates exchanged for 802.1X authentication are valid, does it matter what the supplicant is? 🙃

![](/img/bypassing-att-fiber-gateway-w4OM6BU.png#center)

[`wpa_supplicant`](https://linux.die.net/man/8/wpa_supplicant) is a binary that acts as a supplicant for 802.1X (AT&T). I like this option because of the lack of devices and cables; it's "clean."

## The plan
* Get keys from a working AT&T gateway
    * Gain admin access on a NVG589 ([root](https://github.com/bypassrg/att/blob/master/README.md#nvg589))
    * Copy certificates and `mfg.dat`
* Extract private keys from `mfg.dat` using [mfg_dat_decode tool](https://www.devicelocksmith.com/2018/12/eap-tls-credentials-decoder-for-nvg-and.html)
* Copy `.pem` files and `wpa_supplicant.conf` to UDM Pro
* Run [wpa_supplicant](https://github.com/pbrah/wpa_supplicant-udmpro) on the UDM Pro
* ...
* Profit

## Get certificates from a working AT&T gateway

To get the data from an AT&T gateway, we must use public knowledge of security vulnerabilities in old NVG589 gateway's firmware to gain root access.

If you've spent time searching this topic, you'll see that most people buy their rooted AT&T certificates from eBay. This could be because rooting is too complex or not worth their time. I love learning new skills, and I'm ready to get my hands dirty, let's give it a try!

To extract the certificates, we generally have the following options:

- Hardware exploits (reading data via physical chip)
    - Pros: works 100% of the time
    - Cons: hard
- Software exploits (reading data via open exploits)
    - Pros: easy
    - Cons: patched on modern devices

### Gain admin access on a NVG589 ([root](https://github.com/bypassrg/att/blob/master/README.md#nvg589))

I first encountered a promising [thread](https://github.com/bypassrg/att#rooting-1) about using software exploits by upgrading or downgrading the NVG firmware to an exploitable version.

The [CVE-2017-14115](https://www.cvedetails.com/cve/CVE-2017-14115/) exploit:

>The AT&T U-verse 9.2.2h0d83 firmware for the Arris NVG589 and NVG599 devices, when IP Passthrough mode is not used, configures ssh-permanent-enable WAN SSH logins to the remotessh account with the 5SaP9I26 password, which allows remote attackers to access a "Terminal shell v1.0" service, and subsequently obtain unrestricted root privileges, by establishing an SSH session and then entering certain shell metacharacters and BusyBox commands.

Unrelated, can we talk about how crazy it is that there was a **WAN exposed**, **HARD-CODED**, **SSH login**? Oof.

I **abruptly** learned that AT&T patched most of the exploits on modern, internet-connected routers. No matter how many times I upgraded or downgraded, I could *not* root my NVG589.

As I went deeper down the rabbit hole, it seemed like my only option was going to be exploiting the hardware. So I bought another NVG589 off of eBay to avoid bricking my only working device.

![](/img/bypassing-att-fiber-gateway-Jc6hWUx.png#center)

When the NVG589 arrived, I plugged it in offline.

Luckily it had older firmware that allowed me to downgrade to version `9.2.2h0d83` and SSH into it with no problems.

After using the default username `remotessh` and password `5SaP9I26` to log in, run the following commands:

```shell
ping -c 1 192.168.1.254;echo /bin/nsh >>/etc/shells
ping -c 1 192.168.1.254;echo /bin/sh >>/etc/shells
ping -c 1 192.168.1.254;sed -i 's/cshell/nsh/g' /etc/passwd
```

Afterward, restart the session and switch to root:

```shell
exit
ssh remotessh@192.168.1.254
```

Type `!` to switch to root shell.


### Copy certificates and `mfg.dat`

```shell
# mount, copy, and unmount the data to a local directory
mount mtd:mfg -t jffs2 /mfg && cp /mfg/mfg.dat /tmp/ && umount /mfg

# change into the tmp directory
cd /tmp

# create a tarball called cert.tar containing all certs in /etc/rootcerts
tar cf cert.tar /etc/rootcert/

# copy cert.tar and mfg.dat to a browsable URL on the gateway
cp cert.tar /www/att/images
cp /tmp/mfg.dat /www/att/images
```

To download the two files, *right-click* > *Save Link As...* 192.168.1.254/images/mfg.dat and 192.168.1.254/images/cert.tar to your **local** device. When I clicked on the links, instead of downloading, my browser freaked out.

## Extract private keys from `mfg.dat` using [mfg_dat_decode tool](https://www.devicelocksmith.com/2018/12/eap-tls-credentials-decoder-for-nvg-and.html)

The `mfg.dat` is a file like you might use to flash a BIOS. It is an entire flash "state," but we only want the certificates. The data can be manually mounted and extracted if you're savvy in this field. However, there is nifty utility ([mfg_dat_decode tool](https://www.devicelocksmith.com/2018/12/eap-tls-credentials-decoder-for-nvg-and.html)) that does everything for you including bundling the output in a nice file.

Following the instructions from [here](https://www.devicelocksmith.com/2018/12/eap-tls-credentials-decoder-for-nvg-and.html):

```shell
# extract the mfg_dat_decode after downloading
cd ~/Downloads/
tar xzvf mfg_dat_decode_1_04.tar.gz 

# make executable
mv linux_amd64/mfg_dat_decode /usr/bin/
chmod +x /usr/bin/mfg_dat_decode

# move contents to working dir
mv ~/Desktop/mfg.dat .
mv ~/Desktop/cert.tar .

# extract certs
tar xvf cert.tar

# run the program
mfg_dat_decode
```

Output is similar to

```shell
802.1x Credential Extraction Tool
Copyright (c) 2018-2019 devicelocksmith.com
Version: 1.04 linux amd64

Found client certificate for Serial Number: XXXXXXXXXX-XXXXXXXXXXXXX

Found certificates with following Subjects:
	XX:XX:XX:XX:XX:XX
				 expires 2034-07-29 19:46:26 -0500 CDT
	Motorola, Inc. Device Intermediate CA
				 expires 2033-04-30 12:36:29 -0500 CDT
	Motorola, Inc. Device Root CA
				 expires 2038-04-30 11:30:26 -0600 CST
Verifying certificates.. success!
Validating private key.. success!
Found valid AAA server root CA certificates:
	System Infrastructure Root CA (SHA256)
				 expires 2044-07-10 14:12:33 -0600 CST
	ATT Services Inc Root CA
				 expires 2031-02-23 17:59:59 -0600 CST
	Frontier-RootCA
				 expires 2024-05-01 08:20:27 -0500 CDT
Successfully saved EAP-TLS credentials to
	~/Downloads/EAP-TLS_8021x_XXXXX-XXXXXXXX.tar.gz
```

`~/Downloads/EAP-TLS_8021x_XXXXX-XXXXXXXX.tar.gz` contains all the files we need to configure the `wpa_supplicant` binary.

{{< notice note >}}
Before moving forward, I connected the NVG589 as-is to validate my eBay NVG589 could get service as-is. Everything worked after a few minutes, I didn't need to call AT&T to "authorize" the router or anything. My existing service worked with the new gateway, now let's swap it out.
{{< /notice >}}

## Copy `.pem` files and `wpa_supplicant.conf` to UDM Pro

Extract all `.pem` files and `wpa_supplicant.conf` from `~/Downloads/EAP-TLS_8021x_XXXXX-XXXXXXXX.tar.gz` to your UDM Pro. [WinSCP](https://winscp.net/eng/index.php) can be used on Windows computers without SCP.

```shell
scp -r *.pem root@192.168.1.1:/tmp/
root@192.168.1.1's password:
CA_001E46-xxxx.pem                                                          100% 3926     3.8KB/s   00:00
Client_001E46-xxxx.pem                                                      100% 1119     1.1KB/s   00:00
PrivateKey_PKCS1_001E46-xxxx.pem                                            100%  887     0.9KB/s   00:00

scp -r wpa_supplicant.conf root@192.168.1.1:/tmp/
wpa_supplicant.conf                                                         100%  680     0.7KB/s   00:00
```

Copy the files to a permanent location like `/mnt/data/podman/wpa_supplicant/` for future use on the UDM Pro.

```shell
# login
ssh root@192.168.1.1

# make directory
mkdir /mnt/data/podman/wpa_supplicant/

# copy files
cp -arfv /tmp/*pem /tmp/wpa_supplicant.conf /mnt/data/podman/wpa_supplicant/
```

Deleting the old files is unnecessary as `/tmp/` is purged after every reboot.

Update the `wpa_supplicant.conf` file with the correct file paths of your `.pem` certificate files.

```shell
sed -i 's,ca_cert=",ca_cert="/etc/wpa_supplicant/conf/,g' /mnt/data/podman/wpa_supplicant/wpa_supplicant.conf

sed -i 's,client_cert=",client_cert="/etc/wpa_supplicant/conf/,g' /mnt/data/podman/wpa_supplicant/wpa_supplicant.conf

sed -i 's,private_key=",private_key="/etc/wpa_supplicant/conf/,g' /mnt/data/podman/wpa_supplicant/wpa_supplicant.conf
```

After running the `sed` commands, verify your paths in `wpa_supplicant.conf` look similar.

```shell
# cat wpa_supplicant.conf
# Generated by 802.1x Credential Extraction Tool
# Copyright (c) 2018-2019 devicelocksmith.com
# Version: 1.04 linux amd64
#
# Change file names to absolute paths
eapol_version=1
ap_scan=0
fast_reauth=1
network={
        ca_cert="/etc/wpa_supplicant/conf/CA_001E46-xxxxxxxx.pem"
        client_cert="/etc/wpa_supplicant/conf/Client_001E46-xxxxxx.pem"
        eap=TLS
        eapol_flags=0
        identity="10:05:B1:xx:xx:xx" # Internet (ONT) interface MAC address must match this value
        key_mgmt=IEEE8021X
        phase1="allow_canned_success=1"
        private_key="/etc/wpa_supplicant/conf/PrivateKey_PKCS1_001E46-xxxxxx.pem"
}
```

If you see `WARNING! Missing AAA server root CA! Add AAA server root CA to CA_001E46-xxxxxx.pem` you might have done something wrong. I had this happen the first time, and it was due to not extracting the certificates in the same directory.

## Podman

Let's talk about Podman.

![](/img/bypassing-att-fiber-gateway-u3WTnjE.png#center)

UDM Pro runs the `unifi-os` in a container on Podman. Podman is almost a 1:1 replacement for Docker. Without getting too deep into how containerization works, let's understand that a container is simply a process. A process running on the host like any other.

There's container magic limiting the hosts resource consumption, but it's still a process running at the end of the day.

Even though I **trust** the UDM Pro to run containers, I don't trust it to run **ANY** containers. Let's look at the `wpa_supplicant` Dockerfile based off of the [wpa_supplicant-udmpro](https://github.com/pbrah/wpa_supplicant-udmpro) repo.

```shell
FROM alpine
RUN apk add --no-cache wpa_supplicant
ENTRYPOINT ["wpa_supplicant"]
CMD []
```

In this case, it's an Alpine container with a `wpa_supplicant` package installed. Running this container is almost identical to executing a `wpa_supplicant` command on the OS. Considering how basic the container is, let's create it ourselves.

## Create local docker image

This step is optional but I like to know the source of things running on my network. Optionally, skip this step and use `pbrah/wpa_supplicant-udmpro:v1.0` for the container image for future commands.

{{< notice note >}}
You should build the `wpa_supplicant` container on the UDM Pro to avoid issues with ARMx64 architecture.
{{< /notice >}}

On the UDM Pro, create a file named `Dockerfile` with the following content

```shell
FROM alpine
RUN apk add --no-cache wpa_supplicant
ENTRYPOINT ["wpa_supplicant"]
CMD []
```

Build the container using the name and tag of `jimangel/wpa_supplicant-udmpro:v1.0` (note the trailing `.` in the command).

```shell
podman build --network=host -t jimangel/wpa_supplicant-udmpro:v1.0 .
```

Confirm the new image exists.

```shell
podman images | grep udmpro
```
Output looks similar to
```shell
localhost/jimangel/wpa_supplicant-udmpro   v1.0      5c56e6248ddd   35 hours ago    10.3 MB                    false
```

## Run [wpa_supplicant](https://github.com/pbrah/wpa_supplicant-udmpro) on the UDM pro

Assuming your UDMP connects to the internet via port 9 (the ethernet WAN port, not the SFP+ port 10), run the `wpa_supplicant` in the background. The ports internally are referenced starting with 0, so port 9 on the device is actually `eth8` and `eth9` is port 10.


```shell
podman run --privileged --network=host \
--name=wpa_supplicant-udmpro \
-v /mnt/data/podman/wpa_supplicant/:/etc/wpa_supplicant/conf/ \
--log-driver=k8s-file --restart always -d \
-ti localhost/jimangel/wpa_supplicant-udmpro:v1.0 \
-Dwired -ieth8 -c/etc/wpa_supplicant/conf/wpa_supplicant.conf
```

Let's breakdown exactly what the command is doing:

* Run an Alpine container (that runs wpa_supplicant) as root (privileged) with real host networking attached
* Name the container "wpa_supplicant-udmpro"
* Mount the certs and config in the container at /etc/wpa_spplicant/conf/
* Log (k8s default?) and always restart (as recommended)
* Run the container in the background (-d detached) with an interactive terminal (-it)
* Launch `wpa_supplicant` (Docker ENTRYPOINT) with the following options ` -Dwired -ieth8 -c/etc/wpa_supplicant/conf/wpa_supplicant.conf` meaning to use the wired eth8 (-i) device to init 802.1X

You did it! It should be running now; if not, read on.

## Troubleshooting and logs

I cannot express how valuable logs are at this point. Assuming things are going according to plan, we should be able to plug the WAN ONT cable in and run

```shell
podman logs -f wpa_supplicant-udmpro
```

Output looks similar to

```shell
Successfully initialized wpa_supplicant
eth8: Associated with XX:XX:XX:XX:XX:XX
eth8: CTRL-EVENT-SUBNET-STATUS-UPDATE status=0
...
eth8: CTRL-EVENT-EAP-SUCCESS EAP authentication completed successfully
```

Other helpful Podman commands include

```shell
# list all containers
podman ps -a

# list images
podman images

# inspect container
podman inspect CONTAINER_ID

# SSH / exec into a container
podman exec -it CONTAINER_ID /bin/bash

# delete container
podman rm wpa_supplicant-udmpro
```

Regarding troubleshooting, I read many people have issues that require spoofing ONT MAC addresses or forcing ONT traffic on [VLAN 0](https://www.cisco.com/c/en/us/td/docs/switches/connectedgrid/cg-switch-sw-master/software/configuration/guide/vlan0/b_vlan_0.pdf). I didn't have to change any of my default settings, but it's worth keeping in mind if you run out of options.

## Surviving reboots

With the above working, we are in business. However, the next time everything reboots, you'll have to SSH into the UDM Pro and restart the container.

Most solutions for "surviving reboots" get overwritten with a firmware upgrade. However, someone figured out that Ubiquiti caches all the `unifi-os` debian packages installed on the UDM Pro in /mnt/data, then re-installs them on boot.

We know that `unifi-os` is running in a Podman container on the UDM Pro.

As a result, `udm-utilities/on-boot-script` was born. A debian package that installs a big for-loop service to run scripts on boot. This allows us to dump scripts in `/mnt/data/on_boot.d/` to be ran at startup; always. The service translates to:

```shell
if [ -d /mnt/data/on_boot.d ]; then
	for i in /mnt/data/on_boot.d/*.sh; do
		if [ -r $i ]; then
			. $i
		fi
	done
fi
```

At first, I was suspicious about running a random person's GitHub debian package on my entire home network gateway. After looking at the [source code](https://github.com/boostchicken/udm-utilities/tree/master/on-boot-script/dpkg-build-files), it seemed harmless.

You can also [build the debian yourself](https://github.com/boostchicken/udm-utilities/blob/master/on-boot-script/build_deb.sh) if you're concerned about security.

I followed the following steps in [this guide](https://github.com/boostchicken/udm-utilities/tree/master/on-boot-script#steps) to install the debian package.

```shell
# log in
unifi-os shell

# download and install
curl -L https://raw.githubusercontent.com/boostchicken/udm-utilities/master/on-boot-script/packages/udm-boot_1.0.5_all.deb -o udm-boot_1.0.5_all.deb
dpkg -i udm-boot_1.0.5_all.deb

# drop back to UDM Pro
exit
```


Create a script [`10-wpa_supplicant.sh`](https://github.com/boostchicken/udm-utilities/blob/master/on-boot-script/examples/udm-files/on_boot.d/10-wpa_supplicant.sh) to start the container on reboot.

```shell
vi /mnt/data/on_boot.d/10-wpa_supplicant.sh
```

Copy the [`10-wpa_supplicant.sh`](https://github.com/boostchicken/udm-utilities/blob/master/on-boot-script/examples/udm-files/on_boot.d/10-wpa_supplicant.sh) example contents.

```shell
#!/bin/sh
podman start wpa_supplicant-udmpro
```

Make it executable.

```shell
chmod +x /mnt/data/on_boot.d/10-wpa_supplicant.sh
```

Test it!

```shell
# what better way than a REAL reboot!?
reboot
```

If everything works, you should have internet access. You can confirm by SSHing into the UDM Pro and running `podman ps` to check for the `wpa_supplicant` container.

## Clean up

Disable SSH on the UDM Pro; it's a good habit to leave it off.

Navigate to the UDM Pro's IP > Settings Manage Settings > Advanced > SSH (off)

![](/img/bypassing-att-fiber-gateway-XYrLTAY.png#center)

## Conclusion

It works! If you step back, all you're doing is running a (wpa_supplicant) process on the UDMP with copied certificates. 95% of the work is getting the certificates copied.

If you look at "real" running processes on the UDM Pro you see the `wpa_supplicant` because we launched it in a container.

![](/img/bypassing-att-fiber-gateway-lyMVBam.png#center)

Put another way:

![](/img/bypassing-att-fiber-gateway-w4OM6BU.png#center)

I'm now comfortable factory resetting, stopping the container, or otherwise resetting the UDM Pro. I also feel safe in the choices I made to enable bypassing the NVG589.

It also feels good to understand exactly how I'm bypassing the AT&T router and I don't foresee any upgrades impacting my UDM Pro.

A minor side note, [myhomenetwork.att.com](https://myhomenetwork.att.com/), which previously reported my home internet as "up" is now set to "down."

![](/img/bypassing-att-fiber-gateway-MvXJ4x7.png#center)

But I'm ok with that.

![](/img/bypassing-att-fiber-gateway-LK1Wxys.png#center)

Even though things are working for me, I still plan on adding additional information about dumping the NAND flash. Once I receive my gear, I'll update this post. Good luck!

## Helpful links

*  [SharknAT&To: AT&T exploits](https://web.archive.org/web/20211017194517/https://www.nomotion.net/blog/sharknatto/)
*  [wpa_supplicant for UDM and UDM Pro](https://github.com/pbrah/wpa_supplicant-udmpro)
*  [ATT Fiber Bypass with UDP Pro](https://www.reddit.com/r/Ubiquiti/comments/j60daq/att_fiber_bypass_with_udp_pro/)
*  [Bypassing the AT&T Fiber Modem/Gateway with a Unifi Dream Machine Pro](https://blog.itske.vin/post/627742851524083712/bypassing-the-att-fiber-modemgateway-with-a)
*  [Bypassing the AT&T Fiber modem with a UniFi Dream Machine Pro](https://wells.ee/journal/2020-08-05-bypassing-att-fiber-modem-udmp/)

## Extra: Using the SFP+ WAN port

While writing this, I switched from using my WAN 1Gb port to using the SFP+ port. Below is how I moved and reset the `wpa_supplicant`. This might be helpful for folks with similar ambitions.

Plug a computer directly into the UDM Pro and unplug all other cables to avoid unintentional impact.

```shell
# stop podman container
podman stop wpa_supplicant-udmpro

# delete container
podman rm wpa_supplicant-udmpro

# start up on WAN SFP port (eth9)
podman run --privileged --network=host \
--name=wpa_supplicant-udmpro \
-v /mnt/data/podman/wpa_supplicant/:/etc/wpa_supplicant/conf/ \
--log-driver=ak8s-file --restart always -d \
-ti localhost/jimangel/wpa_supplicant-udmpro:v1.0 \
-Dwired -ieth9 -c/etc/wpa_supplicant/conf/wpa_supplicant.conf

# plug in ISP cable

# follow logs
podman logs -f wpa_supplicant-udmpro

# keep watching the logs for
"eth9: CTRL-EVENT-EAP-SUCCESS EAP authentication completed successfully"

# reboot for good luck
reboot
```