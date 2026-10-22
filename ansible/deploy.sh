#!/usr/bin/env bash
# Enchaîne les playbooks du cluster kubeadm, avec un contrôle entre chaque étape.
# Rejouable : chaque playbook est idempotent. Aucune commande destructive (pas de kubeadm reset).
# Usage : ./deploy.sh [-y] [--from N]     (N = 1..5 : reprendre à cette étape)
set -euo pipefail
cd "$(dirname "$0")"

YES=0; FROM=1
while [ $# -gt 0 ]; do
  case "$1" in
    -y) YES=1 ;;
    --from) FROM="${2:?numero_etape_manquant}"; shift ;;
    *) echo "Usage : $0 [-y] [--from N]" >&2; exit 2 ;;
  esac
  shift
done

[ -f inventory.ini ] || { echo "inventory.ini absent : cp inventory.ini.example inventory.ini" >&2; exit 1; }
command -v ansible-playbook >/dev/null || { echo "ansible-playbook introuvable" >&2; exit 1; }

LOG="$HOME/deploy-cluster-$(date +%Y%m%d-%H%M%S).log"
KC="--kubeconfig /etc/kubernetes/admin.conf"
step() { printf '\n=== Étape %s : %s ===\n' "$1" "$2"; }
kube() { ansible aljw-k8s-cp -b -m command -a "kubectl $KC $*" ; }

echo "Journal : $LOG"
if [ "$YES" -ne 1 ]; then
  read -rp "Lancer l'installation (kubeadm init/join, Calico) sur aljw-k8s-* ? [o/N] " r
  [ "$r" = "o" ] || { echo "Annulé."; exit 0; }
fi

{
  step 0 "Connexion aux 3 VM"
  ansible k8s -m ping -f 1

  if [ "$FROM" -le 1 ]; then
    step 1 "containerd + kubeadm sur les 3 nœuds"
    ansible-playbook playbooks/01-common.yml -f 1
  fi
  if [ "$FROM" -le 2 ]; then
    step 2 "credential provider sur les 3 nœuds"
    ansible-playbook playbooks/02-credential-provider.yml -f 1
  fi
  if [ "$FROM" -le 3 ]; then
    step 3 "kubeadm init sur le master"
    ansible-playbook playbooks/03-control-plane.yml
  fi
  if [ "$FROM" -le 4 ]; then
    step 4 "join des workers + étiquettes"
    ansible-playbook playbooks/04-workers.yml -f 1
  fi
  if [ "$FROM" -le 5 ]; then
    step 5 "Calico (VXLAN) + stockage local"
    ansible-playbook playbooks/05-cni-storage.yml
  fi

  step 6 "Contrôle final"
  kube get nodes -o wide --show-labels
  kube get pods -A
  echo
  echo "OK : vérifie 3 nœuds Ready (w1 pool=gitlab, w2 pool=main) et des pods Running."
  echo "Reste à prouver : un pod qui tire une image d'aljw-docker sans imagePullSecret."
} 2>&1 | tee "$LOG"
