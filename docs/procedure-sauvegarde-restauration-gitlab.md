# Procédure de sauvegarde et de restauration de GitLab

**Statut : sauvegarde réalisée et vérifiée (22/10/2026) ; restauration non encore testée.**
À mettre à jour après le premier test de restauration sur le nouveau cluster.

Aucun secret n'est écrit dans ce document. Les fichiers sensibles restent dans le bucket privé.

## 1. Contexte

| Élément | Valeur |
|---|---|
| Version de GitLab | 19.5.0 (édition CE, installation Omnibus, image à tag fixe) |
| Emplacement actuel | Cluster GKE `aljw-cluster`, namespace `cicd`, déploiement `gitlab` |
| Disque de données | 30 Go (805 Mo utilisés au moment de la sauvegarde) |
| Bucket de sauvegarde | `gs://aljw-gitlab-backups-formation-equipe1` (privé, versionné) |

## 2. Ce que contient la sauvegarde

| Fichier | Contenu | Remarque |
|---|---|---|
| `<horodatage>_gitlab_backup.tar` | Dépôts, base de données, uploads, CI (artefacts, traces) | Créé par `gitlab-backup create` |
| `gitlab-secrets.json` | Clés de chiffrement | **Absent de l'archive.** Sans lui, les variables CI/CD, les jetons et l'authentification à deux facteurs restaurés sont illisibles |
| `gitlab.rb` | Configuration | **Absent de l'archive.** À traiter comme un secret |

**Hors sauvegarde** : les images Docker (dans Artifact Registry, reconstruites par le pipeline), la configuration du Runner (valeurs Helm, jeton à renouveler), Traefik et cert-manager (valeurs Helm).

## 3. Sauvegarder

Prérequis : `kubectl` pointe sur GKE (`kubectl config current-context`), `gcloud` est connecté avec un compte autorisé sur le bucket, et l'espace disque de GitLab est suffisant (`kubectl exec -n cicd deploy/gitlab -- df -h /var/opt/gitlab` : viser moins de 40 % utilisé).

```powershell
powershell -ExecutionPolicy Bypass -File .\backup-gitlab.ps1 -Bucket aljw-gitlab-backups-formation-equipe1
```

Le script : crée la sauvegarde (`gitlab-backup create STRATEGY=copy`), copie l'archive, `gitlab-secrets.json` et `gitlab.rb` sur le poste, contrôle que l'archive est lisible, envoie les trois fichiers dans un sous-dossier horodaté du bucket, puis supprime les copies locales.

Contrôles : le bucket liste trois objets avec des tailles plausibles ; la version est notée ; aucune copie ne reste sur le poste.

**Sauvegarde du 22/10/2026** : dossier `20261022-1028`, archive `1792657730_2026_10_22_19.5.0_gitlab_backup.tar` (environ 200 Mio), `gitlab-secrets.json` (environ 16 Ko), `gitlab.rb` (environ 173 Ko).

## 4. Restaurer (sur le nouveau cluster)

Ne jamais tester la restauration sur le GitLab de GKE, qui est en service.

**Prérequis** : GitLab CE **19.5.0** (même version exactement) installé et démarré dans le nouveau cluster, avec un volume persistant pour `/var/opt/gitlab` **et** pour `/etc/gitlab` (sinon `gitlab-secrets.json` serait perdu au redémarrage du pod).

1. **Récupérer les fichiers** depuis le bucket, dans un dossier temporaire du poste (jamais dans le dépôt Git) :
   ```powershell
   gcloud storage cp "gs://aljw-gitlab-backups-formation-equipe1/20261022-1028/*" .
   ```
2. **Copier dans le pod** (chemins relatifs : `kubectl cp` confond `C:` avec un nom de pod) :
   ```powershell
   $pod = "<nom-du-pod-gitlab>"; $ns = "<namespace>"
   kubectl cp "./1792657730_2026_10_22_19.5.0_gitlab_backup.tar" "${ns}/${pod}:/var/opt/gitlab/backups/"
   kubectl cp "./gitlab-secrets.json" "${ns}/${pod}:/etc/gitlab/gitlab-secrets.json"
   ```
3. **Configuration** : comparer `gitlab.rb` de la sauvegarde avec celui du nouveau GitLab, sans l'écraser aveuglément. Reprendre ce qui doit l'être, mais garder l'adresse (`external_url`) et les réglages de proxy du **nouveau** cluster.
4. **Droits et reconfiguration** (dans le pod) :
   ```bash
   chown git:git /var/opt/gitlab/backups/1792657730_2026_10_22_19.5.0_gitlab_backup.tar
   gitlab-ctl reconfigure
   ```
5. **Arrêter les services qui écrivent dans la base** :
   ```bash
   gitlab-ctl stop puma
   gitlab-ctl stop sidekiq
   gitlab-ctl status
   ```
6. **Restaurer** (l'identifiant est le nom de l'archive sans `_gitlab_backup.tar`) :
   ```bash
   gitlab-backup restore BACKUP=1792657730_2026_10_22_19.5.0
   ```
   La restauration **remplace** les données existantes ; répondre `yes` aux deux confirmations.
7. **Redémarrer et vérifier** :
   ```bash
   gitlab-ctl restart
   gitlab-rake gitlab:check SANITIZE=true
   gitlab-rake gitlab:doctor:secrets
   ```
8. **Contrôles fonctionnels** : connexion avec un compte existant, présence des projets (dont `lms-platform`), variables CI/CD lisibles, branches protégées et rôles des membres conformes.
9. **Après la restauration** : enregistrer un nouveau Runner (nouveau jeton), lancer une pipeline de test, supprimer les copies locales des fichiers sensibles.

## 5. Points d'attention

- Le fichier `gitlab-secrets.json` doit être restauré **avant** de lancer la restauration, sinon les données chiffrées sont inutilisables.
- Le bucket est versionné : supprimer un fichier ne l'efface pas. En fin de TP, supprimer **toutes les versions** (le bucket contient les clés de chiffrement), après accord d'Asma.
- L'archive reste aussi dans le pod GitLab de GKE (`/var/opt/gitlab/backups`) : ne la supprimer qu'avec l'accord d'Asma.
- Ne jamais mettre ces fichiers dans Git ni dans une conversation.
