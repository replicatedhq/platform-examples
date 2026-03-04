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
    # -- MinIO operator pods
    - logs:
        name: minio/operator
        namespace: minio
        selector:
          - app.kubernetes.io/name=operator
        limits:
          maxLines: 10000
    # -- MinIO tenant pods (in the app namespace)
    - logs:
        name: minio/tenant-pods
        selector:
          - v1.min.io/tenant
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
    # -- ingress-nginx pods
    - logs:
        name: ingress-nginx/pods
        namespace: ingress-nginx
        selector:
          - app.kubernetes.io/instance=ingress-nginx
        limits:
          maxLines: 10000
    # -- Preflight re-checks (verify environment hasn't drifted post-install)
    {{- if (index .Values "nfs-server" "enabled") }}
    - runPod:
        name: nfs-kernel-check
        namespace: default
        timeout: 30s
        podSpec:
          containers:
            - name: nfs-kernel-check
              image: {{ .Values.images.busybox.repository }}:{{ .Values.images.busybox.tag }}
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
    # -- Preflight re-checks (verify environment hasn't drifted post-install)
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
              message: The cluster requires at least 4 GiB of memory. StorageBox runs multiple storage backends (Cassandra, PostgreSQL, MinIO) plus cluster operators, each requiring significant memory.
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
    {{- if .Values.tenant.enabled }}
    - nodeResources:
        checkName: Cluster memory capacity for MinIO
        outcomes:
          - fail:
              when: "sum(memoryCapacity) < 2Gi"
              message: MinIO requires at least 2 GiB of cluster memory. Each MinIO server pod needs memory for object caching and request handling.
          - pass:
              message: The cluster has sufficient memory for MinIO.
    - nodeResources:
        checkName: Cluster storage for MinIO
        outcomes:
          - fail:
              when: "sum(ephemeralStorageCapacity) < 10Gi"
              message: MinIO requires at least 10 GiB of storage capacity for tenant volumes.
          - pass:
              message: The cluster has sufficient storage capacity for MinIO.
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
