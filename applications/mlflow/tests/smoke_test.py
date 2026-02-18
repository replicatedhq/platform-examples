#!/usr/bin/env python3
"""
Lightweight MLflow CI smoke test.

Validates that the MLflow server is running and its REST API is functional
using only the requests library (no heavy ML dependencies required).
"""

import sys
import argparse
import time
import socket
import json
import logging
from urllib.parse import urlparse

import requests

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def wait_for_server(base_url, timeout=120, interval=5):
    """Wait for the MLflow server to accept connections."""
    parsed = urlparse(base_url)
    host = parsed.hostname
    port = parsed.port or (443 if parsed.scheme == 'https' else 80)

    start = time.time()
    while time.time() - start < timeout:
        try:
            socket.create_connection((host, port), timeout=5)
        except (socket.timeout, socket.error, ConnectionRefusedError) as e:
            logger.info(f"Waiting for {host}:{port} ({e})...")
            time.sleep(interval)
            continue

        try:
            r = requests.get(f"{base_url}/health", timeout=5, verify=False)
            if r.status_code == 200:
                logger.info(f"Server is up (health check OK)")
                return True
        except requests.exceptions.RequestException:
            pass

        time.sleep(interval)

    logger.error(f"Server at {base_url} not reachable after {timeout}s")
    return False


def test_experiments_api(base_url):
    """Create and retrieve an experiment via the REST API."""
    api = f"{base_url}/api/2.0/mlflow"

    # Create experiment
    name = f"ci-smoke-{int(time.time())}"
    r = requests.post(f"{api}/experiments/create",
                      json={"name": name}, timeout=10, verify=False)
    if r.status_code != 200:
        logger.error(f"Failed to create experiment: {r.status_code} {r.text}")
        return False
    experiment_id = r.json().get("experiment_id")
    logger.info(f"Created experiment '{name}' (id={experiment_id})")

    # Get experiment
    r = requests.get(f"{api}/experiments/get",
                     params={"experiment_id": experiment_id}, timeout=10, verify=False)
    if r.status_code != 200:
        logger.error(f"Failed to get experiment: {r.status_code} {r.text}")
        return False
    logger.info("Retrieved experiment successfully")

    # Search experiments
    r = requests.get(f"{api}/experiments/search",
                     params={"max_results": 10}, timeout=10, verify=False)
    if r.status_code != 200:
        logger.error(f"Failed to search experiments: {r.status_code} {r.text}")
        return False
    logger.info("Searched experiments successfully")
    return True


def test_runs_api(base_url):
    """Create a run, log params/metrics, and verify via the REST API."""
    api = f"{base_url}/api/2.0/mlflow"

    # Use the Default experiment
    r = requests.post(f"{api}/runs/create",
                      json={"experiment_id": "0", "run_name": "ci-smoke"},
                      timeout=10, verify=False)
    if r.status_code != 200:
        logger.error(f"Failed to create run: {r.status_code} {r.text}")
        return False
    run_id = r.json()["run"]["info"]["run_id"]
    logger.info(f"Created run {run_id}")

    # Log a parameter
    r = requests.post(f"{api}/runs/log-parameter",
                      json={"run_id": run_id, "key": "test_param", "value": "42"},
                      timeout=10, verify=False)
    if r.status_code != 200:
        logger.error(f"Failed to log parameter: {r.status_code} {r.text}")
        return False
    logger.info("Logged parameter")

    # Log a metric
    r = requests.post(f"{api}/runs/log-metric",
                      json={"run_id": run_id, "key": "accuracy", "value": 0.95,
                            "timestamp": int(time.time() * 1000), "step": 0},
                      timeout=10, verify=False)
    if r.status_code != 200:
        logger.error(f"Failed to log metric: {r.status_code} {r.text}")
        return False
    logger.info("Logged metric")

    # Get the run and verify
    r = requests.get(f"{api}/runs/get",
                     params={"run_id": run_id}, timeout=10, verify=False)
    if r.status_code != 200:
        logger.error(f"Failed to get run: {r.status_code} {r.text}")
        return False

    run_data = r.json()["run"]["data"]
    params = {p["key"]: p["value"] for p in run_data.get("params", [])}
    metrics = {m["key"]: m["value"] for m in run_data.get("metrics", [])}

    if params.get("test_param") != "42":
        logger.error(f"Parameter mismatch: expected '42', got '{params.get('test_param')}'")
        return False
    if metrics.get("accuracy") != 0.95:
        logger.error(f"Metric mismatch: expected 0.95, got {metrics.get('accuracy')}")
        return False

    logger.info("Verified run data (params + metrics)")
    return True


def main():
    parser = argparse.ArgumentParser(description="Lightweight MLflow CI smoke test")
    parser.add_argument("hostname", help="host:port of the MLflow server")
    parser.add_argument("--protocol", default="http", help="http or https (default: http)")
    parser.add_argument("--connection-timeout", type=int, default=120,
                        help="Max seconds to wait for server (default: 120)")
    parser.add_argument("--debug", action="store_true")
    args = parser.parse_args()

    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)

    base_url = f"{args.protocol}://{args.hostname}"
    logger.info(f"Running smoke test against {base_url}")

    if not wait_for_server(base_url, timeout=args.connection_timeout):
        logger.error("Server not reachable, aborting")
        sys.exit(1)

    ok = True
    for test_fn in [test_experiments_api, test_runs_api]:
        name = test_fn.__name__
        logger.info(f"--- {name} ---")
        if test_fn(base_url):
            logger.info(f"PASS: {name}")
        else:
            logger.error(f"FAIL: {name}")
            ok = False

    if ok:
        logger.info("All smoke tests passed")
        sys.exit(0)
    else:
        logger.error("Some smoke tests failed")
        sys.exit(1)


if __name__ == "__main__":
    main()
