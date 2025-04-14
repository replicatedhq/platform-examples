# WG-Easy Development Pattern Examples

This document provides practical examples of the key concepts in the WG-Easy Helm chart pattern.

## Progressive Complexity Example

This example demonstrates the complete workflow from working with a single chart to creating a full release.

### Stage 1-2: Chart Dependencies and Configuration

```yaml
# cert-manager/Chart.yaml
apiVersion: v2
name: cert-manager
version: 1.0.0
dependencies:
  - name: cert-manager
    version: '1.14.5'
    repository: https://charts.jetstack.io
  - name: templates
    version: '*'
    repository: file://../charts/templates
```

```bash
# Update dependencies
helm dependency update ./cert-manager

# Verify dependencies were downloaded
ls -la ./cert-manager/charts/
```

### Stage 3: Local Validation

```bash
# Render templates locally to verify
helm template ./cert-manager --output-dir ./rendered-templates

# Verify the output
ls -la ./rendered-templates/cert-manager/templates/
```

### Stage 4: Single Chart Install

```bash
# Create a test cluster
task cluster-create
task setup-kubeconfig

# Install the single chart
helm install cert-manager ./cert-manager -n cert-manager --create-namespace

# Validate deployment
kubectl get pods -n cert-manager
```

### Stage 5: Integration Testing

```bash
# Deploy multiple charts using helmfile
task deploy-helm

# Verify integration points
kubectl get clusterissuers
kubectl get ingressroutes -A
```

### Stage 6-7: Release Preparation and Testing

```bash
# Prepare release files
task release-prepare

# Create a release
task release-create

# Test in embedded environment
task create-gcp-vm
task setup-embedded-cluster
```

### Validation Points

The example demonstrates validation at each stage:

1. **Dependencies**: Verify charts are downloaded correctly
2. **Template Rendering**: Ensure templates produce valid Kubernetes resources
3. **Single Chart**: Confirm chart installs and runs properly in isolation
4. **Integration**: Validate charts work together as expected
5. **Release**: Verify proper packaging and release creation
6. **Production Environment**: Confirm full system functionality

### Issue Isolation Example

If an issue is discovered during integration testing (Stage 5):

1. **Identify Components**: Determine which charts are involved
2. **Scale Back**: Return to Stage 4 to test each chart individually
3. **Find Root Cause**: Isolate the specific chart or interaction causing the issue
4. **Fix and Validate**: Make changes and validate at the simpler level first
5. **Progress Again**: Move back through the stages to ensure the fix works in the full system

## Modular Configuration Example

This example shows how per-chart configuration is maintained and merged during release.

### Per-Chart Configuration

```yaml
# traefik/replicated/config.yaml
apiVersion: kots.io/v1beta1
kind: Config
metadata:
  name: not-used
spec:
  groups:
    - name: traefik-config
      title: Traefik
      items:
      - name: domain
        title: Domain
        type: text
        required: true
```

```yaml
# wg-easy/replicated/config.yaml
apiVersion: kots.io/v1beta1
kind: Config
metadata:
  name: not-used
spec:
  groups:
    - name: wireguard-config
      title: Wireguard
      items:
      - name: password
        title: Admin password
        type: password
        required: true
```

### Configuration Merging

During release preparation, these files are automatically merged:

```bash
task release-prepare
```

This produces a combined `config.yaml` in the release directory with all options from both components.

### Team Ownership Benefits

This approach allows:

1. **Distributed Responsibilities**: The Traefik team manages Traefik options, WG-Easy team manages WG-Easy options
2. **Independent Updates**: Teams can update their configuration without coordinating changes
3. **Clear Boundaries**: Configuration ownership follows component ownership
4. **Reduced Conflicts**: Fewer merge conflicts in version control

## Chart Wrapping Example

This example demonstrates wrapping an upstream chart and the benefits it provides.

### Simple Chart Wrapping

```yaml
# traefik/Chart.yaml - Wrapper chart
apiVersion: v2
name: traefik
version: 1.0.0
dependencies:
  - name: traefik
    version: '28.0.0'
    repository: https://helm.traefik.io/traefik
  - name: templates
    version: '*'
    repository: file://../charts/templates
```

```yaml
# traefik/values.yaml - Our custom defaults
traefik:
  service:
    type: NodePort
  ports:
    web:
      nodePort: 80
      redirectTo: websecure
    websecure:
      nodePort: 443
```

### Custom Templates

```yaml
# traefik/templates/certificate.yaml - Custom resource
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: traefik-cert
  namespace: traefik
spec:
  secretName: traefik-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  {{- range .Values.certs.dnsNames }}
    - {{ . | quote }}
  {{- end }}
```

### Benefits

1. **Extended Functionality**: Add custom resources that aren't part of the upstream chart
2. **Version Management**: Control which version of the upstream chart is used
3. **Simplified Updates**: Test upstream chart updates in isolation
4. **Custom Defaults**: Set defaults that match your use case

### Environment Consistency

The wrapper chart ensures consistency by:

1. **Shared Templates**: Reuse common patterns
2. **Explicit Dependencies**: Clear relationship between components
3. **Controlled Customization**: Customizations applied in a standard way
