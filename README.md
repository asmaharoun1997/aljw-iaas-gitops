# Refonte IaaS : Terraform

Crée : sous-réseau 10.2.0.0/24, 2 règles de pare-feu, 3 VM Kubernetes (sans IP publique),
accès privé Cloud SQL, 2 instances Cloud SQL MySQL 8 (staging, preprod).

Ne touche à aucune ressource existante (GKE, VPC, NAT, anciennes VM).

## Ordre
1. Créer une fois le bucket d'état (voir la conversation).
2. `terraform init`
3. `terraform plan -out plan.tfplan`  (lire le plan avant tout)
4. `terraform apply plan.tfplan`

Aucun secret dans ces fichiers : les mots de passe MySQL sont générés par Terraform
et ne sont jamais affichés.
