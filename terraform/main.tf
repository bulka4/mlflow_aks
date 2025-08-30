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


# Create an ACR where we will be storing a Docker image used for deploying the MLflow Tracking Server and running MLflow project.
module "acr" {
  source = "./modules/acr"
  acr_name                = var.acr_name
  resource_group_name     = var.resource_group_name
  resource_group_location = var.location
}


# Service Principal for authentication. It is going to have assigned the following roles and scopes:
# - Role 'acrpush' with scope for ACR - Enable pulling images from ACR when deploying resources on Kubernetes
# - Role 'Contributor' with scope for ACR - Enable pushing images to ACR using Azure CLI
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
  storage_account_name = var.storage_account_artifacts_name
}


# Container for MLflow artifacts
module "artifact_store_container" {
  source = "./modules/sa_container"
  name = "mlflow-artifacts"
  storage_account_name = module.artifact_store.name
}


# File share for MLflow projects
module "sa_projects_file_share" {
  source = "./modules/sa_file_share"
  name = "mlflow-projects"
  storage_account_name = module.artifact_store.name
}


# Create files content which will be saved on the localhost:
# - Dockerfile for creating an image for interacting with AKS
# - values.yaml file for the MLflow Helm chart
# - Files for the MLflow project:
#   - backend_config.yaml 
#   - MLproject
locals {
  namespace                     = "mlflow"                # Name of the Kubernetes namespace where we will deploy all the MLflow resources
  tracking_server_service_name  = "mlflow-service"        # Name of the Service which will be attached to the Pod running the MLflow Tracking Server
  service_account_name          = "mlflow-sa"             # Name of the Service Account which will be created and used when running MLflow projects
  mlproject_image_name          = "mlproject:latest"      # Name of the Docker image which will be used for the MLflow project
  tracking_server_image_name    = "mlflow-server:latest"  # Name of the Docker image which will be used for the MLflow Tracking Server
  acr_secret_name               = "acr-secret"            # Name of the Kubernetes secret which will be used for accessing ACR
  
  dockerfile = templatefile("template_files/docker/template.Dockerfile", {
    rg_name         = module.resource_group.name
    aks_name        = azurerm_kubernetes_cluster.aks.name

    acr_sp_id       = module.service_principal.client_id
    acr_sp_password = module.service_principal.client_password
    acr_name        = module.acr.name
    
    tenant_id       = data.azurerm_client_config.current.tenant_id
    subscription_id = data.azurerm_client_config.current.subscription_id
    
    mlproject_image_name          = local.mlproject_image_name
    tracking_server_image_name    = local.tracking_server_image_name
  })

  # values.yaml file for the mlflow_setup chart
  values_setup = templatefile("template_files/mlflow_helm_chart/values-setup-template.yaml", {
    namespace                     = local.namespace
    tracking_server_service_name  = local.tracking_server_service_name
    tracking_server_image_name    = local.tracking_server_image_name
    service_account_name          = local.service_account_name
    acr_secret_name               = local.acr_secret_name
    
    acr_url         = module.acr.url
    acr_sp_id       = module.service_principal.client_id
    acr_sp_password = module.service_principal.client_password

    mlflow_storage_account_name       = module.artifact_store.name
    mlflow_storage_account_access_key = module.artifact_store.primary_access_key
    mlflow_container                  = module.artifact_store_container.name
    sa_file_share_name                = module.sa_projects_file_share.name
  })

  # values.yaml file for the mlflow_project chart
  values_project = templatefile("template_files/mlflow_helm_chart/values-project-template.yaml", {
    namespace                     = local.namespace
    service_account_name          = local.service_account_name
    mlproject_image_name          = local.mlproject_image_name
    acr_url                       = module.acr.url
    tracking_server_service_name  = local.tracking_server_service_name
  })
}


# Save files on the localhost
resource "local_file" "dockerfile" {
  # each.key - content to save in a file
  # each.value - path where to save a file
  for_each = {
    0 = {content = local.dockerfile, path = "../docker/Dockerfile"}
    1 = {content = local.values_setup, path = "../docker/helm_charts/mlflow_setup/values.yaml"}
    2 = {content = local.values_project, path = "../docker/helm_charts/mlflow_project/values.yaml"}
  }

  content = each.value.content
  filename = each.value.path
}


# Get info about the current client to get subscription ID
data "azurerm_client_config" "current" {}