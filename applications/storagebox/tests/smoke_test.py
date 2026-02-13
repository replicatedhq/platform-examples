#!/usr/bin/env python3
"""Storagebox smoke test.

Validates that all enabled storage components are reachable after a Helm install.
Each component is tested via kubectl port-forward with a dynamically allocated
local port.  Service names are discovered via label selectors so the tests are
resilient to operator-generated naming changes.

Usage:
    python smoke_test.py <namespace> [--kubeconfig PATH] [--timeout 120]
"""

import argparse
import json
import logging
import os
import socket
import subprocess
import sys
import time
from contextlib import contextmanager

import requests
import urllib3

# Self-signed certs are expected in test environments (MinIO auto-generates them)
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

KUBECTL = os.environ.get("KUBECTL", "kubectl")


def _kubectl(*args, kubeconfig=None, namespace=None):
    """Run a kubectl command and return stdout."""
    cmd = [KUBECTL]
    if kubeconfig:
        cmd += ["--kubeconfig", kubeconfig]
    if namespace:
        cmd += ["-n", namespace]
    cmd += list(args)
    log.debug("exec: %s", " ".join(cmd))
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    if result.returncode != 0:
        log.warning("kubectl stderr: %s", result.stderr.strip())
    return result.stdout.strip()


def discover_service(namespace, label_selector, kubeconfig=None, prefer_port=None):
    """Return (service_name, port) for the first non-headless service matching *label_selector*.

    If *prefer_port* is given, look for that port number among the service's
    ports instead of blindly returning the first one.
    """
    raw = _kubectl(
        "get", "svc",
        "-l", label_selector,
        "-o", "json",
        kubeconfig=kubeconfig,
        namespace=namespace,
    )
    if not raw:
        return None, None
    data = json.loads(raw)
    items = data.get("items", [])
    if not items:
        return None, None
    # Prefer non-headless (clusterIP != "None") services
    non_headless = [s for s in items if s.get("spec", {}).get("clusterIP") != "None"]
    if non_headless:
        candidates = non_headless
    else:
        # All headless - prefer those that actually define ports
        with_ports = [s for s in items if s.get("spec", {}).get("ports")]
        candidates = with_ports or items
    # If prefer_port is set, try to find a service that exposes it
    if prefer_port:
        for svc in candidates:
            for p in svc.get("spec", {}).get("ports", []):
                if p.get("port") == prefer_port:
                    return svc["metadata"]["name"], prefer_port
    svc = candidates[0]
    name = svc["metadata"]["name"]
    ports = svc.get("spec", {}).get("ports", [])
    port = ports[0]["port"] if ports else None
    return name, port


def _free_port():
    """Get a free TCP port on localhost."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        return s.getsockname()[1]


@contextmanager
def port_forward(namespace, service, remote_port, kubeconfig=None):
    """Context manager that runs ``kubectl port-forward`` and yields the local port."""
    local_port = _free_port()
    cmd = [KUBECTL]
    if kubeconfig:
        cmd += ["--kubeconfig", kubeconfig]
    cmd += [
        "-n", namespace,
        "port-forward",
        f"svc/{service}",
        f"{local_port}:{remote_port}",
    ]
    log.info("port-forward %s:%s -> localhost:%s", service, remote_port, local_port)
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    # Give port-forward a moment to bind
    time.sleep(2)
    try:
        yield local_port
    finally:
        proc.terminate()
        proc.wait(timeout=5)


def tcp_check(host, port, timeout=5):
    """Return True if a TCP connection can be established."""
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except (socket.timeout, OSError):
        return False


# ---------------------------------------------------------------------------
# Component checks
# ---------------------------------------------------------------------------

def check_postgres(namespace, kubeconfig, timeout):
    """TCP connect to PostgreSQL on port 5432."""
    svc_name = "postgres-nodeport"  # created by our chart template
    port = 5432
    log.info("[postgres] using service %s:%s", svc_name, port)
    return _retry_port_forward_tcp(namespace, svc_name, port, kubeconfig, timeout)


def check_minio(namespace, kubeconfig, timeout):
    """HTTPS GET /minio/health/live on the MinIO tenant service."""
    # MinIO operator creates a service named "minio" in the release namespace
    svc_name, svc_port = discover_service(
        namespace, "v1.min.io/tenant=minio", kubeconfig=kubeconfig,
    )
    if not svc_name:
        # Fallback to well-known name
        svc_name, svc_port = "minio", 443
    log.info("[minio] discovered service %s:%s", svc_name, svc_port)
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with port_forward(namespace, svc_name, svc_port, kubeconfig) as lp:
                url = f"https://localhost:{lp}/minio/health/live"
                resp = requests.get(url, verify=False, timeout=5)
                if resp.status_code == 200:
                    log.info("[minio] health check passed (HTTP %s)", resp.status_code)
                    return True
                log.warning("[minio] unexpected status %s", resp.status_code)
        except Exception as exc:
            log.debug("[minio] attempt failed: %s", exc)
        time.sleep(5)
    return False


def check_nfs(namespace, kubeconfig, timeout):
    """TCP connect to the NFS server on port 2049."""
    # The nfs-server subchart creates a service whose name is templated from
    # the release.  Try label-based discovery first.
    svc_name, svc_port = discover_service(
        namespace, "app.kubernetes.io/name=nfs-server", kubeconfig=kubeconfig,
        prefer_port=2049,
    )
    if not svc_name:
        svc_name, svc_port = "storagebox-nfs-server", 2049
    svc_port = svc_port or 2049
    log.info("[nfs] discovered service %s:%s", svc_name, svc_port)
    return _retry_port_forward_tcp(namespace, svc_name, svc_port, kubeconfig, timeout)


def check_rqlite(namespace, kubeconfig, timeout):
    """HTTP GET /status on the rqlite service."""
    # The rqlite subchart labels services with the release name as
    # app.kubernetes.io/name, not "rqlite".  Use the chart label instead.
    svc_name, svc_port = discover_service(
        namespace, "helm.sh/chart=rqlite-2.0.0,app.kubernetes.io/component=voter", kubeconfig=kubeconfig,
    )
    if not svc_name:
        svc_name, svc_port = "storagebox-rqlite", 80
    svc_port = svc_port or 80
    log.info("[rqlite] discovered service %s:%s", svc_name, svc_port)
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with port_forward(namespace, svc_name, svc_port, kubeconfig) as lp:
                resp = requests.get(f"http://localhost:{lp}/status", timeout=5)
                if resp.status_code == 200:
                    log.info("[rqlite] status check passed (HTTP %s)", resp.status_code)
                    return True
                log.warning("[rqlite] unexpected status %s", resp.status_code)
        except Exception as exc:
            log.debug("[rqlite] attempt failed: %s", exc)
        time.sleep(5)
    return False


def check_cassandra(namespace, kubeconfig, timeout):
    """TCP connect to the K8ssandra CQL service on port 9042."""
    # Use datacenter label to target the DC-level service which has the CQL port.
    # The cluster-level label also matches seed services that have no ports.
    svc_name, svc_port = discover_service(
        namespace,
        "cassandra.datastax.com/cluster=storagebox-cassandra,cassandra.datastax.com/datacenter=dc1",
        kubeconfig=kubeconfig,
        prefer_port=9042,
    )
    if not svc_name:
        svc_name, svc_port = "storagebox-cassandra-dc1-service", 9042
    svc_port = svc_port or 9042
    log.info("[cassandra] discovered service %s:%s", svc_name, svc_port)
    return _retry_port_forward_tcp(namespace, svc_name, svc_port, kubeconfig, timeout)


# ---------------------------------------------------------------------------
# Retry helper
# ---------------------------------------------------------------------------

def _retry_port_forward_tcp(namespace, svc_name, svc_port, kubeconfig, timeout):
    """Retry TCP connect through port-forward until *timeout*."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with port_forward(namespace, svc_name, svc_port, kubeconfig) as lp:
                if tcp_check("localhost", lp):
                    log.info("[%s] TCP connect succeeded on port %s", svc_name, svc_port)
                    return True
        except Exception as exc:
            log.debug("[%s] attempt failed: %s", svc_name, exc)
        time.sleep(5)
    return False


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

COMPONENTS = {
    "postgres": check_postgres,
    "minio": check_minio,
    "nfs": check_nfs,
    "rqlite": check_rqlite,
    "cassandra": check_cassandra,
}


def main():
    parser = argparse.ArgumentParser(description="Storagebox smoke tests")
    parser.add_argument("namespace", help="Kubernetes namespace where storagebox is installed")
    parser.add_argument("--kubeconfig", default=os.environ.get("KUBECONFIG"), help="Path to kubeconfig file")
    parser.add_argument("--timeout", type=int, default=120, help="Per-component timeout in seconds (default: 120)")
    parser.add_argument("--components", nargs="*", choices=list(COMPONENTS.keys()), help="Test only specific components")
    parser.add_argument("--debug", action="store_true", help="Enable debug logging")
    args = parser.parse_args()

    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)

    targets = args.components or list(COMPONENTS.keys())
    results = {}

    for name in targets:
        log.info("--- Testing %s ---", name)
        try:
            ok = COMPONENTS[name](args.namespace, args.kubeconfig, args.timeout)
        except Exception as exc:
            log.error("[%s] unexpected error: %s", name, exc)
            ok = False
        results[name] = ok
        status = "PASS" if ok else "FAIL"
        log.info("[%s] %s", name, status)

    log.info("--- Results ---")
    all_pass = True
    for name, ok in results.items():
        status = "PASS" if ok else "FAIL"
        log.info("  %-12s %s", name, status)
        if not ok:
            all_pass = False

    if all_pass:
        log.info("All component checks passed.")
        sys.exit(0)
    else:
        log.error("One or more component checks failed.")
        sys.exit(1)


if __name__ == "__main__":
    main()
