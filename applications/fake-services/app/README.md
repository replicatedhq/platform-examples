# fake-service

This Helm chart will install:

- A fake-service frontend
- A fake-service backend

The `frontend` service will be exposed with an `Ingress`.

We will not install `ingress-nginx` as part of the Helm chart but install `ingress-nginx` controller separately. E.g. with `k0s` Helm chart (extension)[https://docs.k0sproject.io/head/helm-charts/?h=helm+extension#example]
