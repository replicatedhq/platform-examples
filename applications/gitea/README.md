# Use Multi-CMX machine to Deploy Gitea with External Postgres Database
This example demonstrates how to deploy Gitea with an external Postgres database using Replicated [Compatibility Matrix](https://docs.replicated.com/vendor/testing-about) and [Embedded Cluster](https://docs.replicated.com/vendor/embedded-overview). In the example, [Gitea Helm chart](https://gitea.com/gitea/helm-chart) is featured as the application to be deployed with a dedicated Postgres database. The infrastructure consists of two separate CMX machine connected to the same network.

## Architecture Overview
Replicated Compatibility Matrix quickly provisions ephemeral clusters of different Kubernetes distributions and versions, such as OpenShift, EKS, and Replicated kURL. In this example, we use two separate Kubernetes clusters, one for Gitea and the other for Postgres.
1. **CMX Cluster (Postgres)**: The CMX cluster is Kubernetes pre-installed cluster hosted on VMs. It contains a single-node VM or a multi-node VM with Postgres database installed. The Postgres database is exposed to the Gitea cluster via a same network.
2. **CMX VM (Gitea)**: The CMX VM is a single VM that has no Kubernetes pre-installed. It is used to deploy Gitea Helm chart. The Gitea Helm chart is configured to use the Postgres database in the CMX cluster.

Both clusters are configured to use the same network, enabling secure inter-cluster communication between Gitea and Postgres.

## Prerequisites
1. [Replicated Vendor Portal Account](https://vendor.replicated.com/signup)
2. [Replicated CLI](https://docs.replicated.com/reference/replicated-cli-installing)
3. [Replicated Embedded Cluster](https://docs.replicated.com/vendor/embedded-overview)
4. [Replicated Compatibility Matrix](https://docs.replicated.com/vendor/testing-about)
5. Valid license for Replicated Embedded Cluster
6. CMX Credits


## Steps
### Cluster Setup
1. PostgresSQL Cluster
Create a new cluster using Replicated Compatibility Matrix with PostgresSQL installed. A example helm chart will be [storagebox helm chart](/applications/storagebox/README.md) which is a intergrated database container with PostgresSQL.

Under the `storagebox` directory, run the following command to create a new release:
```bash
cd applications/storagebox
make release

## those commands will package the storagebox helm chart and upload it to the replicated vendor portal with a new release
## After the release is created, you need to promote the release to the desired channel
## A dedicated test user should be created with embedded cluster access to test the release
```

In the Replicated Vendor Portal, customer's license can be downloaded from the [`Customer`](https://docs.replicated.com/vendor/licenses-download) page. Use the license ID to create a new cluster with the following command:

```bash
replicated cluster create \
    --distribution embedded-cluster \
    --instance-type r1.xlarge \
    --disk 100 \
    --license-id xxxxxx \
    --ttl 4h \
    --name postgres-cluster

## Verify cluster creation
replicated cluster ls

## Access cluster shell
replicated cluster shell <cluster-id>

## Port forward the kotsadm to install the storagebox helm chart with PostgresSQL enabled
kubectl port-forward svc/kotsadm 3000:3000 -n kotsadm
```

Login to the kotsadm dashboard with default password `password` and configure the storagebox helm chart with PostgresSQL only enabled. After the helm chart is installed, the PostgresSQL database is ready to be used by Gitea.

2. Gitea Cluster
Create a new cluster using Replicated Compatibility Matrix with no pre-installed Kubernetes. The cluster will be used to deploy Gitea Helm chart.

```bash
## first, find the network id of the PostgresSQL cluster
replicated network ls
---
ID          NAME                           STATUS          CREATED                           EXPIRES                           OUTBOUND
709a523d    postgres-cluster                running         2025-02-18 17:06              2025-02-18 21:12              -    
---
```

Use the network ID to create a new cluster with the following command:
```bash
replicated vm create --distribution ubuntu --version 24.04 --instance-type r1.xlarge --disk 100 --name gitea-vm --network 709a523d

## wait for the cluster to be ready
replicated vm ls
---
06db1e55    gitea-vm                       ubuntu          24.04         running         2025-02-18 17:29              2025-02-18 18:30        
---
## ssh into the VM with vm id
ssh 06db1e55@replicatedvm.com
```

In the VM, you can verify the network connection to the PostgresSQL before deploying Gitea Helm chart.
First, find the hostname of the PostgresSQL cluster.
```bash
replicated cluster ls
---
64ccba9c    postgres-cluster                embedded-cluster    5             running         2025-02-18 17:06              2025-02-18 21:12  
---

## connect to the kubeconfig of the PostgresSQL cluster
replicated cluster shell 64ccba9c

## get the hostname of the PostgresSQL cluster
kubectl get node
---
64ccba9c1   Ready    control-plane   28m   v1.30.9+k0s
---
```

`64ccba9c1` is the hostname of the PostgresSQL cluster. Use the hostname to verify the network connection to the PostgresSQL cluster:

```bash
sudo apt-get install -y postgresql-client
## password is postgres
psql -h 64ccba9c1 -p 5432 -U postgres -d postgres
```

After the network connection is verified, you can deploy Gitea Helm chart.

Go to `applications/gitea` directory and run the following command to create a new release:
```bash
cd applications/gitea
make release
```

Promote the release to the desired channel with a dedicated test user. The test user should have access to the Embedded Cluster.

In the Replicated Vendor Portal, go to the [customer page](https://docs.replicated.com/vendor/embedded-using) where you enabled Embedded Cluster. At the top right, click Install instructions and choose Embedded Cluster. A dialog appears with instructions on how to download the Embedded Cluster installation assets and install your application.

```bash
curl -f "https://replicated.app/embedded/<appslug>/gitea" -H "Authorization: xxxxxxxxx" -o <appslug>-gitea.tgz
tar -xvzf  <appslug>-gitea.tgz
sudo ./<appslug> install --license license.yaml
```

After the installation is complete, you need to expose the `kotsadmin` console to configure the Gitea Helm chart. Run the following command to expose the `kotsadmin` console:
```bash
replicated vm port expose 06db1e55 --port 30000
---
31128876        30000           http            http://busy-visvesvaraya.ingress.replicatedcluster.com    false           ready  

31128876        30000           https           https://busy-visvesvaraya.ingress.replicatedcluster.com    false           ready  
---

```

The `06db1e55` is the VM ID of the Gitea cluster. You can access the `kotsadmin` console with the following URL: `https://busy-visvesvaraya.ingress.replicatedcluster.com:30000`. The default password is what you set in the `install` command.

In the `kotsadmin` console, you can configure the Gitea Helm chart to use the PostgresSQL database in the PostgresSQL cluster by
1. `Enable Internal PostgresSQL` to `false` (disable the internal PostgresSQL)
2. `Postgres User` to `postgres`
3. `Postgres Password` to `postgres`
4. `Postgres Host` to `64ccba9c1` (hostname of the PostgresSQL cluster)
5. `Postgres Database Name` to `postgres`


After the configuration is complete, you can deploy the Gitea Helm chart. The Gitea Helm chart will use the PostgresSQL database in the PostgresSQL cluster.

## Network Diagram
```
+----------------------+         +----------------------+
|  Postgres Cluster    |         |   Git VM Cluster     |
|----------------------|         |----------------------|
| - Embedded Cluster   |         | - Embedded Cluster   |
| - Postgres DB        |<------->| - Gitea              |
+----------------------+         +----------------------+
       Shared Network: 709a523d
```
