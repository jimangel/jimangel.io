---
title: "Running kind clusters in VMware Workstation Pro 16"
description: "Local, fast, Kubernetes cluster testing with kind and VMware Workstation Pro"
subtitle: "kind provides local, fast, Kubernetes cluster testing"
summary: "Play with some of the new container features in VMware Workstation Pro"
date: 2020-11-26
lastmod: 2020-11-26
#publishDate: You only need to specify this option if you wish to set date in the future but publish the page now.
featured: false
draft: false
authors:
- jimangel
tags:
- vmware
- homelab
- kubernetes
- kind
- powershell
categories: []
keywords:
- vmware workstation kubernetes
- vmware
- homelab
- kubernetes
- kind

cover:
  image: "img/kind-clusters-featured.jpg"
  alt: "Dark blue PowerShell prompt with the command 'kind create cluster' typed out"

slug: "running-kind-clusters-in-workstation-pro"
---

VMware Workstation Pro 16 recently announced support for [`kind`](https://docs.vmware.com/en/VMware-Workstation-Pro/16/rn/VMware-Workstation-16-Pro-Release-Notes.html#Whatsnew) Kubernetes clusters. `kind` stands for Kubernetes in Docker.

Additionally, you can run containers on your desktop using `vctl.exe`. For a general comparison, think of `vctl.exe` like the `docker` CLI ([commands](https://github.com/VMwareFusion/vctl-docs/blob/master/docs/getting-started.md#vctl-commands)).

To use the new features in Workstation, it's a two-step process:
* Start the [containerd](https://containerd.io/) based runtime with `vctl.exe system start`
* Do container-y things
  * Run a container on the host with `vctl.exe run IMAGE_NAME` 
  * Launch a `kind` environment with `vctl.exe kind`
    * Create a `kind` cluster with `kind create cluster`

Workstation uses a proprietary container runtime, CRX, based on containerd. CRX stands for "Container Runtime for ESXi." `vctl.exe` and `kind` create containers on CRX VMs. Each CRX VM is a new container runtime. A CRX VM includes a fast booting Linux kernel and minimal container runtime inside the guest. Since the Linux kernel couples with the hypervisor, it has many tweaks to paravirtualize the container. For more details on CRX VMs, read "[Project Pacific Technical Overview](https://blogs.vmware.com/vsphere/2019/08/project-pacific-technical-overview.html)" or "[vSphere 7 Pods Explained](https://blogs.vmware.com/vsphere/2020/05/vsphere-7-vsphere-pods-explained.html)."

## Overview

I couldn't find any great resources on what `vsctl.exe` *could* or *couldn't* do. Most of the documentation lacked the broader picture beyond single command examples. A lot of my discovery was trial and error.

Helpful spoilers:
* A CRX VM is still a vmx / vmdk on disk
* Containers running in CRX VMs do not show in the Workstation Pro GUI
    * Discover with the `vmrun.exe` CLI via `& "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe" list`
* By running containers in a VM (CRX), traffic and compute are more isolated between containers than on a traditional host
* `kind` accepts a `config.yaml` file to customize clusters

## Install console tools

Select this option during the installation of Workstation Pro 16. Workstation Pro 16 installs a utility called `vctl.exe` in your PATH. After that, the `vctl.exe` utility is accessible in all environments.

![](/img/kind-clusters-setup.jpg)

First, start the container runtime. The container runtime doesn't start or stop with the Workstation Player application.

1. Open up a PowerShell terminal
1. Run `vctl.exe system start` to start the container runtime

    ```bash
    vctl.exe system start
    ```
    Output
    ```bash
    Preparing storage...
    Container storage has been prepared successfully under C:\Users\me\.vctl\storage
    Preparing container network...
    Container network has been prepared successfully using vmnet: vmnet8
    Launching container runtime...
    Container runtime has been started.
    ```
1. Run `vctl.exe kind` to download the needed binaries

    ```bash
    vctl.exe kind
    ```
    Output
    ```bash
    Downloading 3 files...
    Downloading [kubectl.exe 90.22% crx.vmdk 2.89% kind-windows-amd64 4.45%]
    Finished kubectl.exe 100.00%
    Downloading [crx.vmdk 92.97% kind-windows-amd64 62.34%]
    Finished crx.vmdk 100.00%
    Downloading [kind-windows-amd64 88.87%]
    Finished kind-windows-amd64 100.00%
    3 files successfully downloaded.
    ```

The vctl-based KinD context is lost after you close the window. To retrieve an old context, run `vctl.exe kind` again. The official "using kind" docs are [here](https://docs.vmware.com/en/VMware-Workstation-Pro/16.0/com.vmware.ws.using.doc/GUID-1CA929BB-93A9-4F1C-A3A8-7A3A171FAC35.html).

## Create a cluster with kind

First make a general config file (`config.yaml`). I was unable to get node labels to work, so let's keep this example simple with a 3 worker and 1 control-plane node.

1. Copy and paste the entire content below to create the file.

    ```bash
    @'
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    nodes:
    - role: control-plane
    - role: worker
    - role: worker
    - role: worker
    '@ | Tee-Object -FilePath "config.yaml"
    ```
    
    > Note: You can **NOT** supply multiple control-plane nodes.

1. Create the cluster from the same window

    ```bash
    kind create cluster --config config.yaml
    ```

    Depending on internet speed and configuration complexity, the process may take a while.



## Use the cluster

Below are sample commands to inspect the new Kubernetes cluster.

Get cluster info

```bash
kubectl cluster-info --context kind-kind
```

Get all pods
```bash
kubectl get pods -A --context kind-kind
```

Get nodes
```bash
kubectl get nodes --context kind-kind
```


If you close the Powershell window, get back in with

```bash
vctl.exe kind
```

Inspect containers

```bash
vctl.exe describe kind-control-plane
```

## Clean up

Stop the containers and containerd runtime

```bash
vctl.exe system stop --force
```

If you want to be more graceful, delete the `kind` cluster first

```bash
kind delete cluster
vctl.exe system stop
```

To purge all container data on your host, delete the content in
```bash
%UserProfile%\.vctl\
```

## Conclusion

Would I use Workstation to run containers instead of Docker on Windows? Probably not.

If I had concerns about container tenant isolation at the host level, I would consider Workstation. Also, if I wanted to push container performance, I would look closer at Workstation's benchmarks. At that point, it might be worth evaluating cloud options with temporary high compute workloads.

I feel guilty for saying this, but I was hoping to see the containers in the VMware Workstation GUI. Having all virtualized containers and machines under one system would be great. Also, in my dream world, I could change the state of containers in the GUI. At the very least, a GUI for triggering `vctl.exe` (docker-esque) commands.

It's still awesome to see innovative solutions like this for embracing containers in consumer products. I look forward to future iterations of Workstation.

## Additional reading

* [Using the vctl Utility](https://docs.vmware.com/en/VMware-Workstation-Player-for-Windows/16.0/com.vmware.player.win.using.doc/GUID-E5957B83-4604-430D-BE7B-43CB85E57302.html)
* [A closer look at VMware's Project Nautilus](https://rguske.github.io/post/a-closer-look-at-vmwares-project-nautilus/)
* [VMware Project Pacific – Technical Overview](https://blog.calsoftinc.com/2019/10/vmware-project-pacific-technical-overview.html)
* [VMware Project Pacific – First Impressions](https://www.architecting.it/blog/vmware-project-pacific/)
* [vSphere 7 – vSphere Pods Explained](https://blogs.vmware.com/vsphere/2020/05/vsphere-7-vsphere-pods-explained.html)
