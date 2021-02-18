terraform {
  required_providers {
    azure = {
      source  = "azurerm"
      version = "=2.13.0"
    }
    helm = {
      source = "helm"
      version = "=2.0.2"
    }
  }
}


provider "azure" {
  features {}
}


resource "azurerm_resource_group" "rg" {
  name     = "aks-cluster"
  location = "westeurope"
}

resource "azurerm_kubernetes_cluster" "cluster" {
  name       = "aks"
  location   = azurerm_resource_group.rg.location
  dns_prefix = "aks"

  resource_group_name = azurerm_resource_group.rg.name
  kubernetes_version  = "1.19.6"

  default_node_pool {
    name       = "aks"
    node_count = "1"
    vm_size    = "Standard_D2s_v3"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Test"
  }
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.cluster.kube_config_raw
}


resource "local_file" "azurek8s" {
  content = azurerm_kubernetes_cluster.cluster.kube_config_raw
  filename = "${path.module}/azurek8s"
  file_permission = "0600"
}

provider "helm" {
  kubernetes {
    config_path = "./azurek8s"
  }
}

resource "helm_release" "ingress_nginx" {
  name       = "my-ingress-nginx"

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"

  namespace  = "ingress-nginx"
  create_namespace = "true"

  set {
    name  = "rbac.create"
    value = "true"
  }

  set {
    name  = "controller.extraArgs.enable-ssl-passthrough"
    value = ""
  }

  depends_on = [
    local_file.azurek8s
  ]
}
