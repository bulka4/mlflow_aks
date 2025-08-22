variable "resource_group_location" {
  type        = string
  description = "Location of the resource group where we will create acr."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group where we will create acr."
}

variable acr_name {
    type = string
    description = "Name of the container registry"
}