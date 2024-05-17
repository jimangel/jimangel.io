---
title: "Easily Limit NVIDIA GPU Power Draw with systemd"
date: 2024-05-17
description: "A simple guide on setting power limits for NVIDIA GPUs on Linux using systemd"
summary: "Learn how to limit the power draw of NVIDIA GPUs on Linux automatically at boot using systemd."
tags:
- linux
- nvidia
- gpu
- systemd
- power-management
keywords:
- NVIDIA GPU
- power limit
- systemd
- Linux
- boot script
- multi-GPU
slug: "limit-nvidia-gpu-power-draw-with-systemd"
---

{{< notice warning >}}
This post may contain inaccuracies and partial information or solutions.

To reduce my backlog of docs, I've decided to publish my nearly completed drafts assisted by AI.

I wrote most of the following content but used generative AI to format, organize, and complete the post. I'm sure some tone is lost along the way.

Leave a comment if you find any issues!
{{< /notice >}}

_(originally created **Dec 8th 2023**)_

If you're running NVIDIA GPUs on Linux, especially in a multi-GPU setup, managing their power draw is crucial for efficiency and stability. Manually setting power limits every time you boot can be tedious. Luckily, we can automate this using systemd.

First, let's check the current power settings of your GPU. Run the following command:

```bash
sudo nvidia-smi -q -d POWER
```

This will show you the current power limits and other details about your GPU's power management. Note down the `Current Power Limit` and `Max Power Limit` for later use.

Next, we need to create a script that sets the power limit for your GPU. This script will enable persistence mode and set the desired power limit.

1. Create the script:

```bash
# This script enables persistence mode and sets the power limit to 240 watts for GPU 0.
sudo tee /usr/local/bin/set-nvidia-power-limit.sh > /dev/null <<EOF
#!/bin/bash
/usr/bin/nvidia-smi -pm ENABLED
/usr/bin/nvidia-smi -pl 270 -i 0,1
EOF
```

Adjust the power limit value and GPU index (`-i 0`) as needed. For example, if you had multiple GPUs you can comma-separate them (`-i 0,1,2,3`)

2. Make the script executable:

```bash
sudo chmod +x /usr/local/bin/set-nvidia-power-limit.sh
```

Now, we need to create a systemd service that runs this script at boot.

3. Create the systemd service file:

```bash
sudo tee /etc/systemd/system/nvidia-tdp.service > /dev/null <<EOF
[Unit]
Description=Set NVIDIA power limit

[Service]
Type=oneshot
ExecStart=/usr/local/bin/set-nvidia-power-limit.sh
EOF
```

This service will execute the script we created.

4. Create the systemd timer file:

```bash
sudo tee /etc/systemd/system/nvidia-tdp.timer > /dev/null <<EOF
[Unit]
Description=Run NVIDIA power limit service after boot

[Timer]
OnBootSec=10

[Install]
WantedBy=timers.target
EOF
```

The timer ensures that the service runs 10 seconds after the system boots.

Enable and start the timer:

```bash
sudo systemctl enable --now nvidia-tdp.timer
```

This command enables the timer and starts it immediately.

Now, your GPU(s) will have their power limits set automatically 10 seconds after each boot. You can check the status anytime with:

```bash
sudo systemctl status nvidia-tdp.service
```

Output similar to:

```bash
May 17 14:51:30 node2 systemd[1]: Starting Set NVIDIA power limit...
May 17 14:51:30 node2 set-nvidia-power-limit.sh[1777373]: Enabled persistence mode for GPU 00000000:01:00.0.
May 17 14:51:30 node2 set-nvidia-power-limit.sh[1777373]: Enabled persistence mode for GPU 00000000:29:00.0.
May 17 14:51:30 node2 set-nvidia-power-limit.sh[1777373]: All done.
May 17 14:51:30 node2 set-nvidia-power-limit.sh[1777374]: Power limit for GPU 00000000:01:00.0 was set to 270.00 W from 450.00 W.
May 17 14:51:30 node2 set-nvidia-power-limit.sh[1777374]: Power limit for GPU 00000000:29:00.0 was set to 270.00 W from 450.00 W.
May 17 14:51:30 node2 set-nvidia-power-limit.sh[1777374]: All done.
May 17 14:51:30 node2 systemd[1]: nvidia-tdp.service: Deactivated successfully.
May 17 14:51:30 node2 systemd[1]: Finished Set NVIDIA power limit.
```

And view the current power limits with:

```bash
sudo nvidia-smi -q -d POWER
```

By automating GPU power management with systemd, you can optimize performance, efficiency, and avoid issues like thermal throttling. This straightforward setup will help you keep your NVIDIA GPUs running optimally in your Linux environment!