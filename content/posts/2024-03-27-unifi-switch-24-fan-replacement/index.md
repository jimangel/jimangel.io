---
title: "Replacing the stock fans on UniFi Dream Machine and 24 Port Switch"
date: 2024-03-27
description: "Quieting my homelab by replacing the stock fans in my UniFi Dream Machine and 24 Port PoE Switch with Noctua silent fans"
summary: "A walkthrough on replacing the loud stock fans in UniFi Dream Machine and 24 Port PoE Switch with quiet Noctua fans"
tags:
- unifi
- homelab
- fans
- noctua
- walkthrough
keywords:
- Ubiquiti
- UniFi
- UDM Pro
- USW-24-POE
- Switch 24 PoE Pro  
- fan replacement
- Noctua NF-A4x20 PWM
- Noctua NF-A6x25 PWM
- silent homelab
- noise reduction

draft: false

slug: "UniFi-switch-24-fan-replacement"

---

{{< notice warning >}}
This post may contain inaccuracies and partial information or solutions.

In an effort to reduce my backlog of docs, I've decided to publish my nearly completed drafts assisted by AI.

I wrote most of the following content, but used generative AI to format, organize, and complete the post. I'm sure some tone is lost along the way.

Leave a comment if you find any issues!
{{< /notice >}}

_(originally created **Jan 8th 2021**)_

If you're like me, you may have been disappointed by how loud the stock fans are in both the 24 port PoE switch and the UDM Pro. The noise is tolerable in a dedicated server room, but in a silent bedroom, not so much.

I couldn't find any information online about replacing the fans, so I decided to void my warranty and do it myself. Hopefully this guide helps any other brave souls looking to quiet down their UniFi gear.

## Replacing the Switch 24 PoE Pro Fans

There's 2 fans in the Switch 24 PoE Pro that are standard 40mm in size. I replaced them both with a [Noctua NF-A4x20 PWM](https://noctua.at/en/nf-a4x20-pwm), which is a premium quiet fan.

![](/img/top-view.jpeg)

### Steps

1. Remove the 4 screws on the back of the switch and carefully lift off the top cover. Be careful of the ribbon cable connecting the status LED board.
    ![Noctua NF-A4x20 PWM installed in Switch 24 PoE Pro](/img/wires.jpeg)
1. Unplug the stock fans and remove the screws holding the large plastic encloser in place.
    ![](/img/switch-fans-lifted.jpeg)
1. Install the Noctua fan in the same orientation as the stock fan. Make sure the label is facing up and the wires are routed through the rectangular slot.
    ![](/img/fan-direction.jpeg)
    ![Switch 24 PoE Pro with stock fan removed](/img/switch-fan.jpeg)
1. Use a 3/16th drill bit to widen the plastic holes (see picture)
    ![](/img/larger-hole-mounts.jpeg)
1. Plug in the new fan to validate it works before closing everything up. Note that it takes about 2 minutes for the fan to spin up on boot.

1. Secure the large plastic fan encloser in place
1. Carefully lower the top cover back on, making sure no wires get trapped underneath. It's a tight fit.
1. Replace the 4 screws on the back.

## Replacing the UDM Pro's Fan 

The fan in the UDM Pro is a, single, non-standard size at 60x25mm. I used a [Noctua NF-A6x25 PWM](https://noctua.at/en/nf-a6x25-pwm) as a replacement.

{{< notice warning >}}
If you don't use the drive slot on your UDM Pro, there most likely is no benefit to performing this modification.

The fan being replaced only is active when a hard drive is installed (for UniFi Protect).
{{< /notice >}}

![](/img/udm-glue.jpeg)

(notice the air black plastic air channel along the bottom we'll have to try not to break)

### Steps

1. Remove the 4 screws on the bottom of the UDM Pro and lift off the bottom cover.
1. To get to the fan, we'll need to remove the 6 screws holding the drive chassis in place (large cut-out circles on corners / middle)
    ![Noctua NF-A6x25 PWM installed in UDM Pro](/img/slot-view.jpeg)
    ![](/img/udm-fan-bay.jpeg)
1. Unplug the stock fan and remove the 4 screws holding it in place. The thermal adhesive may have broken, which is fine.
    ![](/img/udm-fan-out.jpeg)
1. Install the Noctua fan in the same orientation. The screw holes won't line up perfectly, but just get them as close as you can.
1. Plug in the new fan and watch it spin* to validate it's working before putting the cover back on.
1. Replace the bottom cover and the 4 screws.

{{< notice note >}}
*You can't fully test noise levels without the HDD installed, as the fan won't spin without it.
{{< /notice >}}

After the mod, there is still some noise coming from the PSU, but the CPU fan noise is greatly reduced. Overall it's a big improvement!






Hopefully this guide was helpful. Enjoy your newly silent homelab!