variable "ssh_path" {
  type        = string
  description = "Path where to save the ssh key on our local computer for connecting to the VM. If not provided then it will not be saved on our computer."
  default = "none"
}

variable "resource_group_location" {
    type = string
    description = "Resource group location. It is created by the resource_group module."
}

variable "resource_group_id" {
    type = string
    description = "ID of the resource group. It is created by the resource_group module."
}