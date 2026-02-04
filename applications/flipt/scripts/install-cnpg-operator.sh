#!/bin/bash
set -e

echo "Installing CloudNativePG operator..."

# Add CNPG Helm repository
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update

# Install the operator in its own namespace
helm upgrade --install cnpg \
  --namespace cnpg-system \
  --create-namespace \
  cnpg/cloudnative-pg

echo "Waiting for operator to be ready..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/cnpg-cloudnative-pg \
  -n cnpg-system

echo "✓ CloudNativePG operator installed successfully!"
echo ""
echo "You can now install Flipt:"
echo "  make install"
