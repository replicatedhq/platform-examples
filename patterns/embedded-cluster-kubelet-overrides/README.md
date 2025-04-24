# Kubelet overrides for Embedded Cluster

If your application has unique environmental requirements such as additional kernel features or specific kubelet settings to function correctly, you can configure these settings via a Worker Profile.

To do this, specify a workerProfile as per the k0s documentation in the k0s config section of unsupportedOverrides within your Embedded Cluster config

## Example 1: Increasing the number of pods schedulable to a single node

This example can benefit your Embedded Cluster releases if you deploy a large number of workloads but your customers prefer to run your application on a single node.

```yaml
apiVersion: embeddedcluster.replicated.com/v1beta1
kind: Config
spec:
  unsupportedOverrides:
    k0s: |
      config:
        spec:
          workerProfiles:
            - name: increased-pod-limit
              values:
                maxPods: 250
```

## Example 2: Set allowed unsafe sysctl settings

```yaml
apiVersion: embeddedcluster.replicated.com/v1beta1
kind: Config
spec:
  unsupportedOverrides:
    k0s: |-
      config: 
        spec:
          workerProfiles:
            - name: default
              values:
                allowedUnsafeSysctls:
                  - net.ipv4.ip_forward
```

## Further reading

[K0s documentation on worker profiles](https://docs.k0sproject.io/stable/configuration/#specworkerprofiles)

[Kubelet configuration options](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletConfiguration)
