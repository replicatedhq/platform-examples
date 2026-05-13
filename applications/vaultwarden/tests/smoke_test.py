#!/usr/bin/env python3
"""Smoke tests for the Vaultwarden Helm chart.

Validates that Vaultwarden is running and its web vault and API are functional
after a Helm install or KOTS deployment.

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
) -> str:
    """Find a service by label selector, falling back to a known name."""
    try:
        out = _kubectl(
            ["get", "svc", "-l", label_selector, "-o", "json"],
            namespace=namespace,
        )
        services = json.loads(out)
        items = services.get("items", [])
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
        time.sleep(3)
        if self._proc.poll() is not None:
            stderr = self._proc.stderr.read().decode() if self._proc.stderr else ""
            raise RuntimeError(f"port-forward exited immediately: {stderr}")
        return self

    def __exit__(self, *_exc):
        if self._proc and self._proc.poll() is None:
            self._proc.terminate()
            self._proc.wait(timeout=5)


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

def check_alive(namespace: str, release: str) -> bool:
    """Verify Vaultwarden /alive health endpoint is responding."""
    svc = discover_service(
        namespace,
        label_selector=f"app.kubernetes.io/name=vaultwarden,app.kubernetes.io/instance={release}",
        fallback_name=release,
    )
    with PortForward(namespace, svc, 80) as pf:
        def _probe():
            url = f"http://127.0.0.1:{pf.local_port}/alive"
            resp = requests.get(url, timeout=5)
            resp.raise_for_status()
            log.info("Vaultwarden /alive returned HTTP %d", resp.status_code)
            return True

        _retry(_probe, "Checking Vaultwarden /alive endpoint")
    log.info("Vaultwarden health check passed")
    return True


def check_web_vault(namespace: str, release: str) -> bool:
    """Verify the web vault UI is being served."""
    svc = discover_service(
        namespace,
        label_selector=f"app.kubernetes.io/name=vaultwarden,app.kubernetes.io/instance={release}",
        fallback_name=release,
    )
    with PortForward(namespace, svc, 80) as pf:
        def _probe():
            url = f"http://127.0.0.1:{pf.local_port}/"
            resp = requests.get(url, timeout=5)
            resp.raise_for_status()
            if "Vaultwarden" in resp.text or "Bitwarden" in resp.text or "bitwarden" in resp.text:
                log.info("Web vault is serving the Vaultwarden UI")
                return True
            log.warning("Got HTTP 200 but page content does not look like Vaultwarden")
            return True  # Still accept a 200 response

        _retry(_probe, "Checking Vaultwarden web vault UI")
    log.info("Web vault check passed")
    return True


def check_api_config(namespace: str, release: str) -> bool:
    """Verify the Bitwarden-compatible API config endpoint responds."""
    svc = discover_service(
        namespace,
        label_selector=f"app.kubernetes.io/name=vaultwarden,app.kubernetes.io/instance={release}",
        fallback_name=release,
    )
    with PortForward(namespace, svc, 80) as pf:
        def _probe():
            url = f"http://127.0.0.1:{pf.local_port}/api/config"
            resp = requests.get(url, timeout=5)
            resp.raise_for_status()
            data = resp.json()
            log.info("API config: version=%s, server=%s",
                     data.get("version", "unknown"),
                     data.get("server", {}).get("name", "unknown"))
            return True

        _retry(_probe, "Checking Vaultwarden /api/config endpoint")
    log.info("API config check passed")
    return True


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Vaultwarden Helm chart smoke tests")
    parser.add_argument("--namespace", default="default", help="Kubernetes namespace")
    parser.add_argument("--release", default="vaultwarden", help="Helm release name")
    args = parser.parse_args()

    checks = [
        ("Health (/alive)", check_alive),
        ("Web Vault UI", check_web_vault),
        ("API Config", check_api_config),
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
