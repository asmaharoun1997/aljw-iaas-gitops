output "node_private_ips" {
  value = { for k, v in google_compute_instance.node : k => v.network_interface[0].network_ip }
}

output "mysql_private_ips" {
  value = { for k, v in google_sql_database_instance.mysql : k => v.private_ip_address }
}

# Les mots de passe ne sont jamais affichés. Lecture ponctuelle :
#   terraform output -raw db_password_staging | Set-Clipboard
output "db_password_staging" {
  value     = random_password.db["staging"].result
  sensitive = true
}

output "db_password_preprod" {
  value     = random_password.db["preprod"].result
  sensitive = true
}

output "nodes_service_account" {
  value = google_service_account.nodes.email
}
