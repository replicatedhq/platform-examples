# helm-fake-service

This repository contains an example Helm chart that distributed with Replicated Embedded Cluster.

![app](img/app.png)

## Components

- A Helm chart using [fake-service](https://github.com/nicholasjackson/fake-service)
- Replicated [manifests](https://docs.replicated.com/reference/custom-resource-about) to deploy the chart with Replicated

## Replicated features

- [x] Packaged as a Helm chart
- [x] Installation works via Helm CLI, as well as KOTS & Embedded Cluster
- [x] Support Online and Airgap install
- [x] Replicated SDK installed
- [x] Custom Metrics implemented
- [x] Github Actions workflow for Replicated test and release
- [x] Support Replicated Proxy Service
- [x] Support Replicated Custom Domain
