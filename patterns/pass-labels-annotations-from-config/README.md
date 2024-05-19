## Pass Labels and Annotations from Config Options to Helm Chart Values

There may be a variety of different situations in which you'd want the user to be able to set annotations or labels on a resource you're deploying in your application. A good example is when you want the user to be able to set annotations on a `Service` or `Ingress` object in public cloud environments. The below shows how you can use Replicated's Config Options to do this.

Source Application: [Mlflow](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow)

1. Use the `textarea` config option type to allow a user to copy/paste in their annotations or labels

[Mlflow KOTS Config](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow/kots/manifests/kots-config.yaml)
```yaml
apiVersion: kots.io/v1beta1
kind: Config
metadata:
  name: config
spec:
  groups:
  - name: ingress_settings
    title: Ingress Settings
    description: Configure Ingress for Mlflow
    items:
    - name: mlflow_load_balancer_annotations
      type: textarea
      title: Load Balancer Annotations
      help_text: "See your cloud provider's documentation for the required annotations."
      when: 'repl{{ and (ne Distribution "embedded-cluster") (ConfigOptionEquals "mlflow_ingress_type" "load_balancer") }}'
```

2. Use the config option you created in your KOTS helm chart values for the service annotations

[Mlflow KOTS Helm Chart](https://github.com/replicatedhq/platform-examples/blob/main/applications/mlflow/kots/manifests/helm-mlflow.yaml)
```yaml
apiVersion: kots.io/v1beta2
kind: HelmChart
metadata:
  name: mlflow
spec:
  chart:
    name: mlflow
    chartVersion: 0.1.2
  weight: 1
  values:
    mlflow:
      ingress:
        enabled: true
        className: repl{{ ConfigOption "mlflow_ingress_class_name"}}
        hostname: repl{{ ConfigOption "mlflow_ingress_host"}}
        annotations: repl{{ ConfigOption `mlflow_ingress_annotations` | nindent 10 }}
```
