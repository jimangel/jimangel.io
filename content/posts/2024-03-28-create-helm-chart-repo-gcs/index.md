---
title: "Creating a Helm Chart Repository on Google Cloud Storage"
date: 2024-03-28
description: "Learn how to create a Helm chart repository on Google Cloud Storage and share your Helm charts."
summary: "This post walks through the process of creating a Helm chart repository on Google Cloud Storage to share your Helm charts."
tags:
- kubernetes
- helm
- google cloud
keywords:
- Helm
- Helm chart
- Helm repository
- Google Cloud Storage
- GCS
- Kubernetes
- chart repository
slug: "create-helm-chart-repo-gcs"
draft: false
---

{{< notice warning >}}
This post may contain inaccuracies and partial information or solutions.

In an effort to reduce my backlog of docs, I've decided to publish my nearly completed drafts assisted by AI.

I wrote most of the following content, but used generative AI to format, organize, and complete the post. I'm sure some tone is lost along the way.

Leave a comment if you find any issues!
{{< /notice >}}

_(originally created **Jun 13th 2021**)_

If you have an open source app that you want folks to start using, creating a Helm chart is a great way to make your application more portable. A Helm chart repository is a place to host Helm charts, making it easy for others to discover and deploy your application.

In this post, we'll walk through the process of creating a Helm chart repository on Google Cloud Storage (GCS), following the official [Helm documentation](https://helm.sh/docs/topics/chart_repository/#hosting-chart-repositories).

## Create a GCS Bucket

The first step is to create a GCS bucket to host your Helm charts. If you're using Terraform to manage your GCP resources, you can add the following configuration to create a public bucket:

```hcl
resource "google_storage_bucket_access_control" "public_rule" {
  bucket = google_storage_bucket.bucket.name
  role   = "READER"
  entity = "allUsers"
}

resource "google_storage_bucket" "bucket" {
  name = "jimangel-charts"
}
```

## Create a Helm Chart

Next, create a new Helm chart for your application. In this example, we'll create a chart named `gitdocs`:

```bash
helm create gitdocs
```

Make any necessary modifications to the chart, and test it using:

```bash
helm template .
```

## Package and Index Your Chart

Create a `public` directory to store your packaged charts, and then package your chart:

```bash
mkdir public
cd public
helm package ../
```

Generate an `index.html` file for your repository:

```bash
helm repo index . --url https://jimangel-charts.storage.googleapis.com
```

## Sync with GCS

Use `gsutil` and `rsync` to upload your charts to the GCS bucket:

```bash
gcloud auth login
gcloud config configurations activate out-of-pocket

gsutil rsync -d ./ gs://jimangel-charts
gsutil iam ch allUsers:objectViewer gs://jimangel-charts
```

To ensure that the charts and index file are always served with the latest version, set the `Cache-Control` header to `no-cache`:

```bash
gsutil -m setmeta -h "Cache-Control:no-cache" gs://jimangel-charts/*.tgz
gsutil -m setmeta -h "Cache-Control:no-cache" gs://jimangel-charts/index.yaml
```

## Test Your Repository

Add your new Helm repository and update the local cache:

```bash
helm repo add jimangel2 https://jimangel-charts.storage.googleapis.com
helm repo update
```

Search for your chart:

```bash
helm search repo jimangel2
```

Install your chart:

```bash
helm install gitdocs jimangel2/gitdocs
```

## Updating Your Chart

To update your chart, make the necessary changes, increment the chart version in the `Chart.yaml` file, and then repeat the packaging, indexing, and syncing steps:

```bash
cd helm-chart/public
helm package ../
helm repo index . --url https://jimangel-charts.storage.googleapis.com
gsutil rsync -d ./ gs://jimangel-charts
gsutil iam ch allUsers:objectViewer gs://jimangel-charts
gsutil -m setmeta -h "Cache-Control:no-cache" "gs://jimangel-charts/*.tgz"
gsutil -m setmeta -h "Cache-Control:no-cache" gs://jimangel-charts/index.yaml
```

Users can then update their local repository cache and see the new version:

```bash
helm repo update
helm search repo -l gitdocs
```

By following these steps, you can create a Helm chart repository on Google Cloud Storage, making it easy to share your applications with the community.