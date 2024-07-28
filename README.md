# Replicated Platform Examples

This repository contains a collection of examples for users of the Replicated
platform. Examples are divided broadly into two categories: applications and
patterns. _Applications_ show complete applications that take advantage of many
feature of the platform, while _Patterns_ show a simple reusable solution to a
common problem you might encounter while distributing your software with
Replicated.

## Contributing

Contributions are greatly appreciated. We are currently evolving our
[contributors guide](Contributing.md) to better support your contributions.


## How to setup Compatibility Testing in GitHub Actions

This tutorial will guide you through setting up compatibility testing in GitHub Actions for your application. It will use the Replicated Replicated Compatibility Matrix to test your application against different versions of Kubernetes and different operating systems.

Replicated Compatibility Matrix quickly provisions ephemeral clusters of different Kubernetes distributions and versions, such as OpenShift, EKS, and Replicated kURL.

Before you begin, you will need to have the following:
- credits in your Replicated account to run the Compatibility Matrix cluster
- a GitHub repository with your helm chart code

Here is the step-by-step guide to setting up compatibility testing in GitHub Actions:

1. Create a new GitHub Actions workflow file in your repository. You can do this by creating a new file in the `.github/workflows` directory of your repository. For example, you can create a file named `compatibility-testing.yml` in the `.github/workflows` directory.
2. In the current workflows, you have two options to run the compatibility testing:
    - Copy cmx-simple.yaml and run the compatibility testing with less steps and configurations.
    - Copy cmx-complete.yaml and run the compatibility testing with more steps and transparencies.
3. setup github actions secrets
    - `REPLICATED_API_TOKEN` - [API token](https://docs.replicated.com/reference/replicated-cli-installing#replicated_api_token) for your Replicated Vendor account
    - `REPLICATED_APP` - [Application slug](https://docs.replicated.com/reference/replicated-cli-installing#replicated_app) for your Replicated application
4. customize the `Run Compatibility Testing` step 
```
      - name: Run Compatibility Testing
        run: |
          retries=10
          sleep_time=6
          for ((i=0; i<retries; i++)); do
            status=$(helm status ${{env.chart_name}} -n test-${{env.chart_name}} -o json | jq -r .info.status)
            if [[ "$status" == "deployed" ]]; then
              echo "Helm release ${{env.chart_name}} is successfully deployed."
              break
            else
              echo "Waiting for Helm release ${{env.chart_name}} to be deployed..."
              sleep $sleep_time
            fi

            if [[ $i -eq $((retries-1)) ]]; then
              echo "Helm release ${{env.chart_name}} failed to deploy after $((retries*sleep_time)) seconds."
              exit 1
            fi
          done
        env:
          KUBECONFIG: /tmp/kubeconfig
```

By trigger the github actions, you can integrate the compatibility testing into your CI/CD pipeline. 

The difference between `cmx-simple.yaml` and `cmx-complete.yaml` is that `cmx-simple.yaml` is using `helm-extra-repos:` to simplify the dependency helm charts installation. Here is the example.
```
          helm-extra-repos: |
            - repo_name: "cnpg"
              url: "https://cloudnative-pg.github.io/charts"
              namespace: "cnpg-system"
              chart_name: "cloudnative-pg"
            - repo_name: "minio-operator"
              url: "https://operator.min.io"
              namespace: "minio-operator"
              chart_name: "operator"
```
it is equivalent to the following steps in `cmx-complete.yaml`
```
      - name: Install Dependency Helm Charts
        id: install-dependency-charts
        run: |
          helm repo add cnpg https://cloudnative-pg.github.io/charts
          helm repo add minio-operator https://operator.min.io
          helm upgrade --install cnpg \
            --namespace cnpg-system \
            --create-namespace \
            cnpg/cloudnative-pg
          helm upgrade --install operator \
              --namespace minio-operator \
              --create-namespace \
              minio-operator/operator
```
