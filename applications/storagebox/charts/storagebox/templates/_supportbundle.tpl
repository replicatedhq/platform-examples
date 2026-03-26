{{/*
Support bundle spec - defines collectors and analyzers for troubleshooting.
Included into a Secret by replicated-supportbundle.yaml.
*/}}
{{- define "storagebox.supportbundle" -}}
kind: SupportBundle
apiVersion: troubleshoot.sh/v1beta2
metadata:
  name: storagebox
spec:
  uri: https://raw.githubusercontent.com/replicatedhq/platform-examples/main/applications/storagebox/charts/storagebox/templates/_supportbundle.tpl
  collectors:
    - clusterInfo: {}
    - clusterResources: {}
    # -- Cassandra data pods (managed by cass-operator in the app namespace)
    - logs:
        name: cassandra/data-pods
        selector:
          - app.kubernetes.io/managed-by=cass-operator
          - app.kubernetes.io/name=cassandra
        limits:
          maxLines: 10000
    # -- k8ssandra-operator pods
    - logs:
        name: k8ssandra-operator/operator
        namespace: k8ssandra-operator
        selector:
          - app.kubernetes.io/name=k8ssandra-operator
        limits:
          maxLines: 10000
    # -- cass-operator pods (deployed as part of k8ssandra-operator chart)
    - logs:
        name: k8ssandra-operator/cass-operator
        namespace: k8ssandra-operator
        selector:
          - app.kubernetes.io/name=cass-operator
        limits:
          maxLines: 10000
    # -- CloudnativePG operator pods
    - logs:
        name: cnpg/operator
        namespace: cnpg
        selector:
          - app.kubernetes.io/name=cloudnative-pg
        limits:
          maxLines: 10000
    # -- PostgreSQL cluster pods (managed by CNPG in the app namespace)
    - logs:
        name: postgres/cluster-pods
        selector:
          - app.kubernetes.io/managed-by=cloudnative-pg
        limits:
          maxLines: 10000
    # -- Garage S3 storage pods
    - logs:
        name: garage/pods
        selector:
          - app.kubernetes.io/name=garage
        limits:
          maxLines: 10000
    # -- Garage setup job pods
    - logs:
        name: garage/setup-job
        selector:
          - app.kubernetes.io/component=garage-setup
        limits:
          maxLines: 10000
    # -- rqlite pods
    - logs:
        name: rqlite/pods
        selector:
          - app.kubernetes.io/name=storagebox
          - app.kubernetes.io/component=voter
        limits:
          maxLines: 10000
    # -- cert-manager pods
    - logs:
        name: cert-manager/pods
        namespace: cert-manager
        selector:
          - app.kubernetes.io/instance=cert-manager
        limits:
          maxLines: 10000
    # -- Envoy Gateway controller pods
    - logs:
        name: envoy-gateway/controller
        namespace: envoy-gateway-system
        selector:
          - app.kubernetes.io/name=gateway-helm
        limits:
          maxLines: 10000
    # -- Envoy proxy pods (provisioned per-Gateway in the EG namespace)
    - logs:
        name: envoy-gateway/proxy-pods
        namespace: envoy-gateway-system
        selector:
          - app.kubernetes.io/managed-by=envoy-gateway
        limits:
          maxLines: 10000
    # -- NFS server pods
    {{- if (index .Values "nfs-server" "enabled") }}
    - logs:
        name: nfs-server/pods
        selector:
          - app.kubernetes.io/name=nfs-server
        limits:
          maxLines: 10000
    {{- end }}
    # -- Preflight re-checks (verify environment hasn't drifted post-install)
    {{- if (index .Values "nfs-server" "enabled") }}
    - runPod:
        name: nfs-kernel-check
        namespace: default
        timeout: 30s
        podSpec:
          containers:
            - name: nfs-kernel-check
              image: {{ .Values.images.alpine.repository }}:{{ .Values.images.alpine.tag }}
              command: ["sh", "-c", "cat /proc/filesystems 2>/dev/null; cat /proc/modules 2>/dev/null"]
    {{- end }}
  analyzers:
    - clusterVersion:
        outcomes:
          - fail:
              when: "< 1.21.0"
              message: The application requires at Kubernetes 1.21.0 or later, and recommends 1.28.0.
              uri: https://www.kubernetes.io
          - warn:
              when: "< 1.28.0"
              message: Your cluster meets the minimum version of Kubernetes, but we recommend you update to 1.28.0 or later.
              uri: https://kubernetes.io
          - pass:
              message: Your cluster meets the recommended and required versions of Kubernetes.
    # -- Infrastructure deployment health
    - deploymentStatus:
        name: cert-manager
        namespace: cert-manager
        outcomes:
          - fail:
              when: "< 1"
              message: cert-manager is not running. TLS certificate provisioning will not work.
          - pass:
              message: cert-manager is running.
    - deploymentStatus:
        name: cert-manager-webhook
        namespace: cert-manager
        outcomes:
          - fail:
              when: "< 1"
              message: cert-manager webhook is not running.
          - pass:
              message: cert-manager webhook is running.
    - deploymentStatus:
        name: cloudnative-pg
        namespace: cnpg
        outcomes:
          - fail:
              when: "< 1"
              message: CloudnativePG operator is not running. PostgreSQL clusters cannot be managed.
          - pass:
              message: CloudnativePG operator is running.
    - deploymentStatus:
        name: envoy-gateway
        namespace: envoy-gateway-system
        outcomes:
          - fail:
              when: "< 1"
              message: Envoy Gateway controller is not running. Gateway API routing will not work.
          - pass:
              message: Envoy Gateway controller is running.
    - deploymentStatus:
        name: k8ssandra-operator
        namespace: k8ssandra-operator
        outcomes:
          - fail:
              when: "< 1"
              message: K8ssandra operator is not running. Cassandra clusters cannot be managed.
          - pass:
              message: K8ssandra operator is running.
    - deploymentStatus:
        name: k8ssandra-operator-cass-operator
        namespace: k8ssandra-operator
        outcomes:
          - fail:
              when: "< 1"
              message: cass-operator is not running. Cassandra pod lifecycle management will not work.
          - pass:
              message: cass-operator is running.
    # -- Application deployment health
    {{- if .Values.garage.enabled }}
    - statefulsetStatus:
        name: {{ .Release.Name }}-garage
        namespace: {{ .Release.Namespace }}
        outcomes:
          - fail:
              when: "< 1"
              message: Garage S3 storage is not running.
          - pass:
              message: Garage S3 storage is running.
    {{- end }}
    {{- if .Values.rqlite.enabled }}
    - statefulsetStatus:
        name: {{ include "storagebox.fullname" . }}-rqlite
        namespace: {{ .Release.Namespace }}
        outcomes:
          - fail:
              when: "< 1"
              message: rqlite is not running.
          - pass:
              message: rqlite is running.
    {{- end }}
    # -- Resource preflights (verify environment hasn't drifted post-install)
    - nodeResources:
        checkName: Total CPU Cores in the cluster is 2 or greater
        outcomes:
          - fail:
              when: "sum(cpuCapacity) < 2"
              message: The cluster must contain at least 2 cores
          - pass:
              message: There are at least 2 cores in the cluster
    {{- if .Values.cassandra.enabled }}
    - nodeResources:
        checkName: Cluster CPU capacity for Cassandra
        outcomes:
          - fail:
              when: "sum(cpuCapacity) < 4"
              message: Cassandra requires at least 4 CPU cores across the cluster. The K8ssandra operator init containers request 1 full CPU, and the Cassandra server requires additional CPU alongside other cluster workloads.
          - warn:
              when: "sum(cpuCapacity) < 6"
              message: Cassandra is functional with 4 CPU cores but 6+ is recommended for production workloads with Reaper repairs enabled.
          - pass:
              message: The cluster has sufficient total CPU capacity for Cassandra workloads.
    - nodeResources:
        checkName: Node CPU capacity for Cassandra scheduling
        outcomes:
          - fail:
              when: "max(cpuAllocatable) < 2"
              message: No node has at least 2 allocatable CPU cores. Cassandra pods require 1 CPU for init containers and additional CPU for the server process. Use a VM with at least 4 CPUs (r1.medium or larger).
          - warn:
              when: "max(cpuAllocatable) < 3"
              message: The largest node has less than 3 allocatable CPU cores. Cassandra will be tight on resources and may experience slow startup or scheduling delays.
          - pass:
              message: At least one node has sufficient allocatable CPU for Cassandra pods.
    {{- end }}
    - nodeResources:
        checkName: Cluster memory capacity
        outcomes:
          - fail:
              when: "sum(memoryCapacity) < 4Gi"
              message: The cluster requires at least 4 GiB of memory. StorageBox runs multiple storage backends (Cassandra, PostgreSQL, Garage) plus cluster operators, each requiring significant memory.
          - warn:
              when: "sum(memoryCapacity) < 8Gi"
              message: The cluster has less than 8 GiB of memory. 8 GiB or more is recommended when running multiple storage backends simultaneously.
          - pass:
              message: The cluster has sufficient memory capacity.
    - nodeResources:
        checkName: Node memory for pod scheduling
        outcomes:
          - fail:
              when: "max(memoryAllocatable) < 2Gi"
              message: No node has at least 2 GiB of allocatable memory. Storage backend pods (especially Cassandra with its 512M JVM heap) require significant memory to schedule and run.
          - warn:
              when: "max(memoryAllocatable) < 4Gi"
              message: The largest node has less than 4 GiB of allocatable memory. Pods may experience OOM kills under load.
          - pass:
              message: At least one node has sufficient allocatable memory for storage backend pods.
    {{- if .Values.postgres.embedded.enabled }}
    - nodeResources:
        checkName: Cluster memory capacity for PostgreSQL
        outcomes:
          - fail:
              when: "sum(memoryCapacity) < 2Gi"
              message: PostgreSQL requires at least 2 GiB of cluster memory. CloudnativePG pods need memory for shared buffers and connection handling.
          - pass:
              message: The cluster has sufficient memory for PostgreSQL.
    - clusterVersion:
        checkName: CloudnativePG operator CRD available
        outcomes:
          - fail:
              when: "< 1.21.0"
              message: CloudnativePG requires Kubernetes 1.21.0 or later.
          - pass:
              message: Kubernetes version is compatible with CloudnativePG.
    {{- end }}
    {{- if .Values.garage.enabled }}
    - nodeResources:
        checkName: Cluster memory capacity for Garage
        outcomes:
          - fail:
              when: "sum(memoryCapacity) < 2Gi"
              message: Garage requires at least 2 GiB of cluster memory for the LMDB metadata engine and S3 request handling.
          - pass:
              message: The cluster has sufficient memory for Garage.
    {{- end }}
    {{- if .Values.rqlite.enabled }}
    - nodeResources:
        checkName: Cluster resources for rqlite
        outcomes:
          - fail:
              when: "sum(cpuCapacity) < 2"
              message: rqlite requires at least 2 CPU cores across the cluster.
          - pass:
              message: The cluster has sufficient CPU for rqlite.
    {{- end }}
    {{- if (index .Values "nfs-server" "enabled") }}
    - textAnalyze:
        checkName: NFS kernel module available
        fileName: nfs-kernel-check/nfs-kernel-check.log
        regex: "\tnfs[4\t ]"
        outcomes:
          - pass:
              when: "true"
              message: NFS kernel support detected.
          - warn:
              when: "false"
              message: NFS kernel support was not detected. The NFS server requires the nfs kernel module to be loaded or available in the host kernel. On minimal VM kernels (e.g., CMX runners with kernel 5.15), the nfs module may not be included. Verify on the host with 'modprobe nfs' or 'cat /proc/filesystems | grep nfs'.
    {{- end }}
    - storageClass:
        checkName: Check for default storage class
        outcomes:
          - fail:
              message: No default storage class found
          - pass:
              message: Default storage class found
{{- end }}
