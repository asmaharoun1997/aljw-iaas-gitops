# Entree publique du nouveau cluster : un equilibreur reseau (passthrough, TCP 80 et 443)
# vers les 2 workers. Traefik termine le HTTPS lui-meme (cert-manager / Let's Encrypt).
# Les VM gardent AUCUNE IP publique : seule l'adresse de l'equilibreur est exposee.

resource "google_compute_address" "ingress" {
  name         = "aljw-ingress-iaas-ip"
  region       = var.region
  address_type = "EXTERNAL"
}

resource "google_compute_instance_group" "workers" {
  name = "aljw-k8s-workers"
  zone = var.zone
  instances = [
    for k, v in google_compute_instance.node : v.self_link
    if v.labels["role"] != "control-plane"
  ]
}

resource "google_compute_region_health_check" "ingress" {
  name                = "aljw-ingress-hc"
  region              = var.region
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  tcp_health_check {
    port = 80
  }
}

resource "google_compute_region_backend_service" "ingress" {
  name                  = "aljw-ingress-backend"
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_region_health_check.ingress.id]

  backend {
    group          = google_compute_instance_group.workers.id
    balancing_mode = "CONNECTION" # seul mode accepte par un equilibreur reseau passthrough
  }
}

resource "google_compute_forwarding_rule" "ingress" {
  name                  = "aljw-ingress-fr"
  region                = var.region
  load_balancing_scheme = "EXTERNAL"
  ip_protocol           = "TCP"
  ports                 = ["80", "443"]
  ip_address            = google_compute_address.ingress.address
  backend_service       = google_compute_region_backend_service.ingress.id
}

# Web depuis Internet + sondes de sante de Google, vers les noeuds du cluster.
resource "google_compute_firewall" "iaas_web" {
  name          = "aljw-iaas-allow-web"
  network       = data.google_compute_network.vpc.name
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0", "35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["aljw-k8s"]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

output "ingress_ip" {
  description = "Adresse publique du nouveau cluster (a donner au prof pour le DNS)."
  value       = google_compute_address.ingress.address
}
