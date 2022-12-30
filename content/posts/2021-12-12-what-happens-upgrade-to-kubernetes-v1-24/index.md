---
title: "Upgrade gotchas for Kubernetes v1.24"
description: "How to prepare for the dockershim removal in Kubernetes 1.24"
summary: "How to prepare for the dockershim removal in Kubernetes 1.24"
subtitle: "Break your cluster when you want to, not when you have to"
date: 2021-12-12
lastmod: 2021-12-12
#publishDate: You only need to specify this option if you wish to set date in the future but publish the page now.
featured: false
draft: false
authors:
- jimangel
tags:
- kubernetes
- cncf
- dockershim
categories: []
keywords:
- kubeadm upgrade
- kubernetes
- cncf
- dockershim

comment: true
# Focal point options: Smart, Center, TopLeft, Top, TopRight, Left, Right, BottomLeft, Bottom, BottomRight
cover:
  image: "img/dockershim-kubernetes-v1.24-cover.jpg"
  alt: "2 legs in jeans with dusty working boots on a gravel trail in front of an orange rusty wavey wall. The picture is cut vertically before the knees."

slug: "dockershim-kubernetes-v1-24"
---

As Kubernetes grows in popularity, the changes each release become more and more critical to test. In v1.24 there are big changes that may or may not impact you.

Most people wait until the first patch release (`vX.XX.1`), after a major `vX.XX.0` version, before getting serious about upgrading. I'll demo how to test even earlier, before the major release.


{{< notice note >}}
Did you know Kubernetes releases alpha versions for the next release almost immediately after cutting a new release? For example, `v1.23.0` was released on 12/7/21 and `v1.24.0-alpha.1` was cut the very next day.
{{< /notice >}}

This blog tests the significant breaking changes between releases during a major version upgrade.

## Why is Kubernetes v1.24 release extra special?

Kubernetes v1.24 removes the dockershim from kubelet. Without getting too deep into the problem, this picture is helpful:

![](/img/dockershim-kubernetes-v1.24-dockershim.jpg)
([source](https://kubernetes.io/docs/tasks/administer-cluster/migrating-from-dockershim/check-if-dockershim-deprecation-affects-you/#role-of-dockershim))

The dockershim code is actually inside kubelet's code base. This was an early design decision before Container Runtime Interfaces (CRI) existed.

Here's an alternative way to view the differences (I wish it said CAN use vs. USES):

![](/img/dockershim-kubernetes-v1.24-containerd.jpg)
([source](https://iximiuz.com/en/posts/containerd-command-line-clients/))

For additional context and information, read more [about the removal here](https://k8s.io/dockershim).


{{< notice note >}}
Many cloud providers are already using a non-Docker CRI and there is no impact to you. I believe the most impacted user group is consumers of upstream OSS Kubernetes.
{{< /notice >}}

## Starting point

Let's start with a "traditional" single node cluster running an "old" `v1.23.0` release. Quick summary of components:

* Ubuntu 20.04 LTS (at least 40G disk free)
* Docker v20.X ([install guide](https://docs.docker.com/engine/install/ubuntu/))
* golang ([install guide](https://go.dev/doc/install))
    * URL: https://go.dev/dl/go1.17.5.linux-amd64.tar.gz
* Kubernetes v1.23.X
    * [Disable swap](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#before-you-begin)
        * [hint](https://graspingtech.com/disable-swap-ubuntu/)
    * [Letting iptables see bridged traffic](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#forwarding-ipv4-and-letting-iptables-see-bridged-traffic)
    * [Installing kubeadm, kubelet and kubectl](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl)
    * [Initializing your control-plane node](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#initializing-your-control-plane-node) (`sudo kubeadm init`)

The first run failed, but I expected that, as I haven't updated kubelet or docker to use the systemd cgroup driver (a change in v1.22+). The first run creates the config files to modify for the fix; specifically `/var/lib/kubelet/config.yaml`.

To fix the error, follow [this gist I wrote](https://gist.github.com/jimangel/21568c757b2b374cabb8cc53e6c9125f).

When finished, re-run `sudo kubeadm reset && sudo kubeadm init`

Output should be successful. Now copy the kubectl config for use:

```shell
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

To test, run `kubectl get nodes`. Output is similar to:

```shell
NAME        STATUS     ROLES                  AGE   VERSION
ubu-servr   NotReady   control-plane,master   59s   v1.23.0
```

Finally, install a CNI ([Calico](https://projectcalico.docs.tigera.io/getting-started/kubernetes/self-managed-onprem/onpremises)).

```shell
curl https://docs.projectcalico.org/manifests/calico.yaml -O
kubectl apply -f calico.yaml
```

Ensure the pods/node is ready:

```shell
$ kubectl get pods -A

NAMESPACE     NAME                                       READY   STATUS    RESTARTS   AGE
kube-system   calico-kube-controllers-647d84984b-247k2   1/1     Running   0          33s
kube-system   calico-node-shq29                          1/1     Running   0          33s
kube-system   coredns-64897985d-75jsz                    1/1     Running   0          2m45s
kube-system   coredns-64897985d-ws4rb                    1/1     Running   0          2m45s
kube-system   etcd-ubu-servr                             1/1     Running   1          2m52s
kube-system   kube-apiserver-ubu-servr                   1/1     Running   1          2m53s
kube-system   kube-controller-manager-ubu-servr          1/1     Running   1          2m52s
kube-system   kube-proxy-4qvcb                           1/1     Running   0          2m45s
kube-system   kube-scheduler-ubu-servr                   1/1     Running   1          2m50s

$ kubectl get nodes

NAME        STATUS   ROLES                  AGE     VERSION
ubu-servr   Ready    control-plane,master   2m48s   v1.23.0
```

## Deploy a "hello-world" workload

```shell
kubectl create deployment echo-server --image=inanimate/echo-server --replicas=3
```

kubeadm, by default, [taints](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) the control plane, which prevents pods from being scheduled. Let's remove the taint considering we're only running a single node. The `-` at the very end is what indicates removal.

```shell
kubectl taint nodes --all node-role.kubernetes.io/master-
```

Check that it's running:

```shell
$ kubectl get pods

NAME                          READY   STATUS    RESTARTS   AGE
echo-server-648d5dd78-5cvzz   1/1     Running   0          3m18s
echo-server-648d5dd78-9jnng   1/1     Running   0          3m18s
echo-server-648d5dd78-9vp2p   1/1     Running   0          3m18s
```

Confirm in a browser by using port-forward.

```shell
kubectl port-forward --address 0.0.0.0 deployment/echo-server 8080:8080
```

Open a browser and navigate to `YOUR_NODE_IP:8080`

It works! Now onto the fun stuff.



## Upgrade to v1.24

Since v1.24 isn't released, we have to use an unreleased version (alpha/beta/release-candidate). While adding some complexity, it's not much more work to manually gather all the tooling & container images. 

`kubeadm` has a guide on their repository about [testing pre-release versions of Kubernetes with kubeadm](https://github.com/kubernetes/kubeadm/blob/main/docs/testing-pre-releases.md).

### Create local debian files

First, [install kubepkg using go](https://github.com/kubernetes/release/tree/master/cmd/kubepkg#installation) (below). Since I'm using a testing server, I plan on being destructive & moving fast.

Build `kubepkg` and generate the debian packages for updating.

```shell
# need `dpkg-buildpackage` & `debhelper` to build debians
sudo apt install dpkg-dev debhelper

git clone https://github.com/kubernetes/release.git

cd release/cmd/kubepkg/

go install ./...

~/go/bin/kubepkg debs --channels release --arch amd64 --kube-version v1.24.0-alpha.1 --packages kubelet,kubectl,kubeadm
```

Output ends similar to:

```shell
INFO Successfully walked builds
```


### Upgrade kubeadm and kubectl

We know there's a breaking change in `kubelet`, and according to the [version skew policy](https://kubernetes.io/releases/version-skew-policy/#kubelet), "`kubelet` must not be newer than `kube-apiserver`, and may be up to two minor versions older."

In that case, let's first upgrade `kubeadm` & `kubectl` (not `kubelet`).

```shell
sudo apt-mark unhold kubeadm kubectl

sudo apt install $(pwd)/bin/testing/kubectl_1.24.0-alpha.1-0_amd64.deb $(pwd)/bin/testing/kubeadm_1.24.0-alpha.1-0_amd64.deb
```

Validate: 

```shell
$ kubectl version --client
Client Version: version.Info{Major:"1", Minor:"24+", GitVersion:"v1.24.0-alpha.1", GitCommit:"cdf3ad823a33733dbbfcec45b368be8ed9690c5b", GitTreeState:"clean", BuildDate:"2021-12-09T02:30:41Z", GoVersion:"go1.17.4", Compiler:"gc", Platform:"linux/amd64"}


$ kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"24+", GitVersion:"v1.24.0-alpha.1", GitCommit:"cdf3ad823a33733dbbfcec45b368be8ed9690c5b", GitTreeState:"clean", BuildDate:"2021-12-09T02:29:30Z", GoVersion:"go1.17.4", Compiler:"gc", Platform:"linux/amd64"}
```

### Stage container images

To avoid any issues with removing Docker, I didn't want to stage the images locally. Instead, I created a Google Artifact Repo and uploaded the images. More info on _how_ in this ([gist](https://gist.github.com/jimangel/6c46f20b8f156d45d2a66175d8bbe9ab)).

### Run the `kubeadm` upgrade process

We need to deviate from the public images to use our new custom public repo. Kubeadm doesn't support changing the configuration during an upgrade ([details](https://github.com/kubernetes/kubeadm/issues/2050#issuecomment-594149278)). As a "hack," we'll update the config map. DO NOT DO THIS IN PRODUCTION.

```shell
kubectl -n kube-system edit cm kubeadm-config
```

Change `imageRepository: k8s.gcr.io` to `imageRepository: us-central1-docker.pkg.dev/out-of-pocket-cloudlab/k8s-testing`.

Now we're ready to upgrade. Run a preflight check to ensure things are working as intended.

```shell
sudo kubeadm upgrade plan
```

Run the upgrade and apply it, allowing for experimental upgrades.

```shell
sudo kubeadm upgrade apply v1.24.0-alpha.1 --allow-experimental-upgrades
```

After some time, the output is similar to:

```shell
[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.24.0-alpha.1". Enjoy!

[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.
```

Let's take a look!

```shell
kubectl get nodes
```

```shell
NAME        STATUS   ROLES                  AGE    VERSION
ubu-servr   Ready    control-plane,master   171m   v1.23.0
```

I'm not too concerned about it still saying `v1.23.0` as I believe `kublet` is responsible for reporting this information to the API server and we have not yet upgraded it. Let's check the running pods/images:

```shell
kubectl describe pods -A | grep -i "image:" | uniq
```

We can see that the image tags are using 1.24, and nothing references 1.23.

```shell
    Image:         inanimate/echo-server
    Image:         docker.io/calico/kube-controllers:v3.21.2
    Image:         docker.io/calico/cni:v3.21.2
    Image:         docker.io/calico/pod2daemon-flexvol:v3.21.2
    Image:         docker.io/calico/node:v3.21.2
    Image:         us-central1-docker.pkg.dev/out-of-pocket-cloudlab/k8s-testing/coredns:v1.8.6
    Image:         us-central1-docker.pkg.dev/out-of-pocket-cloudlab/k8s-testing/etcd:3.5.1-0
    Image:         us-central1-docker.pkg.dev/out-of-pocket-cloudlab/k8s-testing/kube-apiserver:v1.24.0-alpha.1
    Image:         us-central1-docker.pkg.dev/out-of-pocket-cloudlab/k8s-testing/kube-controller-manager:v1.24.0-alpha.1
    Image:         us-central1-docker.pkg.dev/out-of-pocket-cloudlab/k8s-testing/kube-proxy:v1.24.0-alpha.1
    Image:         us-central1-docker.pkg.dev/out-of-pocket-cloudlab/k8s-testing/kube-scheduler:v1.24.0-alpha.1
```

So far, pretty pain-free. Let's check our ability to port forward.

```shell
kubectl port-forward --address 0.0.0.0 deployment/echo-server 8080:8080
```

Yep! We're in good shape. Next, we'll upgrade `kubelet`. Please note, if this was a larger system, you should follow the official upgrade guide, including drain/cordon nodes.

```shell
sudo apt-mark unhold kubelet

sudo apt install $(pwd)/bin/testing/kubelet_1.24.0-alpha.1-0_amd64.deb
```

Running `kubelet --version`, we now see that it's `Kubernetes v1.24.0-alpha.1`. However, if we run `service kubelet status`, you'll notice it failed (`code=exited, status=1/FAILURE`).

Debug further with `journalctl -xeu kubelet`. After looking a bit, boom, here's the culprit:

```shell
 "Failed to run kubelet" err="failed to run Kubelet: using dockershim is not supported, please consider using a full-fledged CRI implementation."
```

Cool. Now we have a cluster with a 100% working and functional control plane, but kubelet (the node's brain) is not working.

We have two options here:
* Continue using Docker with a 3rd party CRI
    * Install [cri-dockerd](https://github.com/mirantis/cri-dockerd) (Mirantis' [officially maintained](https://www.mirantis.com/blog/the-future-of-dockershim-is-cri-dockerd/) dockershim replacement)
* Swap `docker-ce` for `containerd` as kubelet's CRI of choice
 
I like the idea of running fewer things on a node; let's see how hard it is to switch to containerd.

Here's the cool thing,

> If you installed `docker-ce` following the [official instructions](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository), you already installed `containerd.io`!

That means we just need to update `kubelet`'s configuration to bypass Docker. Stop docker by running:

```shell
sudo systemctl stop docker
sudo systemctl disable docker.service docker.socket
```

`systemctl disable` prevents the services from starting on reboot.

Then update the existing `containerd` config to INCLUDE the CRI plugin, which is currently disabled by default. It might seem a bit backward, but we can enable it by commenting out the disable flag in `/etc/containerd/config.toml`.

```shell
# sed adds a "#" to the disabled plugins line.
sudo sed -i 's/disabled_plugins/#disabled_plugins/g' /etc/containerd/config.toml
```

Validate with `cat /etc/containerd/config.toml`.

Restart containerd with `sudo systemctl daemon-reload && sudo systemctl restart containerd` and check the status with `sudo systemctl status containerd`

Now that containerd is configured, we need to update kubelet to use the runtime (CRI) instead of Docker.

Edit `/var/lib/kubelet/kubeadm-flags.env` to point at containerd.

```shell
sudo vi /var/lib/kubelet/kubeadm-flags.env
```

We need to add `--container-runtime=remote` (has only two arguments, `docker` or `remote`) and `--container-runtime-endpoint=unix:///run/containerd/containerd.sock` (defaults to `unix:///var/run/dockershim.sock`) to the list of arguments. The `--container-runtime-endpoint` argument could be any [valid CRI](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#container-runtimes).

Also, we can eliminate `--network-plugin=cni` as it's a deprecated argument.

The final file should look like this:

```shell
KUBELET_KUBEADM_ARGS="--container-runtime=remote --container-runtime-endpoint=unix:///run/containerd/containerd.sock --pod-infra-container-image=k8s.gcr.io/pause:3.6"
```

Reload and restart `kubelet` with:

```shell
sudo systemctl daemon-reload && sudo systemctl restart kubelet
```

Check if it worked with `sudo systemctl status kubelet`.

```shell
● kubelet.service - kubelet: The Kubernetes Node Agent
     Loaded: loaded (/lib/systemd/system/kubelet.service; enabled; vendor preset: enabled)
    Drop-In: /etc/systemd/system/kubelet.service.d
             └─10-kubeadm.conf
     Active: active (running) since Sun 2021-12-12 21:14:07 UTC; 4s ago
```

Aaaaay! 🎉🎉🎉 Let's check our cluster now. It might take a few minutes for everything to return to 100% running.

```shell
$ kubectl get nodes
NAME        STATUS   ROLES                  AGE     VERSION
ubu-servr   Ready    control-plane,master   3h37m   v1.24.0-alpha.1

$ kubectl get pods -A
NAMESPACE     NAME                                       READY   STATUS    RESTARTS   AGE
default       echo-server-648d5dd78-76x95                1/1     Running   2          131m
default       echo-server-648d5dd78-gw4w4                1/1     Running   2          131m
default       echo-server-648d5dd78-n27vs                1/1     Running   2          131m
kube-system   calico-kube-controllers-647d84984b-247k2   1/1     Running   4          3h35m
kube-system   calico-node-shq29                          1/1     Running   4          3h35m
kube-system   coredns-64897985d-75jsz                    1/1     Running   4          3h38m
kube-system   coredns-64897985d-ws4rb                    1/1     Running   4          3h38m
kube-system   etcd-ubu-servr                             1/1     Running   5          3h38m
kube-system   kube-apiserver-ubu-servr                   1/1     Running   2          48m
kube-system   kube-controller-manager-ubu-servr          1/1     Running   2          47m
kube-system   kube-proxy-wzrnw                           1/1     Running   2          47m
kube-system   kube-scheduler-ubu-servr                   1/1     Running   2          47m
```

If curious, we can check that Docker is "off" with:

```shell
$ service docker status
● docker.service - Docker Application Container Engine
     Loaded: loaded (/lib/systemd/system/docker.service; enabled; vendor preset: enabled)
     Active: inactive (dead) since Mon 2021-12-13 02:41:02 UTC; 5min ago
TriggeredBy: ● docker.socket
       Docs: https://docs.docker.com
   Main PID: 6451 (code=exited, status=0/SUCCESS)
```

Let's try a new workload to ensure we're able to pull, run, and route traffic.

```shell
kubectl create deployment nginx \
--image=nginx --replicas=2

kubectl port-forward --address 0.0.0.0 deployment/nginx 8080:80
```

Open a browser and navigate to: `YOUR_NODE_IP:8080`

![](/img/dockershim-kubernetes-v1.24-nginx.jpg)

It works in the browser too! My cluster is now healthy and running the latest version of Kubernetes without dockershim.

Let's see if it can survive a reboot.

```shell
sudo shutdown -r now
```

Output (after logging back in):

```shell
kubectl get pods -A

NAMESPACE     NAME                                       READY   STATUS    RESTARTS      AGE
default       echo-server-648d5dd78-dxxww                1/1     Running   2 (61s ago)   159m
default       echo-server-648d5dd78-fs96h                1/1     Running   2 (61s ago)   159m
default       echo-server-648d5dd78-zznwg                1/1     Running   2 (61s ago)   159m
default       nginx-85b98978db-lw4gd                     1/1     Running   1 (61s ago)   5m39s
default       nginx-85b98978db-rkcjb                     1/1     Running   1 (61s ago)   5m39s
kube-system   calico-kube-controllers-647d84984b-cmmcn   1/1     Running   3 (61s ago)   160m
kube-system   calico-node-96x94                          1/1     Running   2 (61s ago)   160m
kube-system   coredns-65dbc9f747-96l8j                   1/1     Running   2 (61s ago)   83m
kube-system   coredns-65dbc9f747-lk7qr                   1/1     Running   2 (61s ago)   83m
kube-system   etcd-ubu-servr                             1/1     Running   2 (61s ago)   84m
kube-system   kube-apiserver-ubu-servr                   1/1     Running   2 (61s ago)   84m
kube-system   kube-controller-manager-ubu-servr          1/1     Running   2 (61s ago)   83m
kube-system   kube-proxy-55mhv                           1/1     Running   2 (61s ago)   83m
kube-system   kube-scheduler-ubu-servr                   1/1     Running   2 (61s ago)   83m
```

Yay! It all came back up. It took a couple of minutes for everything to start running again.

Now for the final test, let's delete `docker-ce` & `docker-cli`.

```shell
sudo apt remove docker-ce docker-ce-cli
```

After removing the packages, it wouldn't hurt to reboot again just for a sanity check. When I did this on my machine, everything came back fine.

## How do I manage images without the Docker CLI?

It might not be obvious, but when we removed `docker-ce-cli`, we lost the ability to `docker` `push`/`pull`/`tag`/`build` containers.

Considering `containerd` is a CRI, there is no included support for building container images, only running them. This is a good thing. Keep your builds in your build system and your runtimes on your nodes 😃.

I get it, though; as we hack on our demo cluster, you might want to build and run custom images.

If you need light oversight on your containers, `ctr` is a command-line client shipped as part of the containerd project. It can do basic `pull`/`tag`/`push` commands and more. For example:

```shell
sudo ctr --namespace k8s.io container ls
```

Or

```shell
$ sudo ctr --namespace k8s.io images -h
NAME:
   ctr images - manage images

USAGE:
   ctr images command [command options] [arguments...]

COMMANDS:
   check       check that an image has all content available locally
   export      export images
   import      import images
   list, ls    list images known to containerd
   mount       mount an image to a target path
   unmount     unmount the image from the target
   pull        pull an image from a remote
   push        push an image to a remote
   remove, rm  remove one or more images by reference
   tag         tag an image
   label       set and clear labels for an image

OPTIONS:
   --help, -h  show help
```

Ivan Velichko has [an excellent overview of the `ctr` commands](https://iximiuz.com/en/posts/containerd-command-line-clients/). 

The containerd team is working on a CLI tool closer with feature parity to `docker` called `nerdctl`. You can read more about it in their GitHub repo: https://github.com/containerd/nerdctl.

With `nerdctl`, you can build containers on a containerd CRI.

## Alternatives

There are other, more mature, replacements for the Docker CLI, such as:

- [podman](https://podman.io/) (Manage pods, containers, and container images.)
    - `alias docker=podman`
- [Buildah](https://buildah.io/) (A tool that facilitates building OCI container images.)
- [ko](https://github.com/google/ko) (A simple, fast container image builder for Go applications.)

## Conclusion

This change is going to impact a lot of folks. The good news is, there are A LOT of options for how you specifically chose to deal with this.

If you don't want to drop Docker, look for upcoming instructions on using the [officially maintained](https://www.mirantis.com/blog/the-future-of-dockershim-is-cri-dockerd/) `cri-docker` dockershim replacement. The steps are similar to what we did, only replace the container-runtime-endpoint with `--container-runtime-endpoint=/var/run/cri-docker.sock`.

Also, this might be an opportunity to explore [other open source CRI's](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#container-runtimes).

Whatever happens, don't let this change catch you by surprise! The Kubernetes community values your feedback. Start testing now and continue testing throughout the release cycle.