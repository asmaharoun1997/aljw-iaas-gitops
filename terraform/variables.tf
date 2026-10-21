variable "project_id" {
  type    = string
  default = "formation-equipe1"
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "zone" {
  type    = string
  default = "europe-west1-b"
}

variable "network_name" {
  description = "VPC existant (non géré par ce code)."
  type        = string
  default     = "aljw-vpc"
}

variable "subnet_cidr" {
  description = "Sous-réseau des 3 VM Kubernetes (libre : 10.0.0.0/20, 10.1.1.0/24 et 10.1.2.0/24 sont déjà pris)."
  type        = string
  default     = "10.2.0.0/24"
}

variable "pod_cidr" {
  description = "Réseau des pods du nouveau cluster (ne chevauche pas GKE 10.4.0.0/14)."
  type        = string
  default     = "10.244.0.0/16"
}

variable "sql_private_range" {
  description = "Plage réservée à Cloud SQL (accès privé)."
  type        = string
  default     = "10.3.0.0"
}

variable "nodes" {
  description = "Les 3 VM du cluster Kubernetes."
  type = map(object({
    machine_type = string
    role         = string
  }))
  default = {
    "aljw-k8s-cp" = { machine_type = "n2-standard-2", role = "control-plane" }
    "aljw-k8s-w1" = { machine_type = "n2-standard-4", role = "gitlab" }
    "aljw-k8s-w2" = { machine_type = "n2-standard-2", role = "apps" }
  }
}

variable "environments" {
  description = "Un Cloud SQL MySQL 8 par environnement."
  type        = set(string)
  default     = ["staging", "preprod"]
}

variable "sql_tier" {
  description = "Taille des instances Cloud SQL (la plus petite pour limiter le coût)."
  type        = string
  default     = "db-f1-micro"
}

variable "registry_repo" {
  description = "Dépôt Artifact Registry existant (non géré par ce code)."
  type        = string
  default     = "aljw-docker"
}
