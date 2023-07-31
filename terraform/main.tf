resource "random_id" "password-user-bob" {
  byte_length = 12
}

resource "random_id" "password-user-dave" {
  byte_length = 12
}

resource "postgresql_role" "bob" {
  name            = "${var.database}_bob"
  password        = random_id.password-user-bob.hex
  login           = true
  create_database = "false"
  depends_on      = [random_id.password-user-bob]
}

resource "postgresql_role" "dave" {
  name            = "${var.database}_dave"
  password        = random_id.password-user-dave.hex
  login           = true
  create_database = "false"
  depends_on      = [random_id.password-user-dave]

}

resource "postgresql_grant" "priv-table-for-bob" {
  database    = var.database
  role        = postgresql_role.bob.name
  schema      = var.schema
  object_type = "table"
  objects     = ["order_items", "orders", "customers", "products"]
  privileges  = ["SELECT"]
  depends_on  = [postgresql_role.bob]
}

resource "postgresql_grant" "priv-schema-for-bob" {
  database    = var.database
  role        = postgresql_role.bob.name
  schema      = var.schema
  object_type = "schema"
  privileges  = ["USAGE"]
  depends_on  = [postgresql_grant.priv-table-for-bob]
}

resource "postgresql_grant" "priv-table-for-dave" {
  database    = var.database
  role        = postgresql_role.dave.name
  schema      = var.schema
  object_type = "table"
  objects     = ["order_items", "orders", "customers", "products"]
  privileges  = ["SELECT", "UPDATE", "DELETE", "INSERT"]
  depends_on  = [postgresql_grant.priv-schema-for-bob]
}

resource "postgresql_grant" "priv-schema-for-dave" {
  database    = var.database
  role        = postgresql_role.dave.name
  schema      = var.schema
  object_type = "schema"
  privileges  = ["USAGE"]
  depends_on  = [postgresql_grant.priv-table-for-dave]
}
