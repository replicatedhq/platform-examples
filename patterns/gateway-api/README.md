# Gateway API for Multi-Protocol Applications

The Kubernetes [Gateway API](https://gateway-api.sigs.k8s.io/) is the successor to the Ingress API. It provides a standardized way to route HTTP, TCP, TLS, and gRPC traffic through a single extensible framework. For applications that expose a mix of protocols -- HTTP APIs alongside TCP databases, for example -- Gateway API replaces the patchwork of Ingress resources, NodePort services, and controller-specific annotations that was previously required.

This pattern demonstrates how to implement Gateway API routing for an application that bundles multiple storage backends with different protocol requirements, using [Envoy Gateway](https://gateway.envoyproxy.io/) as the controller.

Source Application: [Storagebox](https://github.com/replicatedhq/platform-examples/blob/main/applications/storagebox)

## Why Gateway API Over Ingress

The traditional Ingress API only handles HTTP/HTTPS. Applications that also need to expose TCP services (databases, message brokers) have no standard way to do this -- each Ingress controller has its own custom annotations or ConfigMaps for TCP routing. Gateway API solves this with dedicated route types:

| Route Type | Protocol | API Version | Use Case |
|---|---|---|---|
| HTTPRoute | HTTP/HTTPS | `gateway.networking.k8s.io/v1` | Web UIs, REST APIs, S3 endpoints |
| TCPRoute | TCP | `gateway.networking.k8s.io/v1alpha2` | Databases (PostgreSQL, Cassandra, Redis) |
| TLSRoute | TLS | `gateway.networking.k8s.io/v1alpha2` | TLS passthrough |
| GRPCRoute | gRPC | `gateway.networking.k8s.io/v1` | gRPC services |

The Storagebox application uses HTTPRoute for its S3 API (Garage) and rqlite, and TCPRoute for PostgreSQL and Cassandra CQL.

## Choosing a Gateway API Controller

Gateway API is a specification, not an implementation. You need a controller that implements it. The key question for Embedded Cluster deployments is: **does the controller bundle all the CRDs you need?**

At the time of writing (February 2026), TCPRoute and TLSRoute are in the Gateway API experimental channel (`v1alpha2`). This is a point-in-time constraint -- these APIs are on track for promotion to the standard channel in a future Gateway API release. Once promoted, the CRD packaging distinction below becomes moot and any conformant controller will work.

Today, most controllers only ship the standard channel CRDs (HTTPRoute, GRPCRoute) in their Helm charts. If you need TCPRoute, your options are:

| Controller | HTTPRoute | TCPRoute | Ships Experimental CRDs | Install Method |
|---|---|---|---|---|
| **Envoy Gateway** | Yes | Yes | Yes (bundled in chart) | OCI Helm chart |
| Traefik | Yes | Yes | No (install separately) | Traditional Helm repo |
| Istio | Yes | Yes | Depends on profile | Traditional Helm repo |
| Cilium | Yes | Yes | Requires CNI | Bundled with CNI |

Traefik fully supports TCPRoute when the experimental CRDs are available in the cluster. The CRDs can be installed as a separate EC extension Helm chart, as a raw `kubectl apply` step, or vendored into your application chart's `crds/` directory. The controller itself handles TCPRoute natively when `providers.kubernetesGateway.experimentalChannel: true` is set.

Storagebox uses **Envoy Gateway** because it bundles all Gateway API CRDs (including experimental TCPRoute) as part of its Helm chart installation, eliminating the need for a separate CRD installation step. EC extensions support OCI chart references natively.

## Architecture: One Gateway Per Application

Rather than a single shared Gateway with many listeners, this pattern creates a **separate Gateway per application**. Envoy Gateway provisions an independent Envoy proxy Deployment and Service for each Gateway resource, providing:

- **Isolation** -- one application's proxy failure does not affect others
- **Independent lifecycle** -- enable or disable each application's Gateway without touching others
- **Clear ownership** -- each Gateway file is self-contained with its routes

```
                    ┌─────────────────┐
                    │  GatewayClass   │
                    │  "storagebox"   │
                    └────────┬────────┘
                             │ references
                    ┌────────▼────────┐
                    │   EnvoyProxy    │
                    │  (NodePort)     │
                    └────────┬────────┘
            ┌────────────────┼────────────────┐
            │                │                │
   ┌────────▼─────┐ ┌───────▼──────┐ ┌───────▼──────┐
   │   Gateway    │ │   Gateway    │ │   Gateway    │
   │ garage (HTTP)│ │ postgres(TCP)│ │cassandra(TCP)│
   └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
          │                │                │
   ┌──────▼───────┐ ┌──────▼──────┐ ┌──────▼──────┐
   │  HTTPRoute   │ │  TCPRoute   │ │  TCPRoute   │
   │  garage-s3   │ │  postgres   │ │  cassandra  │
   └──────┬───────┘ └──────┬──────┘ └──────┬──────┘
          │                │                │
   ┌──────▼───────┐ ┌──────▼──────┐ ┌──────▼──────┐
   │   Service    │ │   Service   │ │   Service   │
   │ garage:3900  │ │ postgres:   │ │ cassandra:  │
   │  (S3 API)    │ │    5432     │ │    9042     │
   └──────────────┘ └─────────────┘ └─────────────┘
```

## Installing the Controller as an EC Extension

Envoy Gateway is installed as an Embedded Cluster extension using an OCI chart reference. No Helm repository entry is needed for OCI charts.

[Storagebox EC Config - Envoy Gateway Extension](https://github.com/replicatedhq/platform-examples/blob/main/applications/storagebox/kots/ec.yaml)
```yaml
# kots/ec.yaml
extensions:
  helm:
    charts:
      - name: envoy-gateway
        chartname: oci://docker.io/envoyproxy/gateway-helm
        namespace: envoy-gateway-system
        version: "v1.7.0"
```

This installs the Envoy Gateway controller, Gateway API CRDs (standard and experimental), and creates a default GatewayClass named `eg`. We create our own GatewayClass instead so we can control the data plane Service type.

## Shared Infrastructure: GatewayClass and EnvoyProxy

All per-application Gateways reference the same GatewayClass, which in turn references an EnvoyProxy resource that configures the data plane. In Embedded Cluster environments there is no cloud load balancer, so the EnvoyProxy specifies `NodePort`.

[Storagebox Gateway Infrastructure](https://github.com/replicatedhq/platform-examples/blob/main/applications/storagebox/charts/storagebox/templates/gateway-infra.yaml)
```yaml
# EnvoyProxy configures the Envoy proxy pods and Service type.
# Created in the envoy-gateway-system namespace so the GatewayClass can find it.
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: storagebox-proxy
  namespace: envoy-gateway-system
spec:
  provider:
    type: Kubernetes
    kubernetes:
      envoyService:
        type: NodePort
      envoyDeployment:
        replicas: 1
---
# GatewayClass references the EnvoyProxy above.
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: storagebox
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
  parametersRef:
    group: gateway.envoyproxy.io
    kind: EnvoyProxy
    name: storagebox-proxy
    namespace: envoy-gateway-system
```

## HTTPRoute: Routing HTTP Traffic to an S3 API

The Garage S3 storage backend exposes an HTTP API on port 3900. The Gateway defines an HTTP listener, and an HTTPRoute matches requests by hostname and forwards them to the Garage Service.

[Storagebox Garage Gateway](https://github.com/replicatedhq/platform-examples/blob/main/applications/storagebox/charts/storagebox/templates/gateway-garage.yaml)
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: storagebox-garage
spec:
  gatewayClassName: storagebox
  listeners:
    - name: http
      port: 80
      protocol: HTTP
      allowedRoutes:
        namespaces:
          from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: storagebox-garage-s3
spec:
  parentRefs:
    - name: storagebox-garage
      sectionName: http
  hostnames:
    - "garage.local"
  rules:
    - backendRefs:
        - name: storagebox-garage
          port: 3900
```

When Envoy Gateway sees this Gateway, it creates an Envoy proxy Deployment and a NodePort Service that listens on port 80. Requests arriving with `Host: garage.local` are forwarded to the Garage S3 API.

### Adding TLS Termination

To terminate TLS at the Gateway, add an HTTPS listener that references a Kubernetes TLS Secret. The HTTPRoute then attaches to the `https` listener instead:

```yaml
listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
  - name: https
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      certificateRefs:
        - name: garage-tls-secret
    allowedRoutes:
      namespaces:
        from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: storagebox-garage-s3
spec:
  parentRefs:
    - name: storagebox-garage
      sectionName: https    # attach to the HTTPS listener
  hostnames:
    - "garage.example.com"
  rules:
    - backendRefs:
        - name: storagebox-garage
          port: 3900
```

The backend Service continues to receive plaintext HTTP. TLS is terminated at the Envoy proxy.

## TCPRoute: Routing Database Traffic

PostgreSQL uses a binary wire protocol on port 5432 -- it cannot be routed with HTTPRoute. TCPRoute handles this by forwarding raw TCP connections. The Gateway defines a TCP listener, and the TCPRoute attaches to it.

[Storagebox PostgreSQL Gateway](https://github.com/replicatedhq/platform-examples/blob/main/applications/storagebox/charts/storagebox/templates/gateway-postgres.yaml)
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: storagebox-postgres
spec:
  gatewayClassName: storagebox
  listeners:
    - name: postgres-tcp
      port: 5432
      protocol: TCP
      allowedRoutes:
        namespaces:
          from: Same
---
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TCPRoute
metadata:
  name: storagebox-postgres
spec:
  parentRefs:
    - name: storagebox-postgres
      sectionName: postgres-tcp
  rules:
    - backendRefs:
        - name: postgres-nodeport
          port: 5432
```

Envoy Gateway creates an Envoy proxy with a NodePort Service exposing port 5432. TCP connections are forwarded directly to the PostgreSQL Service without any application-layer inspection.

The same pattern works for Cassandra CQL on port 9042:

[Storagebox Cassandra Gateway](https://github.com/replicatedhq/platform-examples/blob/main/applications/storagebox/charts/storagebox/templates/gateway-cassandra.yaml)
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: storagebox-cassandra
spec:
  gatewayClassName: storagebox
  listeners:
    - name: cassandra-tcp
      port: 9042
      protocol: TCP
      allowedRoutes:
        namespaces:
          from: Same
---
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TCPRoute
metadata:
  name: storagebox-cassandra
spec:
  parentRefs:
    - name: storagebox-cassandra
      sectionName: cassandra-tcp
  rules:
    - backendRefs:
        - name: storagebox-cassandra-dc1-service
          port: 9042
```

## Making It Configurable via KOTS

Each application's Gateway is independently togglable through the KOTS Admin Console. The Helm templates use a three-way conditional: the global gateway toggle, the per-service gateway toggle, and the service's own enabled flag.

```yaml
{{- if and .Values.gateway.enabled .Values.gateway.postgres.enabled .Values.postgres.embedded.enabled }}
# Gateway + TCPRoute resources here
{{- end }}
```

The KOTS Config UI exposes the per-service gateway toggles inside each service's settings group, with cascading visibility:

[Storagebox KOTS Config - PostgreSQL Gateway Settings](https://github.com/replicatedhq/platform-examples/blob/main/applications/storagebox/kots/kots-config.yaml)
```yaml
- name: gateway_postgres_enabled
  title: Enable PostgreSQL Gateway
  type: bool
  default: true
  description: Create a TCP Gateway + TCPRoute for PostgreSQL on port 5432
  when: 'repl{{ and (ConfigOptionEquals "postgres_enabled" "1")
                    (ConfigOptionNotEquals "postgres_external" "1")
                    (ConfigOptionEquals "gateway_enabled" "1") }}'
```

This setting only appears when PostgreSQL is enabled, is not using an external database, and the global Gateway API toggle is on.

## What Gateway API Cannot Do

Gateway API does not cover every protocol. NFS requires UDP on multiple ports (111, 2049, 32765, 32767), and the Gateway API UDPRoute type is not implemented by most controllers including Envoy Gateway. The Storagebox NFS server stays on NodePort services for this reason.

When a service requires a protocol that Gateway API does not support, use a direct NodePort or LoadBalancer Service and skip the Gateway entirely. The two approaches coexist without conflict.

## Key Considerations

- **TCPRoute is experimental (as of February 2026).** It uses `gateway.networking.k8s.io/v1alpha2` and requires the experimental channel CRDs to be present in the cluster. Envoy Gateway bundles these automatically. Other controllers like Traefik support TCPRoute but require the CRDs to be installed separately -- via a dedicated Helm chart, `kubectl apply`, or your application chart's `crds/` directory. Check the [Gateway API releases page](https://github.com/kubernetes-sigs/gateway-api/releases) for the current status of TCPRoute promotion to the standard channel.
- **Each Gateway creates an Envoy proxy.** Four Gateways means four Envoy Deployments. On resource-constrained single-node clusters, consolidating HTTP services into one Gateway with multiple HTTPRoutes (differentiated by hostname) is more efficient.
- **CRD installation timing matters.** In Embedded Cluster deployments, the Gateway API CRDs are installed by the controller's EC extension. If the application chart deploys before the CRDs are registered, Helm will fail with "no matches for kind." A retry from the Admin Console resolves this.
- **NodePort is the default for EC.** Without a cloud load balancer, the EnvoyProxy resource configures Envoy Services as NodePort. Clients connect via `<node-ip>:<port>`.
- **The builder key must enable all Gateways.** For air-gap image discovery, the HelmChart `builder` values must set all gateway and application toggles to `true` so that every template renders during `helm template`.
