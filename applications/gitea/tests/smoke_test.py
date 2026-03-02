#!/usr/bin/env python3
"""Smoke tests for the Gitea Helm chart.

Validates that the three core components are reachable after a Helm install:
  - Gitea HTTP (web UI / API on port 3000)
  - PostgreSQL via CloudNativePG (port 5432)
  - Valkey cache (Redis-compatible, port 6379)

Usage:
    python smoke_test.py [--namespace NAMESPACE] [--release RELEASE]
"""

import argparse
import json
import logging
import socket
import subprocess
import sys
import time

import requests

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _kubectl(args: list[str], namespace: str | None = None) -> str:
    """Run a kubectl command and return stdout."""
    cmd = ["kubectl"]
    if namespace:
        cmd += ["-n", namespace]
    cmd += args
    log.debug("Running: %s", " ".join(cmd))
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return result.stdout.strip()


def discover_service(
    namespace: str,
    label_selector: str,
    fallback_name: str,
    name_contains: str | None = None,
) -> str:
    """Find a service by label selector, falling back to a known name.

    If *name_contains* is given, only services whose name includes that
    substring are considered (useful for picking the CNPG ``-rw`` service
    out of the ``-r``, ``-ro``, ``-rw`` triple).
    """
    try:
        out = _kubectl(
            ["get", "svc", "-l", label_selector, "-o", "json"],
            namespace=namespace,
        )
        services = json.loads(out)
        items = services.get("items", [])
        if name_contains:
            items = [i for i in items if name_contains in i["metadata"]["name"]]
        if items:
            name = items[0]["metadata"]["name"]
            log.info("Discovered service %s via labels '%s'", name, label_selector)
            return name
    except (subprocess.CalledProcessError, json.JSONDecodeError, KeyError) as exc:
        log.warning("Label-based discovery failed (%s), using fallback: %s", exc, fallback_name)
    return fallback_name


def _free_port() -> int:
    """Return an available TCP port on localhost."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


class PortForward:
    """Context manager that runs ``kubectl port-forward`` in the background."""

    def __init__(self, namespace: str, service: str, remote_port: int):
        self.namespace = namespace
        self.service = service
        self.remote_port = remote_port
        self.local_port = _free_port()
        self._proc: subprocess.Popen | None = None

    def __enter__(self):
        cmd = [
            "kubectl", "-n", self.namespace,
            "port-forward", f"svc/{self.service}",
            f"{self.local_port}:{self.remote_port}",
        ]
        log.info("Starting port-forward: %s", " ".join(cmd))
        self._proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        # Give the tunnel a moment to establish.
        time.sleep(3)
        if self._proc.poll() is not None:
            stderr = self._proc.stderr.read().decode() if self._proc.stderr else ""
            raise RuntimeError(f"port-forward exited immediately: {stderr}")
        return self

    def __exit__(self, *_exc):
        if self._proc and self._proc.poll() is None:
            self._proc.terminate()
            self._proc.wait(timeout=5)


def tcp_check(host: str, port: int, timeout: float = 5.0) -> bool:
    """Return True if a TCP connection to host:port succeeds."""
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def _retry(fn, description: str, retries: int = 10, interval: float = 3.0):
    """Retry *fn* until it returns a truthy value or we run out of attempts."""
    for attempt in range(1, retries + 1):
        log.info("[%d/%d] %s", attempt, retries, description)
        try:
            result = fn()
            if result:
                return result
        except Exception as exc:
            log.warning("  attempt %d failed: %s", attempt, exc)
        if attempt < retries:
            time.sleep(interval)
    raise RuntimeError(f"All {retries} attempts failed: {description}")


# ---------------------------------------------------------------------------
# Component checks
# ---------------------------------------------------------------------------

def check_gitea(namespace: str, release: str) -> bool:
    """Verify Gitea HTTP is responding via /api/v1/version."""
    svc = discover_service(
        namespace,
        label_selector=f"app.kubernetes.io/name=gitea,app.kubernetes.io/instance={release}",
        fallback_name=f"{release}-http",
        name_contains="-http",
    )
    with PortForward(namespace, svc, 3000) as pf:
        def _probe():
            url = f"http://127.0.0.1:{pf.local_port}/api/v1/version"
            resp = requests.get(url, timeout=5)
            resp.raise_for_status()
            data = resp.json()
            log.info("Gitea version: %s", data.get("version", "unknown"))
            return True

        _retry(_probe, "Checking Gitea HTTP /api/v1/version")
    log.info("Gitea HTTP check passed")
    return True


def check_postgres(namespace: str, release: str) -> bool:
    """Verify PostgreSQL (CNPG) is accepting TCP connections on port 5432."""
    svc = discover_service(
        namespace,
        label_selector=f"cnpg.io/cluster={release}-postgres",
        fallback_name=f"{release}-postgres-rw",
        name_contains="-rw",
    )
    with PortForward(namespace, svc, 5432) as pf:
        def _probe():
            return tcp_check("127.0.0.1", pf.local_port)

        _retry(_probe, "Checking PostgreSQL TCP connectivity")
    log.info("PostgreSQL check passed")
    return True


def check_valkey(namespace: str, release: str) -> bool:
    """Verify Valkey is accepting TCP connections on port 6379."""
    svc = discover_service(
        namespace,
        label_selector=f"app.kubernetes.io/name=valkey,app.kubernetes.io/instance={release}",
        fallback_name=f"{release}-valkey",
    )
    with PortForward(namespace, svc, 6379) as pf:
        def _probe():
            return tcp_check("127.0.0.1", pf.local_port)

        _retry(_probe, "Checking Valkey TCP connectivity")
    log.info("Valkey check passed")
    return True


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Gitea Helm chart smoke tests")
    parser.add_argument("--namespace", default="default", help="Kubernetes namespace")
    parser.add_argument("--release", default="gitea", help="Helm release name")
    args = parser.parse_args()

    checks = [
        ("Gitea HTTP", check_gitea),
        ("PostgreSQL", check_postgres),
        ("Valkey", check_valkey),
    ]

    failed = []
    for name, fn in checks:
        log.info("--- Running check: %s ---", name)
        try:
            fn(args.namespace, args.release)
        except Exception as exc:
            log.error("FAIL: %s — %s", name, exc)
            failed.append(name)

    print()
    if failed:
        print(f"FAILED checks: {', '.join(failed)}")
        sys.exit(1)
    else:
        print("All smoke tests passed.")
        sys.exit(0)


if __name__ == "__main__":
    main()
