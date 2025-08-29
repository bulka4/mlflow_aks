variable "location" {
  type    = string
  default = "westeurope"
}

variable "resource_group_name" {
  type    = string
  default = "data_engineering_apps"
}

variable "aks_name" {
  type    = string
  default = "AKS"
  description = "Name of the created AKS cluster."
}

variable "node_count" {
  type    = number
  default = 1
}

variable "node_vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "vm_username" {
  type    = string
  default = "azureadmin"
  description = "A name of the user used for connecting through SSH to worker nodes. It will be also a name of a user created by the generated Dockerfile."
}

variable "ssh_path" {
  type        = string
  description = <<EOT
    Path where to save the private ssh key on our local computer for connecting to the VMs. 
    The recommended one for Windows is C:\\Users\\username\\.ssh\\id_rsa.
  EOT
}

variable "kubernetes_version" {
  type    = string
  default = null
  description = "Optional: specify AKS Kubernetes version (leave null for latest supported by provider)."
}

variable "acr_name" {
  type    = string
  default = "MLflowBulka"
  description = "Name of the created ACR."
}

variable "storage_account_artifacts_name" {
  type    = string
  default = "mlflowartifactsbulka"
  description = "Name of the created Storage Account which will act as an artifact store."
}


variable "storage_account_projects_name" {
  type    = string
  default = "mlflowartifactsbulka"
  description = "Name of the created Storage Account where we will be saving MLflow projects."
}