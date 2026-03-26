"""
Flipt Python SDK Example

This example demonstrates how to integrate Flipt feature flags
into a Python application.

Install: pip install flipt
"""

import os
from typing import Dict, Optional
from datetime import datetime, timedelta
import requests


class FliptClient:
    """Simple Flipt HTTP client for Python"""

    def __init__(self, url: str = None, auth_token: str = None):
        self.url = url or os.getenv("FLIPT_URL", "http://flipt.flipt.svc.cluster.local:8080")
        self.auth_token = auth_token
        self.session = requests.Session()

        if self.auth_token:
            self.session.headers.update({"Authorization": f"Bearer {self.auth_token}"})

    def evaluate_boolean(
        self,
        namespace_key: str,
        flag_key: str,
        entity_id: str,
        context: Optional[Dict[str, str]] = None,
    ) -> bool:
        """Evaluate a boolean feature flag"""
        url = f"{self.url}/api/v1/evaluate/v1/boolean"

        payload = {
            "namespaceKey": namespace_key,
            "flagKey": flag_key,
            "entityId": entity_id,
            "context": context or {},
        }

        try:
            response = self.session.post(url, json=payload)
            response.raise_for_status()
            data = response.json()
            return data.get("enabled", False)
        except requests.exceptions.RequestException as e:
            print(f"Error evaluating flag: {e}")
            return False  # Default to false on error

    def evaluate_variant(
        self,
        namespace_key: str,
        flag_key: str,
        entity_id: str,
        context: Optional[Dict[str, str]] = None,
    ) -> Optional[str]:
        """Evaluate a variant feature flag"""
        url = f"{self.url}/api/v1/evaluate/v1/variant"

        payload = {
            "namespaceKey": namespace_key,
            "flagKey": flag_key,
            "entityId": entity_id,
            "context": context or {},
        }

        try:
            response = self.session.post(url, json=payload)
            response.raise_for_status()
            data = response.json()
            return data.get("variantKey")
        except requests.exceptions.RequestException as e:
            print(f"Error evaluating variant: {e}")
            return None


# Example 1: Simple boolean flag evaluation
def check_boolean_flag(client: FliptClient, user_id: str = "user-123") -> bool:
    """Check a boolean feature flag"""
    result = client.evaluate_boolean(
        namespace_key="default",
        flag_key="new_dashboard",
        entity_id=user_id,
        context={
            "email": "user@example.com",
            "plan": "enterprise",
            "region": "us-east-1",
        },
    )

    if result:
        print("✓ New dashboard is enabled for this user")
    else:
        print("✗ New dashboard is disabled for this user")

    return result


# Example 2: Variant flag evaluation (A/B testing)
def check_variant_flag(client: FliptClient, user_id: str = "user-456") -> str:
    """Check a variant feature flag"""
    variant = client.evaluate_variant(
        namespace_key="default",
        flag_key="checkout_flow",
        entity_id=user_id,
        context={
            "userId": user_id,
            "email": "test@example.com",
            "accountAge": "30",
        },
    )

    print(f"User assigned to variant: {variant}")

    variants = {
        "control": "original_checkout",
        "variant_a": "streamlined_checkout",
        "variant_b": "express_checkout",
    }

    return variants.get(variant, "original_checkout")


# Example 3: Batch evaluation
def evaluate_multiple_flags(
    client: FliptClient, user_id: str, context: Dict[str, str]
) -> Dict[str, bool]:
    """Evaluate multiple feature flags at once"""
    flags = ["new_dashboard", "dark_mode", "beta_features"]
    results = {}

    for flag_key in flags:
        try:
            result = client.evaluate_boolean(
                namespace_key="default",
                flag_key=flag_key,
                entity_id=user_id,
                context=context,
            )
            results[flag_key] = result
        except Exception as e:
            print(f"Error evaluating flag {flag_key}: {e}")
            results[flag_key] = False

    print(f"Feature flags for user: {results}")
    return results


# Example 4: Flask middleware
try:
    from flask import Flask, request, g
    from functools import wraps

    def feature_flags_middleware(client: FliptClient):
        """Flask middleware to add feature flags to request context"""

        def decorator(f):
            @wraps(f)
            def decorated_function(*args, **kwargs):
                user_id = request.headers.get("X-User-ID", "anonymous")
                context = {
                    "email": request.headers.get("X-User-Email", ""),
                    "plan": request.headers.get("X-User-Plan", "free"),
                    "ip": request.remote_addr,
                    "userAgent": request.headers.get("User-Agent", ""),
                }

                try:
                    g.features = evaluate_multiple_flags(client, user_id, context)
                except Exception as e:
                    print(f"Error loading feature flags: {e}")
                    g.features = {}

                return f(*args, **kwargs)

            return decorated_function

        return decorator

    # Example Flask app
    def create_app(client: FliptClient) -> Flask:
        app = Flask(__name__)

        @app.route("/dashboard")
        @feature_flags_middleware(client)
        def dashboard():
            if g.features.get("new_dashboard", False):
                return "Showing new dashboard v2"
            else:
                return "Showing old dashboard v1"

        @app.route("/api/config")
        @feature_flags_middleware(client)
        def config():
            return {"features": g.features, "version": "1.0.0"}

        return app

except ImportError:
    print("Flask not installed, skipping Flask examples")
    create_app = None


# Example 5: Cached client with TTL
class CachedFliptClient:
    """Flipt client with local caching"""

    def __init__(self, client: FliptClient, ttl_seconds: int = 60):
        self.client = client
        self.cache = {}
        self.ttl = timedelta(seconds=ttl_seconds)

    def _get_cache_key(self, namespace_key: str, flag_key: str, entity_id: str) -> str:
        return f"{namespace_key}:{flag_key}:{entity_id}"

    def evaluate_boolean(
        self,
        namespace_key: str,
        flag_key: str,
        entity_id: str,
        context: Optional[Dict[str, str]] = None,
    ) -> bool:
        """Evaluate flag with caching"""
        cache_key = self._get_cache_key(namespace_key, flag_key, entity_id)
        cached = self.cache.get(cache_key)

        # Check if cache is valid
        if cached:
            value, timestamp = cached
            if datetime.now() - timestamp < self.ttl:
                return value

        # Fetch fresh value
        try:
            result = self.client.evaluate_boolean(
                namespace_key, flag_key, entity_id, context
            )

            # Update cache
            self.cache[cache_key] = (result, datetime.now())

            return result
        except Exception as e:
            # Return stale cache on error if available
            if cached:
                print(f"Using stale cache due to error: {e}")
                return cached[0]
            raise


# Example 6: Django middleware
try:
    from django.utils.deprecation import MiddlewareMixin

    class FeatureFlagMiddleware(MiddlewareMixin):
        """Django middleware to add feature flags to request"""

        def __init__(self, get_response):
            self.get_response = get_response
            self.client = FliptClient()

        def process_request(self, request):
            user_id = getattr(request.user, "id", "anonymous")
            context = {
                "email": getattr(request.user, "email", ""),
                "plan": getattr(request.user, "plan", "free"),
                "ip": request.META.get("REMOTE_ADDR", ""),
                "userAgent": request.META.get("HTTP_USER_AGENT", ""),
            }

            try:
                request.features = evaluate_multiple_flags(
                    self.client, str(user_id), context
                )
            except Exception as e:
                print(f"Error loading feature flags: {e}")
                request.features = {}

except ImportError:
    print("Django not installed, skipping Django examples")


# Example 7: FastAPI dependency
try:
    from fastapi import FastAPI, Depends, Request
    from fastapi.responses import JSONResponse

    def get_feature_flags(request: Request):
        """FastAPI dependency for feature flags"""
        client = FliptClient()
        user_id = request.headers.get("X-User-ID", "anonymous")
        context = {
            "email": request.headers.get("X-User-Email", ""),
            "plan": request.headers.get("X-User-Plan", "free"),
            "ip": request.client.host,
            "userAgent": request.headers.get("User-Agent", ""),
        }

        try:
            return evaluate_multiple_flags(client, user_id, context)
        except Exception as e:
            print(f"Error loading feature flags: {e}")
            return {}

    # Example FastAPI app
    def create_fastapi_app() -> FastAPI:
        app = FastAPI()

        @app.get("/dashboard")
        def dashboard(features: dict = Depends(get_feature_flags)):
            if features.get("new_dashboard", False):
                return {"message": "Showing new dashboard v2"}
            else:
                return {"message": "Showing old dashboard v1"}

        @app.get("/api/config")
        def config(features: dict = Depends(get_feature_flags)):
            return {"features": features, "version": "1.0.0"}

        return app

except ImportError:
    print("FastAPI not installed, skipping FastAPI examples")
    create_fastapi_app = None


def main():
    """Run all examples"""
    print("Flipt Python SDK Examples\n")

    # Create client
    client = FliptClient()

    # Example 1: Boolean flag
    print("Example 1: Boolean Flag")
    check_boolean_flag(client)
    print()

    # Example 2: Variant flag
    print("Example 2: Variant Flag")
    variant = check_variant_flag(client)
    print(f"Selected checkout: {variant}\n")

    # Example 3: Batch evaluation
    print("Example 3: Batch Evaluation")
    evaluate_multiple_flags(
        client, "user-789", {"email": "user789@example.com", "plan": "premium"}
    )
    print()

    # Example 4: Cached evaluation
    print("Example 4: Cached Evaluation")
    cached_client = CachedFliptClient(client, ttl_seconds=60)
    result1 = cached_client.evaluate_boolean("default", "new_dashboard", "user-123")
    print(f"First call (from API): {result1}")
    result2 = cached_client.evaluate_boolean("default", "new_dashboard", "user-123")
    print(f"Second call (from cache): {result2}")
    print()

    print("Examples completed!")


if __name__ == "__main__":
    main()
