variable service_principal_display_name {
    type = string
}

variable "role_assignments" {
    type = list(object({
        role = string
        scope = string
    }))
    description = <<EOF
        List of role assignments of the following format: 
            [
                {role = "role1", scope = "scope1"}
                ,{role = "role2", scope = "scope2"}
                ,...
            ]
    EOF
}

/*
variable scope {
    type = string
    description = "Scope of the service principal. That is ID of a resource which will be a scope."
}

variable role {
    type = string
    description = "Role which will be assigned to the service principal."
}
*/