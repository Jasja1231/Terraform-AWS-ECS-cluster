
variable "db_username" {
  type    = string
  default = "admin"
}

variable "db_name" {
  type    = string
  default = "database_terraform"
}


resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}





