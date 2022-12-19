# It is here in plain text for studying purpose 
#Should not be like this,I know.

variable "db_password" {
  type      = string
  default   = "password123"
  sensitive = true
}

variable "db_username" {
  type    = string
  default = "admin"
}

variable "db_name" {
  type    = string
  default = "database_terraform"
}

