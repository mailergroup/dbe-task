variable "database" {
  description = "Postgres database name"
  type        = string
  default     = "ecommerce_database"
}

variable "postgres_username" {
  description = "Postgres username to connect on main database"
  type        = string
  default     = "ecommerce_user"
}

variable "postgres_username_password" {
  description = "Postgres password to connect on main database"
  type        = string
  default     = "a_very_powerfull_password"
}

variable "host" {
  description = "Postgres host to connect"
  type        = string
  default     = "localhost"
}

variable "schema" {
  description = "Postgres scheme to connect"
  type        = string
  default     = "public"
}

variable "port" {
  description = "Postgres Connection Port"
  type        = number
  default     = 5432
}

variable "connect_timeout" {
  description = "Terrform Connection timeout"
  type        = number
  default     = 120
}

variable "ssl_mode" {
  description = "Terrform SSL Connection mode"
  type        = string
  default     = "disable"
}