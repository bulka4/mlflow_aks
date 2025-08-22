resource "random_pet" "ssh_key_name" {
  prefix    = "ssh"
  separator = ""
}

resource "azapi_resource_action" "ssh_public_key_gen" {
  type        = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  resource_id = azapi_resource.ssh_public_key.id
  action      = "generateKeyPair"
  method      = "POST"

  response_export_values = ["publicKey", "privateKey"]
}

# Save the SSH private key in the local file at path specified by the filename argument. It can be used to connect to the created VM via SSH
# It will be created only if the ssh_path variable is provided.
resource "local_file" "private_key" {
  count    = var.ssh_path == "none" ? 0 : 1 # if the ssh_path argument is not provided then don't save the ssh key on the local computer.
  content  = azapi_resource_action.ssh_public_key_gen.output.privateKey
  filename = var.ssh_path
  file_permission = "0600"
}

resource "azapi_resource" "ssh_public_key" {
  type      = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  name      = random_pet.ssh_key_name.id
  location  = var.resource_group_location
  parent_id = var.resource_group_id
}