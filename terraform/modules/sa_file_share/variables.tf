variable "name" {
    type = string
    description = "Name of the created File share."
    default = "MyFileShare"
}

variable "storage_account_name" {
    type = string
    description = "Name of the Storage Account where to create the File share."
}