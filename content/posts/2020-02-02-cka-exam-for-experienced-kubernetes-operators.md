---
title: "Passing The CKA Exam For Experienced Kubernetes Operators"
subtitle: "Tips and tricks to help you pass confidently"
summary: "For experienced operators wanting to advance their Kubernetes journey by getting certified"
date: 2020-02-02
lastmod: 2020-02-02
#publishDate: You only need to specify this option if you wish to set date in the future but publish the page now.
featured: false
draft: false
authors:
- jimangel
tags:
- kubernetes
- cncf
categories: []

cover:
  image: /img/cka-exam-featured.jpg

slug: "cka-exam-for-experienced-kubernetes-operators"
---

First, let me clarify; this is not a beginner's guide. There are plenty of resources available for beginners:

* [On Google](https://www.google.com/search?q=cka+exam+tips)
* [On Medium](https://medium.com/search?q=cka%20exam%20tips)
* [Curated resources in a Google Doc](https://docs.google.com/spreadsheets/d/1l_p7dzmBO_fRQ5p3lp0PvaCBi7sOfqCOoCdj9vI6MZU)

This post is for experienced operators who want to advance their Kubernetes journey by getting certified.

I have supported Kubernetes at scale and in production since 2018. I can run `kubectl` commands in my sleep and extinguish the strangest of kube-fires. The one thing I didn't have was my CKA certificate - a hands-on practical exam created by the CNCF.

In February 2020, I passed my CKA exam with a **96%**, and here's how I did it.

{{< notice warning >}}
On September 1st, 2020, the CNCF is [refreshing the exam content](https://training.linuxfoundation.org/cka-program-changes-2020/). Older guides, including the information below, might not accurately reflect the current state of the CKA exam.
{{< /notice >}}

## Calm the noise

There's SO MUCH information out there; it's easy to get overwhelmed. I found myself asking questions like:

* Do I need to do Kelsey Hightower's [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) *again?* (no)
* Do I truly know the ins and outs of Deployments, Services, and Storage?
* How strict will the proctor be about my room and desk?
* Can I take notes during the exam? (yes, browser-based)
* How will I interact with the clusters in the exam?
* How will I deal with YAML manifests?
* Is 3 hours enough time? (yes)

![going crazy](/img/cka-exam-dizzy.gif#center)

It turns out, KTHW is less relevant if you already have experience debugging clusters. Don't doubt what you already know about Kubernetes.

The proctoring was very fair and not nearly as intimidating as I thought. I had to pan my camera around the room to show that there were no additional electronics, phones, people, etc. I did have some audio gear and mics on the desk that caused no problems. (They are watching you on the webcam the whole time, so there's that too)

![My Desk](/img/cka-exam-my-desk.jpeg)

The proctor also made me open up Task Manager to prove no other apps were running. All interactions with the proctor were through a chat window, and there were easy controls to interact with them.

As far as interacting with clusters - almost anything is fair game. Your terminal access will be browser based. **Every question will have the appropriate `kubectl config use-context` command at the top.**

Each of the 24 questions will contain tasks. The exam doesn't care how you accomplish the task; it only cares that you can complete the task. If you're comfortable editing YAML in vim - go for it! Likewise, you can use [kubectl generators](https://kubernetes.io/docs/reference/kubectl/conventions/#generators), copy/paste docs on [k8s.io](https://k8s.io), or even straight up `kubectl edit` on a resource. You can also borrow specs from any resource running in the cluster. I used a lot of `cat << EOF | kubectl apply -f ...` as seen on the Cheat Sheet.

Whatever you do, do what's the most **comfortable** and **fastest.**

That includes aliases. I don't use aliases as much as I should, so I felt like remembering them would slow me down. I did add in a single [BASH alias](https://kubernetes.io/docs/reference/kubectl/cheatsheet/#bash) (`alias k=kubectl`) for speed's sake. I still found myself typing `kubectl` most of the time.

Old habits die hard.

## How ready are you?

This is a question only you can answer. I bought a couple of online learning courses but had difficulty staying focused. As Kelsey Hightower jokingly said:

> How many times can we talk about pods coming up?

I just wanted to know: **Can I pass this exam?**

Then I hit the jackpot on Udemy. A course that had mock exams that were similar to taking the real exam. The mock exams also had solutions too if I was really stumped.

![major key](/img/cka-exam-major-key.gif#center)

Sign up for [this Udemy course](https://www.udemy.com/course/certified-kubernetes-administrator-with-practice-tests/), jump straight to the practice exams, and see how you do. Please don't purchase it at full price, Udemy always has sales making their courses more affordable.

Once complete, use that as your starting point and dive into any areas you struggled on.

## Test-taking tips

 The Kubernetes documentation is your best friend. Know how to search and find each exam area in the docs. More specifically, the two most important documents are:

 - The `kubectl` [Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

 > Tip: When grasping for straws on a question, try to `Ctrl+F` search the cheatsheet for a keyword.

 - The `kubectl` [Reference Docs](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands) 

 > Tip: When using kubectl to do anything, there are complete examples in the reference docs, including arguments.

You can use bookmarks during the exam; however, I mainly used the two links above 90% of the time. It never hurts to have more bookmarks handy. An example of my partial bookmark bar:

![bookmarks](/img/cka-exam-bookmarks.png#center)

Since it's not multiple choice, there was no way for me to know which questions I completed. As a result, I started to track my progress in the browser-based notepad with the following format: `Question Number - My Confidence - Weight`

```shell
1 - 100% - 2%
2 - 100% - 4%
3 - skipped, about XYZ, come back - 8%
4 - 75% - 4%
5 - 100% - 8%
```

The far right column will add up to 100% at the end. This way, I had a rough idea of when I was close to the passing mark of 74%.

As an experienced operator, you will know when you have a question 100% because you can validate that the task is complete/present/working.

> Note: When I exited the exam, I had all questions marked as 100% "confidence" as correct. I was wrong for at least 4 of those percentage points, haha.

Lastly, don't forget to read the [FAQ](https://www.cncf.io/certification/cka/faq/), more specifically, the [browser compatibility check tool](https://www.examslocal.com/ScheduleExam/Home/CompatibilityCheck).

<!--adsense-->

## Curve balls

I can't go into details about the actual content of the exam, but make sure you have experience in the following areas:

- Using the [etcdctl command](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/). Specifically with the cluster SSL certificates. You should be able to do things with this CLI in your sleep.

- Troubleshooting `systemd` and `kubelet`. Knowing how to fix things in a way that will survive reboots. 

- Using `kubeadm` to [bootstrap a cluster](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/) from scratch.

- How [static / mirror pods](https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/) work and how to configure and debug them. Try to create a static pod folder in a place other than `/etc/kubernetes/manifests`.

## Final thoughts

I spent my first pass focusing on completion, tracking, and speed. If I didn't know, I would mark the question to revisit.

Around the 2-hour mark, I was done with what I "knew" or grabbed from the docs. I felt confident about passing and spent the remaining hour returning to any incomplete questions, starting with the heavier-weighted ones.

I ended up completing the exam with 15 minutes to spare. Then I waited, and waited, and. waited.

![waiting](/img/cka-exam-wait.gif#center)

When you finish, you'll receive an email saying it takes up to 36 hours to get the results. I received mine around the 32-hour mark. I probably DDoSed the CNCF portal with my obsessive checking. While I felt good about it... it's not over until you get the results.

I hope this helps you! Good luck, and feel free to ask any questions!