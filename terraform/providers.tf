terraform {
  required_version = ">=1.2.9"

  required_providers {
    postgresql = {
      source = "cyrilgdn/postgresql"
      version = "1.20.0"
    }
  }
}
provider "postgresql" {
  host     = var.host
  port     = var.port
  database = var.database
  username = var.postgres_username
  password = var.postgres_username_password
  connect_timeout = 120
  superuser       = true
  sslmode         = var.ssl_mode
}

