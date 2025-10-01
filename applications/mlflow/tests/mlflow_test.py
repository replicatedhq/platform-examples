#!/usr/bin/env python3

import sys
import os
import argparse
import subprocess
import mlflow
from mlflow.models import infer_signature
import requests
import time
import socket
from urllib.parse import urlparse
import logging

import pandas as pd
from sklearn import datasets
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def check_server_connection(tracking_uri, timeout=30, retry_interval=5):
    """
    Check if the MLflow server is reachable
    
    Args:
        tracking_uri: The URI of the MLflow server
        timeout: Maximum time in seconds to wait for the server
        retry_interval: Interval in seconds between retries
        
    Returns:
        bool: True if the server is reachable, False otherwise
    """
    logger.info(f"Checking connection to MLflow server at {tracking_uri}")
    
    url = tracking_uri
    if not url.endswith('/'):
        url += '/'
    
    # Simple health check - just try to access the root URL
    health_url = url
    
    # Parse URL to get host and port for socket check
    parsed_url = urlparse(tracking_uri)
    host = parsed_url.hostname
    port = parsed_url.port or (443 if parsed_url.scheme == 'https' else 80)
    
    # Authentication disabled for MLflow 3.x compatibility
    auth = None
    
    start_time = time.time()
    while time.time() - start_time < timeout:
        # First try a basic socket connection
        try:
            socket.create_connection((host, port), timeout=5)
            logger.info(f"Socket connection to {host}:{port} successful")
        except (socket.timeout, socket.error, ConnectionRefusedError) as e:
            logger.warning(f"Socket connection failed: {e}")
            logger.info(f"Retrying in {retry_interval} seconds...")
            time.sleep(retry_interval)
            continue
            
        # Then try an HTTP request to the root URL
        try:
            # For our test environment, always disable SSL verification
            response = requests.get(health_url, timeout=5, verify=False, auth=auth if auth else None)
            status_code = response.status_code
            logger.info(f"Server returned status code: {status_code}")
            
            # 200 OK, 302 Found (redirect), or 401 Unauthorized (at least server is responding)
            if status_code in (200, 302, 401):
                logger.info(f"MLflow server is reachable at {tracking_uri}")
                return True
            else:
                logger.warning(f"MLflow server returned unexpected status code {status_code}")
        except requests.exceptions.RequestException as e:
            logger.warning(f"HTTP request failed: {e}")
        
        logger.info(f"Retrying in {retry_interval} seconds...")
        time.sleep(retry_interval)
    
    logger.error(f"Could not connect to MLflow server at {tracking_uri} after {timeout} seconds")
    return False

def run_mlflow_test(tracking_uri, connection_timeout=60):
    """
    Run MLflow test with the specified tracking URI
    
    Args:
        tracking_uri: The URI to use for the MLflow tracking server
        connection_timeout: Timeout in seconds for server connection
        
    Returns:
        True if the test passed, False otherwise
    """
    try:
        logger.info(f"Setting MLflow tracking URI to: {tracking_uri}")
        
        # Disable SSL warnings for self-signed certificates when using HTTPS
        if tracking_uri.startswith('https://'):
            import urllib3
            urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        
        # Check if the server is reachable before proceeding
        if not check_server_connection(tracking_uri, timeout=connection_timeout):
            logger.error("Failed to connect to MLflow server, aborting test")
            return False
        
        # Set MLflow tracking URI
        mlflow.set_tracking_uri(tracking_uri)
        
        # Load the Iris dataset
        logger.info("Loading dataset and training model...")
        X, y = datasets.load_iris(return_X_y=True)
        
        # Split the data into training and test sets
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )
        
        # Define the model hyperparameters
        params = {
            "solver": "lbfgs",
            "max_iter": 1000,
            "multi_class": "auto",  # Deprecated but keeping for now
            "random_state": 8888,
        }
        
        # Train the model
        lr = LogisticRegression(**params)
        lr.fit(X_train, y_train)
        
        # Predict on the test set
        y_pred = lr.predict(X_test)
        
        # Calculate metrics
        accuracy = accuracy_score(y_test, y_pred)
        
        logger.info(f"Current tracking URI: {mlflow.get_tracking_uri()}")
        logger.info(f"Model trained with accuracy: {accuracy:.4f}")
        
        # Create a new MLflow Experiment
        logger.info("Creating MLflow experiment...")
        experiment_name = "MLflow CI Test"
        try:
            experiment = mlflow.get_experiment_by_name(experiment_name)
            if experiment is None:
                experiment_id = mlflow.create_experiment(experiment_name)
                logger.info(f"Created new experiment with ID: {experiment_id}")
            else:
                logger.info(f"Using existing experiment with ID: {experiment.experiment_id}")
            mlflow.set_experiment(experiment_name)
        except Exception as e:
            logger.error(f"Failed to create or set experiment: {e}")
            return False
        
        # Start an MLflow run
        logger.info("Starting MLflow run...")
        try:
            with mlflow.start_run():
                # Log the hyperparameters
                mlflow.log_params(params)
                
                # Log the loss metric
                mlflow.log_metric("accuracy", accuracy)
                
                # Set a tag that we can use to remind ourselves what this run was for
                mlflow.set_tag("Training Info", "CI Test for MLflow")
                
                # Infer the model signature
                signature = infer_signature(X_train, lr.predict(X_train))
                
                # Log the model
                logger.info("Logging model to MLflow...")
                model_info = mlflow.sklearn.log_model(
                    sk_model=lr,
                    artifact_path="iris_model",
                    registered_model_name="ci-test-model",
                    signature=signature
                )
                
                logger.info(f"Model URI: {model_info.model_uri}")
                
            # Load the model back for predictions as a generic Python Function model
            try:
                logger.info("Loading model for predictions...")
                loaded_model = mlflow.pyfunc.load_model(model_info.model_uri)
                predictions = loaded_model.predict(X_test[:3])
                logger.info(f"Test predictions: {predictions}")
                return True
            except Exception as e:
                logger.error(f"Error loading model: {e}")
                return False
        except Exception as e:
            logger.error(f"Error during MLflow run: {e}")
            return False
            
    except Exception as e:
        logger.error(f"Test failed with error: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return False

def ensure_dependencies():
    """Ensure required packages are installed."""
    try:
        import mlflow
        import pandas
        import sklearn
        import requests
    except ImportError:
        logger.info("Installing required dependencies...")
        subprocess.check_call([
            sys.executable, "-m", "pip", "install", 
            "mlflow", "pandas", "scikit-learn", "requests"
        ])

def main():
    parser = argparse.ArgumentParser(description="MLflow CI testing tool")
    parser.add_argument("hostname", help="Hostname of the MLflow server")
    parser.add_argument("--port", type=int, help="Port number (if not included in hostname)")
    parser.add_argument("--protocol", default="https", help="Protocol (http or https, default: https)")
    parser.add_argument("--connection-timeout", type=int, default=60, 
                        help="Timeout in seconds for server connection (default: 60)")
    parser.add_argument("--debug", action="store_true", help="Enable debug logs")
    
    args = parser.parse_args()
    
    # Set logging level based on debug flag
    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Build the tracking URI
    tracking_uri = f"{args.protocol}://{args.hostname}"
    if args.port:
        tracking_uri += f":{args.port}"
    
    # Show protocol info
    if args.protocol == "http":
        logger.info("Using HTTP protocol (insecure)")
    
    # Note: Authentication disabled for MLflow 3.x
    logger.info("Authentication disabled (MLflow 3.x without basic auth)")
    
    # Ensure dependencies are installed
    ensure_dependencies()
    
    # Run the test
    logger.info(f"Starting MLflow test against server: {tracking_uri}")
    success = run_mlflow_test(tracking_uri, connection_timeout=args.connection_timeout)
    
    if success:
        logger.info("✅ MLflow test completed successfully")
        sys.exit(0)
    else:
        logger.error("❌ MLflow test failed")
        sys.exit(1)

if __name__ == "__main__":
    main() 