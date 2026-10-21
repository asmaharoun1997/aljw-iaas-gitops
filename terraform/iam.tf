# Compte de service dédié aux 3 VM : il ne peut que LIRE le dépôt d'images aljw-docker.
resource "google_service_account" "nodes" {
  account_id   = "aljw-k8s-nodes"
  display_name = "VM du cluster Kubernetes IaaS (lecture du registre aljw-docker)"
}

resource "google_artifact_registry_repository_iam_member" "nodes_reader" {
  project    = var.project_id
  location   = var.region
  repository = var.registry_repo
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.nodes.email}"
}
