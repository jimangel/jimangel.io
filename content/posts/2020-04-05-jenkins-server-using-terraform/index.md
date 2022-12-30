---
title: "Low-Cost Public Jenkins Server using Terraform and DigitalOcean"
description: "How to deploy a Jenkins server on DigitalOcean with Terraform"
subtitle: "Deploy a public Jenkins server on a $5 DigitalOcean Droplet with `terraform apply`."
summary: "Deploy a public Jenkins server on a $5 DigitalOcean Droplet with `terraform apply`."
date: 2020-04-05
lastmod: 2020-04-05
#publishDate: You only need to specify this option if you wish to set date in the future but publish the page now.
featured: false
authors:
- jimangel
tags:
- jenkins
- automation
- digitalocean
- terraform
categories: []
keywords:
- namecheap terraform
- jenkins
- automation
- digitalocean
- terraform

cover:
  image: "img/jenkins-server-featured.jpg"
  alt: "large colorful plumbing pipes to represent pipelines"

slug: "jenkins-server-using-terraform"
---

Love it or hate it, Jenkins isn't going anywhere. Jenkins is the leading open source automation server and supports building, deploying, and automating projects.

My goal is to automate the infrastructure and setup of Jenkins, so my time is spent on *using* Jenkins rather than setting it up. I also want this tutorial to be affordable, so everyone can get started with little financial investment.

By using Terraform, I can build and destroy the entire stack with a single command.

## What you'll end up with 

- DigitalOcean Droplet
  - nginx reverse proxy
  - Jenkins server
- No Jenkins setup wizard
- Automated configuration (via [Jenkins Configuration as Code](https://jenkins.io/projects/jcasc/))
  - plugins (via [script](https://github.com/jimangel/terraform-jenkins/blob/master/install-jenkins.sh#L59))
  - pipelines
- A custom domain with HTTPS (using Let's Encrypt)

![](/img/jenkins-server-jenkins-arch.jpg)

## Tools and infrastructure used

### Terraform

Terraform is a utility developed by HashiCorp that enables you to treat Infrastructure as Code (IaC). Feed it config files, and it will manage any cloud, infrastructure, or service.

### Digital Ocean

Digital Ocean is a cloud provider with flat-rate billing. This tutorial can be adapted to use any cloud provider, but I enjoy the simple billing DigitalOcean offers.

## Before you begin

Before running Terraform, you need to set up a few things. The good news is that you'll never have to do it again once complete.

### Buy a domain

For HTTPS certificates, you need a fully qualified domain name (FQDN) that is publicly available.

Use your favorite domain registrar to purchase a domain. For this tutorial, I'm using [Namecheap](https://www.namecheap.com/).

![](/img/jenkins-server-jenkins-domain.jpg)

{{< notice note >}}
This tutorial does not support subdomains (ex: **jenkins**.myserver.com).
{{< /notice >}}

### Use DigitalOcean's nameservers

Using DigitalOcean for DNS means there is no need to configure multiple providers in Terraform. Update the nameservers in Namecheap to use DigitalOcean for DNS.

Under **Manage** domains in Namecheap:

![](/img/jenkins-server-digitalocean-ns.jpg)

If you're following along, use these exact nameservers:

```shell
ns1.digitalocean.com
ns2.digitalocean.com
ns3.digitalocean.com
```

[DNS propagation](https://www.namecheap.com/support/knowledgebase/article.aspx/9622/10/dns-propagation--explained) takes up to 24 hours. However, in my testing, it usually is faster. To validate the nameserver records are public, check the domain at [who.is](https://who.is).

![](/img/jenkins-server-whois-lookup.jpg)

### Export the domain name

```shell
export DOMAIN="myjenkinsserver.com"
```

### Create DigitalOcean API access token

Navigate to https://cloud.digitalocean.com/account/api/tokens and click **Generate New Token**.

Give the token **write** access.

![](/img/jenkins-server-do-token.jpg)

### Export DigitalOcean API access token

Once created, copy the token for safekeeping and export it as a variable.

```shell
# DigitalOcean personal access token
export DO_PAT="<YOUR TOKEN>"
```

### Install Terraform

Check for later versions: https://releases.hashicorp.com/terraform/

```shell
# set version
export terraformVersion="0.13.2"

# curl the binary
curl -Lo terraform.zip https://releases.hashicorp.com/terraform/${terraformVersion}/terraform_${terraformVersion}_linux_amd64.zip

# unpack and make executable
unzip terraform.zip
rm -rf terraform.zip
chmod +x ./terraform
sudo mv ./terraform /usr/local/bin/terraform

# validate
terraform version
```

## Create the infrastructure

Validate the following variables are set (check with `echo $VARIABLE_NAME`):

- `DO_PAT`
- `DOMAIN`

1) Export Terraform variables

    By adding `TF_VAR_` to [variables](https://www.terraform.io/docs/configuration/variables.html) referenced in the Terraform configuration, there is no need to supply it on the command line.

    ```shell
    export TF_VAR_do_token=${DO_PAT}
    export TF_VAR_pub_key=$HOME/.ssh/id_rsa.pub
    export TF_VAR_pvt_key=$HOME/.ssh/id_rsa
    export TF_VAR_domain=${DOMAIN}
    ```

1) Clone Terraform files from GitHub

    ```shell
    git clone https://github.com/jimangel/terraform-jenkins.git
    cd terraform-jenkins
    ```

1) Terraform `init` downloads the needed Terraform providers
    
    ```shell
    terraform init
    ```

1) Dry-run with `plan`
    ```shell
    terraform plan
    ```
1) Deploy with `apply`

{{< notice warning >}}
This part takes ~10 minutes; don't be alarmed if it occasionally hangs
{{< /notice >}}
    
```shell
terraform apply
```

![](/img/jenkins-server-terminal-out.jpg)



## Generate SSL certs and nginx config

Automating SSL with Terraform is a "chicken and egg" problem.

- Terraform can't automatically generate certs on the server without DNS existing
- Terraform can't update DNS before creating the server

There is a way to generate certificates with Terraform using a DNS TXT record challenge, but then I can't use the `certbot` command to renew, configure and update my nginx config automatically. One day I might revisit this.

Until then, you need to run a few commands to generate certs:

```shell
# ssh into the newly created server
ssh root@$(terraform output ip)

# set domain variable
export DOMAIN="myjenkinsserver.com"

# set email
export EMAIL="email@gmail.com"

# generate certs and automatically configure nginx
sudo certbot --nginx --manual-public-ip-logging-ok --no-eff-email --agree-tos --rsa-key-size 4096 --email ${EMAIL} --redirect -d "${DOMAIN}" -d "www.${DOMAIN}"
```

While you're logged into the server, grab the admin password:

```shell
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

5a298e2v1r23erbt0wreb
```

## That's it! Let's check it out

![](/img/jenkins-server-webpage-done.jpg)

The credentials for initial login are:
- User: admin
- Password: `/var/lib/jenkins/secrets/initialAdminPassword`

## Clean up with `destroy`

```shell
terraform destroy
```

## `terraform apply` deep dive

When `terraform apply` runs, it checks the required variables and providers from `provider.tf`. Next, it uses `www-jenkins.tf` & `domain.tf` to build the server and update DNS, respectively.

```shell
├── domain.tf
├── install-jenkins.sh
├── install-plugins.sh
├── jenkins.yaml
├── nginx.tpl
├── outputs.tf
├── provider.tf
├── versions.tf
└── www-jenkins.tf
```

`www-jenkins.tf` specifies the DigitalOcean droplet parameters and imports our SSH keys.

`www-jenkins.tf` also copies the `install-jenkins.sh`, `install-plugins.sh`, and `jenkins.yaml` files to the newly created server.

`install-jenkins.sh` is a bash script that does all of the configuration on the server.

- updates packages
- installs Docker (for pipelines)
- installs Java
- installs Jenkins
- installs nginx
    - disables TLS v1 & v1.1
    - enables TLS v1.2 & v1.3
- installs certbot
- enables swap
- installs plugins via `install-plugins.sh`
- force skips the Jenkins setup wizard
- moves `jenkins.yaml` [JCasC](https://jenkins.io/projects/jcasc/) to be used
- restarts Jenkins

{{< notice note >}}
`install-jenkins.sh` should be an Ansible playbook and not part of Terraform. Terraform is for infrastructure and not configuration management. More information is below about what problems this causes.
{{< /notice >}}

`install-plugins.sh` was copied from a [gist](https://gist.githubusercontent.com/micw/e80d739c6099078ce0f3/raw/33a21226b9938382c1a6aa68bc71105a774b374b/install_jenkins_plugin.sh) I found. You can automate the configuration of a Jenkins server with the [Jenkins Configuration as Code](https://jenkins.io/projects/jcasc/) plugin; however, JCasC is not present by default.

`jenkins.yaml` is the heart of our configuration used by [Jenkins Configuration as Code](https://jenkins.io/projects/jcasc/). **If you want to configure Jenkins or add pipelines, do it here.**

`nginx.tpl` generates a `nginx.conf` file based on your domain variable. This is needed to support custom domains.

Terraform uses `outputs.tf` to capture information that is referenced later such as the server public IP (`terraform output ip`).

`versions.tf` validates your version of Terraform before continuing (`>= 0.12`)


## Costs

My out-of-pocket cost is $9.06 for the domain and $5/mo for my server.

DigitalOcean offers incremental billing at $0.007/hr, which is good to know if you want to `destroy` everything afterward.

I can also spin up the server, test, and spin it down when done.

## Other thoughts

### Configuration Management

Using `install-jenkins.sh` to configure our Jenkins server is kind of a hack. The problem is, that Terraform can only validate that our infrastructure exists but not if our script is completed successfully.

If `install-jenkins.sh` is modified, and `terraform apply` is run, Terraform says there is nothing to change; since all of the infrastructure *technically* exists. Our only option is to run `install-jenkins.sh` by hand in the server or `terraform destroy` and `terraform apply`.

A better option would be to use Terraform to build our infrastructure and use Ansible to provision Jenkins / nginx. [Geerling's Ansible role](https://github.com/geerlingguy/ansible-role-jenkins) would be perfect for something like this.

### Docker

I mentioned earlier that `install-plugins.sh` is needed since the JCasC plugin is not present by default.

If I had deployed Jenkins using docker instead of the Ubuntu package, I could have [built it with the needed plugins](https://github.com/jenkinsci/docker/#script-usage).

I purposely chose **not** to use Docker given the small server size, and, to be honest, I didn't want to support building custom docker images for this.

### Setup wizard

To skip the initial Jenkins setup wizard, I run a `sed 's/NEW/RUNNING/g'` command to [trick Jenkins](https://github.com/jimangel/terraform-jenkins/blob/master/install-jenkins.sh#L62
) into thinking it's already provisioned.

I'm not sure what impact this will have on upgrades/installs.

### HTTPS

I don't particularly enjoy having to configure the HTTPS portion manually. One option might be to use Terraform and a TXT DNS challenge to get the initial certificates and then use an Ansible playbook to implement Let's Encrypt.

### Existing offerings 

If you're not trying to nerd out on managing infrastructure, there is a managed [CloudBees Jenkins Distribution](https://do.co/2HaL1R4) on DigitalOcean. Although I believe the droplet size needs to be larger, leading to a higher cost.

### Shout out

Shout out to [AutomatingGuy](https://automatingguy.com/2018/09/25/jenkins-configuration-as-code/) for such a great tutorial on using JCasC. Most of my Jenkins config is borrowed from his post.