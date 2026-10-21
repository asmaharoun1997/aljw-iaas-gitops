resource "google_compute_instance" "node" {
  for_each     = var.nodes
  name         = each.key
  machine_type = each.value.machine_type
  zone         = var.zone
  tags         = ["aljw-k8s"]

  # Les VM sont jetables : elles ne portent aucune donnée.
  deletion_protection = false

  labels = {
    role = each.value.role
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 50
      type  = "pd-standard" # le quota SSD de la région est presque plein
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.iaas.id
    # pas de access_config : aucune IP publique
  }

  # Compte dédié, sans clé JSON : le jeton est fourni par le serveur de métadonnées.
  service_account {
    email  = google_service_account.nodes.email
    scopes = ["cloud-platform"] # les droits réels sont limités par IAM (iam.tf)
  }

  metadata = {
    enable-oslogin = "TRUE"
  }
}
