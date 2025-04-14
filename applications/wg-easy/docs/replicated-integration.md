# Replicated Integration

This document explains how the WG-Easy Helm chart pattern integrates with the Replicated platform, focusing on key integration points and modular configuration.

## Replicated Overview

Replicated is a platform that enables software vendors to deliver and manage Kubernetes applications to enterprise customers. In the context of this development pattern, Replicated provides:

1. **Distribution**: Package and ship your application securely
2. **Configuration Management**: User-friendly configuration interfaces
3. **Licensing**: Control access through license files
4. **Embedded Kubernetes**: Deploy to environments without existing clusters
5. **Updates**: Manage application versions and updates

## Integration Points

The WG-Easy pattern integrates with Replicated at the following key points in the development workflow:

### 1. Chart Structure Integration

Each chart includes a `replicated` directory containing:

```
cert-manager/replicated/
├── helmChart-cert-manager.yaml  # Installation instructions
└── config.yaml                  # Component-specific configuration
```

### 2. Modular Configuration

Each chart can define its own `config.yaml` with component-specific configuration options:

```yaml
# Example: wg-easy/replicated/config.yaml
apiVersion: kots.io/v1beta1
kind: Config
metadata:
  name: not-used
spec:
  groups:
    - name: wireguard-config
      title: Wireguard
      description: Wireguard configuration
      items:
      - name: password
        title: Admin password
        type: password
        required: true
      - name: domain
        title: IP or domain
        help_text: Domain or IP which the vpn is accessible on
        type: text
        required: true
```

During release preparation, these individual `config.yaml` files are automatically merged into a single configuration file.

### 3. Chart Installation

The `helmChart-*.yaml` files define how each Helm chart is installed by Replicated installers:

```yaml
# Example: traefik/replicated/helmChart-traefik.yaml
apiVersion: kots.io/v1beta2
kind: HelmChart
metadata:
  name: traefik
spec:
  chart:
    name: traefik
    chartVersion: '1.0.0'
  weight: 2
  helmUpgradeFlags:
    - --wait
  namespace: traefik
  values:
    traefik:
      ports:
        web:
          nodePort: 80
        websecure:
          nodePort: 443
```

### 4. Release Workflow

The integration with Replicated's release process is handled by the `release-prepare` and `release-create` tasks:

```bash
# Prepare release files
task release-prepare

# Create and promote a release
task release-create CHANNEL=Beta
```

The `release-prepare` task:

1. Copies all Replicated YAML files to a release directory
2. Merges all `config.yaml` files from different components
3. Packages all Helm charts

## Modular Configuration Benefits

This modular configuration approach provides several benefits:

1. **Team Ownership**: Different teams can own their component's configuration
2. **Isolation**: Changes to one component's configuration don't affect others
3. **Simplified Development**: Focus on your component without worrying about the full configuration
4. **Automatic Merging**: Configuration merging is automated at release time

## Embedded Cluster Support

Replicated's embedded Kubernetes capability is configured via the `cluster.yaml` file:

```yaml
apiVersion: embeddedcluster.replicated.com/v1beta1
kind: Config
spec:
  version: 2.1.3+k8s-1.29
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

This enables running the application in environments without a pre-existing Kubernetes cluster.

## Further Replicated Documentation

For detailed information about Replicated's capabilities and options, refer to the official documentation:

- [Replicated KOTS Documentation](https://docs.replicated.com/reference/kots-cli)
- [Helm Chart Integration](https://docs.replicated.com/vendor/helm-installing)
- [Configuration Options](https://docs.replicated.com/vendor/config-screen)
- [Embedded Clusters](https://docs.replicated.com/vendor/embedded-clusters)
