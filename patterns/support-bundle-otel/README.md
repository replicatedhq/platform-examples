# Collecting OpenTelemetry Data in Support Bundles

If your application is instrumented with OpenTelemetry, you might be collecting traces, metrics, and logs in a SaaS observability platform or your own self-hosted backend. That works well for real-time monitoring. When troubleshooting customer issues, having that telemetry data in the support bundle alongside traditional cluster diagnostics (pod logs, resource specs, etc.) shows you what the application was actually doing. You can see which requests were slow, what errors occurred, which services were involved.

The challenge is that OpenTelemetry data usually flows through the system and ends up somewhere else. It's not sitting around in files waiting to be collected by `kubectl support-bundle`.

## The Approach

Run an OpenTelemetry Collector that writes telemetry to local files. Then use Troubleshoot's `copy` collector to grab those files when generating a support bundle.

The collector can write to files and optionally forward data to other backends simultaneously. When a support bundle is generated, you get a snapshot of recent telemetry data. The last few minutes or hours, depending on how much data you're collecting and how you configure file rotation.

The setup uses a two-container pod:
- **otel-collector** receives OTLP data from your apps and exports it to files
- **file-sidecar** keeps running so the support bundle can copy files from it

Both containers share an `emptyDir` volume where the JSONL files live.

```
Your App → OTel Collector → writes JSONL files → Support Bundle copies them
                ↓
         (optionally forwards to other backends)
```

This approach is non-intrusive. Your applications don't need to know about it. They keep sending OTLP data as normal. The collector handles the file export transparently.

## OTel Collector Configuration

The OpenTelemetry Collector needs to be configured to write telemetry to files. The `file` exporter takes the telemetry data and appends it to JSONL (JSON Lines) files, one line per span/metric/log entry.

This configuration writes traces, metrics, and logs to separate files:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 1s
    send_batch_size: 1024

exporters:
  file/traces:
    path: /var/log/otel/traces.jsonl
    format: json

  file/metrics:
    path: /var/log/otel/metrics.jsonl
    format: json

  file/logs:
    path: /var/log/otel/logs.jsonl
    format: json

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [file/traces]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [file/metrics]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [file/logs]
```

All three pipelines write to files on disk. These files live on a volume that's shared with the sidecar container.

To forward data to an observability backend, add more exporters to the pipeline. For example, to send traces to an OTLP-compatible backend:

```yaml
exporters:
  file/traces:
    path: /var/log/otel/traces.jsonl
    format: json

  otlp/backend:
    endpoint: https://your-backend:4317
    tls:
      insecure: false

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [file/traces, otlp/backend]  # both destinations
```

## Deployment Setup

The deployment runs two containers in the same pod, sharing an `emptyDir` volume. The collector writes to the volume, and the sidecar keeps the pod alive so the support bundle tooling can copy files from it.

The sidecar exists because Troubleshoot's `copy` collector works by exec'ing into a running container and copying files out. The collector container image might not have the binaries that Troubleshoot needs (like `tar` or `sh`). The sidecar provides a minimal container with standard tools that's always available for file access.

Full deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
spec:
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      volumes:
        - name: otel-data
          emptyDir: {}
        - name: otel-config
          configMap:
            name: otel-collector-config

      containers:
        - name: otel-collector
          image: otel/opentelemetry-collector-contrib:0.91.0
          command:
            - "/otelcol-contrib"
            - "--config=/etc/otel-config/config.yaml"
          volumeMounts:
            - name: otel-config
              mountPath: /etc/otel-config
            - name: otel-data
              mountPath: /var/log/otel
          ports:
            - containerPort: 4317
              name: otlp-grpc
            - containerPort: 4318
              name: otlp-http
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"

        - name: file-sidecar
          image: busybox:1.35
          command: ["sh", "-c", "while true; do sleep 60; done"]
          volumeMounts:
            - name: otel-data
              mountPath: /var/log/otel
```

The file-sidecar container just sleeps forever. It keeps the pod alive so the support bundle can exec into it and copy files.

## Service

Expose the collector so applications can send data to it:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: otel-collector
spec:
  selector:
    app: otel-collector
  ports:
    - name: otlp-grpc
      port: 4317
      targetPort: otlp-grpc
    - name: otlp-http
      port: 4318
      targetPort: otlp-http
```

## Support Bundle Configuration

Use the `copy` collector to grab files from the sidecar container:

```yaml
apiVersion: troubleshoot.sh/v1beta2
kind: SupportBundle
metadata:
  name: my-app-bundle
spec:
  collectors:
    - copy:
        name: otel-traces
        selector:
          - app=otel-collector
        namespace: otel-system
        containerPath: /var/log/otel/traces.jsonl
        containerName: file-sidecar

    - copy:
        name: otel-metrics
        selector:
          - app=otel-collector
        namespace: otel-system
        containerPath: /var/log/otel/metrics.jsonl
        containerName: file-sidecar

    - copy:
        name: otel-logs
        selector:
          - app=otel-collector
        namespace: otel-system
        containerPath: /var/log/otel/logs.jsonl
        containerName: file-sidecar

    - exec:
        name: otel-file-listing
        selector:
          - app=otel-collector
        namespace: otel-system
        containerName: file-sidecar
        command: ["ls"]
        args: ["-la", "/var/log/otel/"]
        timeout: 10s

    - logs:
        name: otel-collector-logs
        selector:
          - app=otel-collector
        namespace: otel-system
        containerName: otel-collector
        limits:
          maxAge: 24h
          maxLines: 1000

    - http:
        collectorName: otel-health
        get:
          url: http://otel-collector.otel-system.svc.cluster.local:4318
          timeout: 10s
```

## Configuring Your Applications

Once the collector is deployed, your applications need to know where to send their telemetry. OpenTelemetry SDKs support configuration via environment variables.

The two key variables are:
- `OTEL_EXPORTER_OTLP_ENDPOINT`: where to send telemetry (your collector's service)
- `OTEL_SERVICE_NAME`: identifies your application in traces and metrics

In a Kubernetes deployment:

```yaml
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://otel-collector.otel-system.svc.cluster.local:4318"
  - name: OTEL_SERVICE_NAME
    value: "my-service"
```

The endpoint uses port 4318 (HTTP) in this example. If your SDK uses gRPC by default, point it to port 4317 instead. Many SDKs auto-detect the protocol based on what the endpoint responds with.

This collector can sit between your applications and any existing backend. Update the application endpoint to point to this collector. It'll write to files and forward to other backends if you configure multiple exporters in the pipeline.

## Things to Watch Out For

**File sizes can get large.** Telemetry data adds up fast, especially traces. Applications can generate hundreds of megabytes per hour. Support bundles can become large and emptyDir volumes can fill up.

To manage this:
- Configure the file exporter with `rotation` settings (max file size, number of backups)
- Use sampling in your applications (probabilistic or tail-based) to reduce trace volume
- Only collect recent data. Set the file exporter to overwrite old files instead of appending forever
- Consider only copying the most recent data in your support bundle spec

**The sidecar uses minimal resources.** It just sleeps, so resource usage is negligible. If you're using autoscaling or spot instances, the pod won't scale down to zero while the sidecar is running.

**Security matters.** Telemetry data can contain sensitive information: HTTP headers, database query parameters, user IDs, API keys, etc. Consider what data is being exposed in support bundles.

Things to consider:
- Configure attribute filtering in the OTel Collector to remove sensitive fields before writing to files
- Restrict RBAC permissions on who can generate support bundles
- Use network policies to limit which pods can send data to the collector
- Document for customers what data is being collected and where it goes

**Connectivity issues.** If applications can't reach the collector, OpenTelemetry SDKs typically log warnings but continue running (graceful degradation). Telemetry data won't be in the support bundle if the collector was down when the issue occurred. The HTTP health check in the support bundle spec helps verify the collector is reachable.

## Why This Works

The `copy` collector in Troubleshoot works by exec'ing into a running container and copying files out, similar to how `kubectl cp` works. This means we need:
1. A container that's running and will stay running
2. Files that are accessible from that container's filesystem
3. Stable file paths that the support bundle spec can reference

The sidecar pattern gives us all three. The OTel Collector writes to `/var/log/otel/*.jsonl` on a shared volume, the sidecar mounts that same volume at the same path, and the sidecar stays alive indefinitely.

When someone generates a support bundle, Troubleshoot finds pods matching the selector, exec's into the `file-sidecar` container, and copies the JSONL files out. The files are included in the support bundle tarball alongside all the other diagnostics.

This approach is simpler than trying to query a remote observability backend at bundle-generation time. You'd need credentials, network access, a query API, and logic to figure out the right time range. The backend might be down or the customer might be air-gapped. With files in the cluster, the data is there when you need it.

## Testing It

Deploy everything and generate a test support bundle:

```bash
kubectl support-bundle ./support-bundle.yaml
```

Unpack the resulting tarball and look for your telemetry files:

```bash
tar -xzf support-bundle-*.tar.gz
cd support-bundle-*/
ls -l otel-system/otel-collector-*/file-sidecar/var/log/otel/
```

Look for `traces.jsonl`, `metrics.jsonl`, and `logs.jsonl` files.
