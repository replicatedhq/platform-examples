terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25.2"
    }
  }
  required_version = ">= 1.0.0"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Create n8n namespace
resource "kubernetes_namespace" "n8n" {
  metadata {
    name = "n8n"
  }
}

# Install CloudNativePG Operator
resource "helm_release" "cloudnativepg" {
  name       = "cloudnativepg"
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cloudnative-pg"
  version    = "0.23.2"
  namespace  = kubernetes_namespace.n8n.metadata[0].name

  # Wait for the CloudNativePG operator to be ready
  wait = true
}

# Install Traefik Ingress Controller
resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "35.0.0"
  namespace  = "traefik-system"
  create_namespace = true

  # Set values for Traefik (customize as needed)
  set {
    name  = "ingressClass.enabled"
    value = "true"
  }
  
  set {
    name  = "ingressClass.isDefaultClass"
    value = "true"
  }
}

# Install n8n chart (local chart)
resource "helm_release" "n8n" {
  name       = "n8n"
  chart      = "${path.module}/charts/n8n"
  namespace  = kubernetes_namespace.n8n.metadata[0].name
  dependency_update = true
  
  # Load values from the n8n-values.yaml file
  values = [
    file("${path.module}/charts/n8n-values.yaml")
  ]

  # Set the encryption key using the random_password resource
  set_sensitive {
    name  = "main.secret.n8n.encryption_key"
    value = random_password.encryption_key.result
  }

  # Dependencies - wait for both remote charts to be installed first
  depends_on = [
    helm_release.cloudnativepg,
    helm_release.traefik
  ]
}

# Generate random passwords for n8n
resource "random_password" "encryption_key" {
  length  = 32
  special = false
}

# resource "random_password" "db_password" {
#   length  = 16
#   special = false
# }

# # Create a secret for PostgreSQL credentials
# resource "kubernetes_secret" "postgres_credentials" {
#   metadata {
#     name      = "n8n-db-credentials"
#     namespace = kubernetes_namespace.n8n.metadata[0].name
#   }

#   data = {
#     username = "n8n"
#     password = random_password.db_password.result
#   }
# } 