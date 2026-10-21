data "google_compute_network" "vpc" {
  name = var.network_name
}

resource "google_compute_subnetwork" "iaas" {
  name                     = "aljw-subnet-iaas"
  region                   = var.region
  network                  = data.google_compute_network.vpc.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true
}

# SSH uniquement par le tunnel IAP de Google (aucune IP publique sur les VM).
resource "google_compute_firewall" "iaas_iap" {
  name          = "aljw-iaas-allow-iap"
  network       = data.google_compute_network.vpc.name
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["aljw-k8s"]

  allow {
    protocol = "tcp"
    ports    = ["22", "6443"] # SSH et API Kubernetes (kubectl via tunnel)
  }
}

# Tout le trafic entre les nœuds et les pods du nouveau cluster.
resource "google_compute_firewall" "iaas_internal" {
  name          = "aljw-iaas-allow-internal"
  network       = data.google_compute_network.vpc.name
  direction     = "INGRESS"
  source_ranges = [var.subnet_cidr, var.pod_cidr]
  target_tags   = ["aljw-k8s"]

  allow {
    protocol = "all"
  }
}
