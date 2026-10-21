resource "google_project_service" "servicenetworking" {
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

# Plage d'adresses réservée à Cloud SQL, puis peering privé avec notre VPC.
resource "google_compute_global_address" "sql_range" {
  name          = "aljw-sql-private-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = var.sql_private_range
  prefix_length = 24
  network       = data.google_compute_network.vpc.id
}

resource "google_service_networking_connection" "sql" {
  network                 = data.google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.sql_range.name]
  depends_on              = [google_project_service.servicenetworking]
}

resource "random_password" "db" {
  for_each = var.environments
  length   = 24
  special  = false
}

resource "google_sql_database_instance" "mysql" {
  for_each            = var.environments
  name                = "aljw-mysql-${each.key}"
  region              = var.region
  database_version    = "MYSQL_8_0"
  deletion_protection = true # refuse la suppression par erreur

  settings {
    tier              = var.sql_tier
    edition           = "ENTERPRISE"
    availability_type = "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = 10

    backup_configuration {
      enabled            = true
      binary_log_enabled = true # permet la restauration à un instant précis
      start_time         = "03:00"
    }

    ip_configuration {
      ipv4_enabled    = false # aucune IP publique
      private_network = data.google_compute_network.vpc.id
    }
  }

  depends_on = [google_service_networking_connection.sql]
}

resource "google_sql_database" "lms" {
  for_each = var.environments
  name     = "lms"
  instance = google_sql_database_instance.mysql[each.key].name
  charset  = "utf8mb4"
}

resource "google_sql_user" "lms" {
  for_each = var.environments
  name     = "lms"
  instance = google_sql_database_instance.mysql[each.key].name
  password = random_password.db[each.key].result
}
