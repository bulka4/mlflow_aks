variable "resource_group_name" {
    type = string
    description = "Name of the resource group"
}

variable "resource_group_location" {
    type = string
    description = "Name of a location the resource group"
}

variable "vm_size" {
    type = string
    description = <<EOT
        Size of the VM which we will create. I think we need to take name of the VM from the Azure pricing website, add
        the 'Standard_' prefix, and replace spaces with the underscore '_'. So for example if we want to use VM 'DS1 v2'
        then vm_size = 'Standard_DS1_v2'.
    EOT
    default = "Standard_B2ms"
}

variable "vm_name" {
    type = string
    description = "Name of the VM."
    default = "myVM"
}

variable "subnet_id" {
    type = string
    description = "Terraform ID of the subnet for our VM. It can be obtained from outputs from the networks module."
}

variable "nsg_id" {
    type = string
    description = "Terraform ID of the network security group for our VM. It can be obtained from outputs from the networks module."
}

variable "hostname" {
    type = string
    description = "hostname of the created VM."
    default = "hostname"
}

variable "username" {
    type = string
    description = "Username used to connect to the created VM using SSH."
    default = "azureadmin"
}

variable "public_key" {
    type = string
    description = "Public key used to connect to the created VM using SSH. It is created by the ssh module."
}

variable "storage_account_uri" {
    type = string
    description = "URI of the storage account for boot diagnostics. It is the primary_blob_endpoint output from the storage_account module."
}