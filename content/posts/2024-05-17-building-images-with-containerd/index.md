---
title: "Building Images with containerd"
date: 2024-05-17
description: "Learn how to easily build container images on systems running containerd using nerdctl and buildkit."
summary: "This post provides a concise tutorial on building container images using nerdctl and buildkit on containerd-based systems."
tags:
- containers
- containerd
- nerdctl
- buildkit
keywords:
- containerd
- nerdctl
- buildkit
- containers
- building images
- container images
draft: false
slug: "building-images-with-containerd"
---

{{< notice warning >}}
This post may contain inaccuracies and partial information or solutions.

To reduce my backlog of docs, I've decided to publish my nearly completed drafts assisted by AI.

I wrote most of the following content but used generative AI to format, organize, and complete the post. I'm sure some tone is lost along the way.

Leave a comment if you find any issues!
{{< /notice >}}

_(originally created **Feb 24th 2024**)_

## Introduction

Since Kubernetes v1.23, when it [switched from using Docker](https://kubernetes.io/docs/tasks/administer-cluster/migrating-from-dockershim/change-runtime-containerd/) as the container runtime to containerd. I found myself interacting with more machines with containerd and without Docker.

This means I had to learn some new tricks for building, inspecting, and using containers on systems without Docker.

This guide will walk you through the simple steps to build container images on a system using containerd as the container runtime.

## Prerequisites

We'll need 2 tools to help us out:
- `nerdctl` is aspiring to be a drop-in replacement for the `docker` CLI (`alias docker='nerdctl'`).
- `buildkit` an OCI compliant toolkit for building container images used by `docker build` and `nerdctl build` behind the scenes.

We'll use `nerdctl` to interact with `containerd` and `buildkit` to run the build steps for creating new containers.

`nerdctl` is a command line utility that is executed per-use and `buildkit` is a binary that runs in the background and works with the container runtime.


## Steps

Execute the following steps on the host running containerd workloads.

Install nerdctl:

```bash
# check the latest release https://github.com/containerd/nerdctl/releases
wget https://github.com/containerd/nerdctl/releases/download/v1.2.0/nerdctl-1.2.0-linux-amd64.tar.gz
tar -xvf nerdctl-1.2.0-linux-amd64.tar.gz
sudo mv nerdctl /usr/local/bin/
```

Get the buildkit binaries:

```bash
# check the latest release https://github.com/moby/buildkit/releases
wget https://github.com/moby/buildkit/releases/download/v0.12.5/buildkit-v0.12.5.linux-amd64.tar.gz
tar -xvf buildkit-v0.12.5.linux-amd64.tar.gz
export PATH=$PATH:$(pwd)/bin
sudo ln -s $(pwd)/bin/buildctl /usr/local/bin/buildctl
```

Launch buildkitd in the background:

```bash
sudo buildkitd &
```

3. Create a Dockerfile for your image. Simple example:

```Dockerfile
FROM debian:buster-slim

RUN apt-get update && apt-get install -y curl

CMD ["curl", "-s", "https://example.com"]
```

4. Build the container image:

```bash
sudo nerdctl build -t myimage:v1 .
```

5. Check the size of the built image:

```bash
sudo nerdctl images
```

6. Run a container using the image:

```bash
sudo nerdctl run --rm myimage:v1
```

And that's it! You've now built and run a container image using nerdctl and buildkit on a containerd-based system.

## Conclusion

Building images with containerd is straightforward thanks to tools like nerdctl and buildkit. By following the simple steps outlined in this guide, you can quickly build optimized container images on your containerd.

## Extras

Want to use nerdctl with GPUs?

```
sudo nerdctl run -it --rm --gpus all docker.io/library/cuda-vector-add:latest
```