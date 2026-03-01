"""
Quick test script for a running Flipt instance.

1. Creates a boolean flag via the Flipt API
2. Enables it
3. Evaluates it via the evaluation API
4. Cleans up

Usage:
    pip install requests
    python test-flipt.py
"""

import requests
import os
import sys

FLIPT_URL = os.getenv("FLIPT_URL", "http://localhost:8080")
NAMESPACE = "default"
FLAG_KEY = "test-flag"


def main():
    session = requests.Session()
    base = FLIPT_URL.rstrip("/")

    # 1. Health check
    print(f"Checking Flipt health at {base} ...")
    try:
        resp = session.get(f"{base}/health", timeout=10)
        resp.raise_for_status()
        print(f"  Health: {resp.json()}\n")
    except requests.exceptions.RequestException as e:
        print(f"  Cannot reach Flipt: {e}")
        sys.exit(1)

    # 2. Create a boolean flag
    print(f"Creating boolean flag '{FLAG_KEY}' ...")
    resp = session.post(
        f"{base}/api/v1/namespaces/{NAMESPACE}/flags",
        json={
            "key": FLAG_KEY,
            "name": "Test Flag",
            "type": "BOOLEAN_FLAG_TYPE",
            "description": "Temporary flag created by test script",
            "enabled": True,
        },
    )
    if resp.status_code == 200:
        print(f"  Created: {resp.json()['key']}\n")
    elif resp.status_code == 409:
        print(f"  Flag already exists, continuing.\n")
    else:
        print(f"  Unexpected response: {resp.status_code} {resp.text}")
        sys.exit(1)

    # 3. Enable the flag (update it)
    print(f"Enabling flag '{FLAG_KEY}' ...")
    resp = session.put(
        f"{base}/api/v1/namespaces/{NAMESPACE}/flags/{FLAG_KEY}",
        json={
            "key": FLAG_KEY,
            "name": "Test Flag",
            "type": "BOOLEAN_FLAG_TYPE",
            "enabled": True,
        },
    )
    if resp.status_code == 200:
        print(f"  Enabled: {resp.json().get('enabled')}\n")
    else:
        print(f"  Update response: {resp.status_code} {resp.text}\n")

    # 4. Create a boolean rollout (100% true)
    print(f"Creating rollout rule (100% true) ...")
    resp = session.post(
        f"{base}/api/v1/namespaces/{NAMESPACE}/flags/{FLAG_KEY}/rollouts",
        json={
            "rank": 1,
            "type": "THRESHOLD_ROLLOUT_TYPE",
            "threshold": {
                "percentage": 100.0,
                "value": True,
            },
        },
    )
    if resp.status_code == 200:
        print(f"  Rollout created.\n")
    elif resp.status_code == 409:
        print(f"  Rollout already exists, continuing.\n")
    else:
        print(f"  Rollout response: {resp.status_code} {resp.text}\n")

    # 5. Evaluate the flag
    print(f"Evaluating flag '{FLAG_KEY}' ...")
    resp = session.post(
        f"{base}/evaluate/v1/boolean",
        json={
            "namespaceKey": NAMESPACE,
            "flagKey": FLAG_KEY,
            "entityId": "test-user-1",
            "context": {"plan": "enterprise"},
        },
    )
    if resp.status_code == 200:
        data = resp.json()
        print(f"  Enabled: {data.get('enabled')}")
        print(f"  Reason:  {data.get('reason')}\n")
    else:
        print(f"  Evaluation response: {resp.status_code} {resp.text}\n")

    # 6. Clean up - delete the flag
    print(f"Cleaning up - deleting flag '{FLAG_KEY}' ...")
    resp = session.delete(
        f"{base}/api/v1/namespaces/{NAMESPACE}/flags/{FLAG_KEY}",
    )
    if resp.status_code == 200:
        print("  Deleted.\n")
    else:
        print(f"  Delete response: {resp.status_code} {resp.text}\n")

    print("Done!")


if __name__ == "__main__":
    main()
