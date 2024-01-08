---
# not too long or too short (think G-search)
title: "Using GCP Workload Identity with local Kubernetes"
date: 2023-12-28
# description is usually what's used in a google snippet
# informs and interests users with a short, relevant summary of what a particular page is about.
# They are like a pitch that convince the user that the page is exactly what they're looking for.
description: "How to setup workload identity federation to allow workloads, that run on a self-hosted Kubernetes (KinD) cluster, authenticate to Google Cloud."
summary: "A quick intro to using Kubernetes service accounts to authenticate to GCP, preventing the need to store or share service account keys."
tags:
- google cloud
- kubernetes
- workload identity
- kind
keywords:
- GCP
- Google Cloud Platform
- Kubernetes
- Workload Identity
- IAM
- JWT
- JWKS
- Cloud Identity Management
- Kubernetes Service Accounts
- Google Service Accounts
- Cloud Security
- Token Validation
- Baremetal
- KinD Cluster
- Access Management
- Cloud Computing
- Google Cloud IAM
- Kubernetes Integration
- Identity Federation
- Google Cloud Authentication

# !! DON'T FORGET: https://medium.com/p/import
# !! DON'T FORGET: https://medium.com/p/import
draft: false
# !! DON'T FORGET: https://medium.com/p/import
# !! DON'T FORGET: https://medium.com/p/import

#comments: false
# from https://unsplash.com/photos/ute2XAFQU2I
cover:
    image: "img/workload-id-kind.png"
    alt: "AI generated colorful artwork of a homelab and wires reaching the clouds in an abstract way" # alt text
    #caption: ""
    relative: true
# check config.toml for some of the default options / toggles

# contain keywords relevant to the page's topic, and contain no spaces, underscores or other characters. You should avoid the use of parameters when possible, as they make URLs less inviting for users to click or share. Google's suggestions for URL structure specify using hyphens or dashes (-) rather than underscores (_). Unlike underscores, Google treats hyphens as separators between words in a URL.
slug: "gcp-workload-id-baremetal-kubernetes"  # make your URL pretty!

---

I use local Kubernetes clusters at home and find that I can get around most limitations compared to cloud offerings.

Yet, there are many times that I wish my local Kubernetes clusters could use GKE Workload Identity.

Workload Identity allows workloads (pods) to run with a Kubernetes service account that can be granted GCP IAM permissions. Meaning that I don't need to download GCP Service Account keys or create hacky workarounds to authenticate to GCP.

Using Workload Identity Federation, you can bring Workload Identity to any cluster. To prove this out, we'll use a local Kubernetes cluster in Docker via [KinD](https://kind.sigs.k8s.io/).

## Before getting started

I highly suggest reading the [official docs](https://cloud.google.com/iam/docs/workload-identity-federation-with-kubernetes#mappings-and-conditions) as this is a complimentary walkthrough.

Enable services on the project:

```
gcloud services enable iam.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable iamcredentials.googleapis.com
gcloud services enable sts.googleapis.com
```

Begin with a local Kubernetes cluster:

```
# go install sigs.k8s.io/kind@v0.20.0
kind create cluster
```

## Create the workload identity pool and provider

We need to know the issuer for later when we create the workload-identity-pool provider.

```
kubectl get --raw /.well-known/openid-configuration | jq -r .issuer
```

Output:

```
https://kubernetes.default.svc.cluster.local
```

Next get the  JSON Web Key Set (JWKS).

The JWKS endpoint in Kubernetes provides a way to obtain public keys used to verify the signatures of tokens, like JWTs, issued by the cluster.

This is crucial for systems integrating with Kubernetes for authentication and authorization, ensuring that they can validate tokens.

The security of JWKS lies in its role in the token validation process, helping prevent unauthorized access by ensuring tokens are genuine and issued by the cluster.

```
# create a new empty directory to create these files in
mkdir ~/k8s-setup-kind-wid
cd ~/k8s-setup-kind-wid
kubectl get --raw /openid/v1/jwks > cluster-jwks.json
```
If you inspect the created `cluster-jwks.json` file, you'll notice the following fields:

- "keys": An array of key objects.

Each key object contains:

- "use": The intended use of the key ("sig" indicates it's used for signing).
- "kty": The key type ("RSA" indicates an RSA key).
- "kid": A unique identifier for the key.
- "e": The exponent for an RSA public key ("AQAB" is a common exponent value).

> "AQAB" as an exponent in the context of an RSA public key is the base64 encoding of the standard exponent 65537. In RSA, a public key is defined by a modulus and an exponent. The number 65537 is widely used as the exponent because it strikes a balance between security and computational efficiency.

This structure allows systems to retrieve the public keys for verifying JWTs issued by the issuer of this JWKS.

## Create a new workload identity pool

```bash
gcloud iam workload-identity-pools create custom-baremetal-pool \
--location="global" \
--description="BYO-workload identity demo" \
--display-name="Bare Metal Cluster Pool"
```

Output:

```bash
Created workload identity pool [custom-baremetal-pool].
```

### Add the Kubernetes cluster as a workload identity pool provider and upload the cluster's JWKS

We'll use more attributes to provide more granular information to GCP. Combined with attribute conditions to restrict the origin or principals that can use Workload Identity. A quick refresher on the two fields from the docs: 

> You can map additional attributes. You can then refer to these attributes when granting access to resources.
>
> Attribute conditions are CEL expressions that can check assertion attributes and target attributes. If the attribute condition evaluates to true for a given credential, the credential is accepted. Otherwise, the credential is rejected.
>
> You can use an attribute condition to restrict which Kubernetes service accounts can use workload identity federation to obtain short-lived Google Cloud tokens.

```bash
gcloud iam workload-identity-pools providers create-oidc kind-cluster-provider \
--location="global" \
--workload-identity-pool="custom-baremetal-pool" \
--issuer-uri="https://kubernetes.default.svc.cluster.local" \
--attribute-mapping="google.subject=assertion.sub,attribute.namespace=assertion['kubernetes.io']['namespace'],attribute.service_account_name=assertion['kubernetes.io']['serviceaccount']['name'],attribute.pod=assertion['kubernetes.io']['pod']['name']" \
--attribute-condition="assertion['kubernetes.io']['namespace'] in ['backend', 'monitoring']" \
--jwk-json-path="cluster-jwks.json"
```

Output:

```bash
Created workload identity pool provider [kind-cluster-provider].
```

## Authenticate a Kubernetes workload

You must perform these steps once for each Kubernetes workload that needs access to Google Cloud.

### Create a Google Service Account and a Kubernetes Service account to use

You need a Google Service Account that allows impersonation via a Kubernetes service account for all the "magic" to happen.

```bash
gcloud iam service-accounts create gcp-sa-for-kind

# now for k8s
kubectl create namespace monitoring
kubectl create serviceaccount k8s-sa-for-kind --namespace monitoring
```

> Grant the IAM service account access to resources that you want the Kubernetes workload to access.

```bash
# TBD - just testing for now but here's where you could grant IAM to various GCP resources
```

### Allow access between the k8s service account and gcp

Grant the Workload Identity User role (`roles/iam.workloadIdentityUser`) to the external identity of the Kubernetes service account

```bash
export PROJECT_NUMBER=$(gcloud projects describe $(gcloud config get-value project) --format='value(projectNumber)')
export SERVICE_ACCOUNT_EMAIL=$(gcloud iam service-accounts list --filter="name:gcp-sa-for-kind" --format='value(email)')
export POOL_ID=$(gcloud iam workload-identity-pools list --location=global --format="value(name.basename())")
export SUBJECT="system:serviceaccount:monitoring:k8s-sa-for-kind"

# SEE BELOW, CAN USE ALTERNATE PRINCIPAL/PRINCIPALSETS
gcloud iam service-accounts add-iam-policy-binding ${SERVICE_ACCOUNT_EMAIL} \
--role=roles/iam.workloadIdentityUser \
--member="principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/subject/${SUBJECT}"
```

> SUBJECT: The expected value for the attribute that you've mapped to `google.subject`, for example `system:serviceaccount:NAMESPACE:KSA_NAME``.

## Deploy a testing pod workload that runs gcloud

First create a credential file to be uploaded to Kubernetes as a config map. The config map is mounted in pods to instruct workloads how to authenticate as the Workload Identity service account. From the docs:

> The credential configuration file lets the Cloud Client Libraries, the gcloud CLI, and Terraform determine the following:
>
>- Where to obtain external credentials from
>- Which workload identity pool and provider to use
>- Which service account to impersonate

### Create a credential configuration file:

```bash
export PROVIDER_ID=$(gcloud iam workload-identity-pools providers list --workload-identity-pool=${POOL_ID} --location=global --format="value(name.basename())")

gcloud iam workload-identity-pools create-cred-config \
projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID} \
--service-account=${SERVICE_ACCOUNT_EMAIL} \
--credential-source-file=/var/run/service-account/token \
--credential-source-type=text \
--output-file=credential-configuration.json
```

Output:

```bash
Created credential configuration file [credential-configuration.json].
```

You may inspect the file:

```bash
cat credential-configuration.json
```

Output:

```bash
{
  "type": "external_account",
  "audience": "//iam.googleapis.com/projects/########/locations/global/workloadIdentityPools/custom-baremetal-pool/providers/kind-cluster-provider",
  "subject_token_type": "urn:ietf:params:oauth:token-type:jwt",
  "token_url": "https://sts.googleapis.com/v1/token",
  "credential_source": {
    "file": "/var/run/service-account/token",
    "format": {
      "type": "text"
    }
  },
  "service_account_impersonation_url": "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/gcp-sa-for-kind@project_name.iam.gserviceaccount.com:generateAccessToken"
}
```

### Import the credential configuration file as a ConfigMap

```bash
kubectl create configmap kind-demo-wid-test \
--from-file credential-configuration.json \
--namespace monitoring
```

Launch a demo workload to authenticate via gcloud automatically using the credentials file.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: example
  namespace: monitoring
spec:
  containers:
  - name: example
    image: google/cloud-sdk:alpine
    command: ["/bin/sh", "-c", "gcloud auth login --cred-file /etc/workload-identity/credential-configuration.json && gcloud auth list && sleep 600"]
    volumeMounts:
    - name: token
      mountPath: "/var/run/service-account"
      readOnly: true
    - name: workload-identity-credential-configuration
      mountPath: "/etc/workload-identity"
      readOnly: true
    env:
    - name: GOOGLE_APPLICATION_CREDENTIALS
      value: "/etc/workload-identity/credential-configuration.json"
  serviceAccountName: k8s-sa-for-kind
  volumes:
  - name: token
    projected:
      sources:
      - serviceAccountToken:
          audience: https://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}
          expirationSeconds: 3600
          path: token
  - name: workload-identity-credential-configuration
    configMap:
      name: kind-demo-wid-test
EOF
```

Output:

```bash
kubectl get pods -n monitoring
NAME      READY   STATUS    RESTARTS   AGE
example   1/1     Running   0          7s
```

Validate with:

```bash
kubectl exec example --namespace monitoring -- gcloud auth print-access-token

# or

kubectl exec example --namespace monitoring -- gcloud config list account

# output
# [core]
# account = gcp-sa-for-kind@gitops-secrets.iam.gserviceaccount.com
# Your active configuration is: [default]
```



## Future updates

I can already sense it... This was a lot of work. I don't want to do this every time I build a new kind cluster.

Good news! Reuse the entire pool with new identities with `gcloud iam workload-identity-pools providers update-oidc`. Full demo:

```bash
mv cluster-jwks.json cluster-jwks.old 
mv credential-configuration.json credential-configuration.old
kind delete cluster

export PROJECT_NUMBER=$(gcloud projects describe $(gcloud config get-value project) --format='value(projectNumber)')
export SERVICE_ACCOUNT_EMAIL=$(gcloud iam service-accounts list --filter="name:gcp-sa-for-kind" --format='value(email)')
export PROVIDER_ID=$(gcloud iam workload-identity-pools providers list --workload-identity-pool=${POOL_ID} --location=global --format="value(name.basename())")
export POOL_ID=$(gcloud iam workload-identity-pools list --location=global --format="value(name.basename())")

kind create cluster

# should still be "https://kubernetes.default.svc.cluster.local"
kubectl get --raw /.well-known/openid-configuration | jq -r .issuer

# get new jwks
kubectl get --raw /openid/v1/jwks > cluster-jwks.json

diff cluster-jwks.json cluster-jwks.old
# they're different!

# update the oidc provider
gcloud iam workload-identity-pools providers update-oidc ${PROVIDER_ID} --location="global" --workload-identity-pool="${POOL_ID}" \
--issuer-uri="https://kubernetes.default.svc.cluster.local" \
--attribute-mapping="google.subject=assertion.sub,attribute.namespace=assertion['kubernetes.io']['namespace'],attribute.service_account_name=assertion['kubernetes.io']['serviceaccount']['name'],attribute.pod=assertion['kubernetes.io']['pod']['name']" \
--attribute-condition="assertion['kubernetes.io']['namespace'] in ['backend', 'monitoring']" \
--jwk-json-path="cluster-jwks.json"

# get new config for k8s configmap
gcloud iam workload-identity-pools create-cred-config \
projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID} \
--service-account=${SERVICE_ACCOUNT_EMAIL} \
--credential-source-file=/var/run/service-account/token \
--credential-source-type=text \
--output-file=credential-configuration.json

diff credential-configuration.json credential-configuration.old
# they're the same! but that's fine, they contain the same instructions!

# create the cluster namespace / test
kubectl create namespace monitoring

# create the new config map
kubectl create configmap kind-demo-wid-test \
--from-file credential-configuration.json \
--namespace monitoring

# create the service account
kubectl create serviceaccount k8s-sa-for-kind --namespace monitoring

# Run the above "example" pod deployment...
# kubectl get pods -n monitoring
# NAME      READY   STATUS    RESTARTS   AGE
# example   1/1     Running   0          7s

kubectl exec example --namespace monitoring -- gcloud auth print-access-token

# Token is returned
```

The same exercise can be done to prove that access is limited per cluster. Follow the same steps without updating the OIDC provider and the container shows `Running` but printing the access token results in:

```bash
ERROR: (gcloud.auth.print-access-token) ("Error code invalid_grant: Error connecting to the given credential's issuer.", '{"error":"invalid_grant","error_description":"Error connecting to the given credential\'s issuer."}')
command terminated with exit code 1
```

Other `update-oidc` commands: https://cloud.google.com/sdk/gcloud/reference/iam/workload-identity-pools/providers/update-oidc

## Additional thoughts

https://cloud.google.com/iam/docs/principal-identifiers - use custom attributes to limit the IAM principals when creating the IAM binding, such as:

```bash
gcloud iam service-accounts add-iam-policy-binding ${SERVICE_ACCOUNT_EMAIL} \
--role=roles/iam.workloadIdentityUser \
--member="principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/subject/${SUBJECT}"
```

This would allow you to do something like:

```bash
--member="principalSet://iam.googleapis.com/locations/global/workforcePools/POOL_ID/attribute.ATTRIBUTE_NAME/ATTRIBUTE_VALUE"
```

Which would allow any member matching those attributes to assume the GCP service account IAM. For example:

```bash
--attribute-mapping="google.subject=assertion.sub,attribute.namespace=assertion['kubernetes.io']['namespace'],attribute.service_account_name=assertion['kubernetes.io']['serviceaccount']['name'],attribute.pod=assertion['kubernetes.io']['pod']['name']"

# attribute.ATTRIBUTE_NAME/ATTRIBUTE_VALUE
...POOL_ID/attribute.pod/testing
```

Would mean any pod named testing can use the pool, except we have an "attribute-condition" limiting the namespace that can use our pool to "monitoring" and "backend"

So, in reality, any pod named "testing" in the namespace "monitoring" or "backend" can use the kind OIDC kubernetes-based service account pool.