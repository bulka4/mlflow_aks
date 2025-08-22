# Resource Group
module resource_group {
    source = "./modules/resource_group"
    name     = var.resource_group_name
    location = var.location
}


# Log Analytics workspace for AKS monitoring
resource "azurerm_log_analytics_workspace" "law" {
  name                = "aks-law"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Below commented lines are to delete later on.
/*
# Generate ssh keys for connecting from our local computer to AKS worker nodes.
module "ssh"{
  source = "./modules/ssh"
  resource_group_id = module.resource_group.id
  resource_group_location = module.resource_group.location
  ssh_path = var.ssh_path
}
*/

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_name
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  dns_prefix          = "${var.aks_name}-dns"

  default_node_pool {
    name       = "system"
    node_count = var.node_count
    vm_size    = var.node_vm_size
    # vm_size, os_type, and other options can be customized
    type       = "VirtualMachineScaleSets"
    os_disk_size_gb = 30
    enable_auto_scaling = false
    # For production, consider using node labels, taints, and autoscaling
  }

  # An AD identity which can be used by AKS to access other Azure resources.
  identity {
    type = "SystemAssigned"
  }

  # Set up a OMS Agent which sents container monitoring data to the Log Analytics Workspace.
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  }

  # Enable RBAC authorization in a cluster. We will be able to create Roles and Roles Bindings in a cluster.
  role_based_access_control_enabled = true

# Below commented lines to delete later on.
/*
  # Add the public SSH key to the authorized keys. That will enable connecting to the cluster's worker nodes.
  linux_profile {
    admin_username = var.vm_username
    ssh_key {
      key_data = module.ssh.public_key
    }
  }
*/

  network_profile {
    network_plugin = "azure"          # azure CNI; use "kubenet" if desired
    load_balancer_sku = "standard"
    outbound_type = "loadBalancer"
  }

  kubernetes_version = var.kubernetes_version

  tags = {
    environment = "dev"
    created_by  = "terraform"
  }
}


# Create an ACR where we will be storing a Docker image used for deploying the MLflow Tracking Server.
module "acr" {
  source = "./modules/acr"
  acr_name                = var.acr_name
  resource_group_name     = var.resource_group_name
  resource_group_location = var.location
}


# Service Principal for authentication. It is going to have assigned the following roles and scopes:
# - Role 'acrpush' with scope for ACR - Enable pulling images from ACR when deploying resources on Kubernetes
# - Role 'Contributor' with score for ACR - Enable pushing images to ACR using Azure CLI
# - Role 'Azure Kubernetes Service Cluster User Role' with scope for AKS - Enable getting credentials to AKS (creating .kube/config file)
#   using the 'az aks get-credentials' command.

module "service_principal" {
  source = "./modules/service_principal"
  service_principal_display_name = "mlflow_acr"
  role_assignments = [
    {role = "acrpush", scope = module.acr.id}
    ,{role = "Contributor", scope = module.acr.id}
    ,{role = "Azure Kubernetes Service Cluster User Role", scope = azurerm_kubernetes_cluster.aks.id}
  ]
}


# Storage Account for saving MLflow artifacts.
module "artifact_store" {
  source = "./modules/storage_account"
  resource_group_name = module.resource_group.name
  resource_group_location = module.resource_group.location
  storage_account_name = var.storage_account_name
}


# Container for MLflow artifacts
module "artifact_store_container" {
  source = "./modules/sa_container"
  name = "mlflow-artifacts"
  storage_account_name = module.artifact_store.name
}


# Create a Dockerfile which will be saved on the localhost and which can be used to create an image for interacting with AKS
locals {
  dockerfile = templatefile("template.Dockerfile", {
    username                          = var.vm_username
    acr_url                           = module.acr.url
    acr_sp_id                         = module.service_principal.client_id
    acr_sp_password                   = module.service_principal.client_password
    acr_name                          = module.acr.name
    mlflow_container                  = module.artifact_store_container.name
    mlflow_storage_account_name       = module.artifact_store.name
    mlflow_storage_account_access_key = module.artifact_store.primary_access_key
    tenant_id                         = data.azurerm_client_config.current.tenant_id
    subscription_id                   = data.azurerm_client_config.current.subscription_id
    rg_name                           = module.resource_group.name
    aks_name                          = azurerm_kubernetes_cluster.aks.name
  })
}


# Save the Dockerfile on the localhost
resource "local_file" "dockerfile" {
  content = local.dockerfile
  filename = "docker/Dockerfile"
}


# Get info about the current client to get subscription ID
data "azurerm_client_config" "current" {}