#!/usr/bin/env bash
# Sprint 13 : suppression complète de l'environnement dev depuis le dépôt (exercice de reprise après sinistre).
# La recréation se fait ensuite par la pipeline (workflow_dispatch), qui mesure le RTO.
# Usage : bash scripts/supprimer_env.sh dev
set -euo pipefail
ENV="${1:?environnement}"
[[ "$ENV" == dev ]] || { echo "REFUS : seul l'environnement dev peut être supprimé par ce script"; exit 2; }
CLUSTER="eks-portail-${ENV}-ADSN"
debut=$(date +%s)
horodatage() { echo "[$(date -u +%T) +$(( $(date +%s) - debut )) s] $*"; }

# 1. Ressources créées par le contrôleur ALB hors CloudFormation (ALB, groupes cibles) : ingress supprimé d'abord
if aws eks describe-cluster --name "$CLUSTER" > /dev/null 2>&1; then
  aws eks update-kubeconfig --name "$CLUSTER" > /dev/null
  horodatage "suppression de l'ingress (ALB créé par le contrôleur)"
  kubectl -n portail delete ingress --all --wait=true --timeout=300s || true
  for _ in $(seq 1 30); do
    aws elbv2 describe-load-balancers --names "alb-${ENV}-leman-ADSN" > /dev/null 2>&1 || break
    sleep 10
  done
  horodatage "ALB supprimé"
fi

# 2. Bucket des fichiers statiques versionné : CloudFormation ne supprime pas un bucket non vide
BUCKET=$(aws cloudformation describe-stacks --stack-name "portail-${ENV}-cloudfront" \
  --query "Stacks[0].Outputs[?OutputKey=='BucketStatique'].OutputValue" --output text 2>/dev/null || true)
if [[ -n "$BUCKET" && "$BUCKET" != None ]]; then
  horodatage "vidage du bucket $BUCKET (toutes les versions)"
  aws s3api list-object-versions --bucket "$BUCKET" --output json \
    | jq '{Objects: ([.Versions[]?, .DeleteMarkers[]?] | map({Key, VersionId})), Quiet: true}' > /tmp/versions.json
  if jq -e '.Objects | length > 0' /tmp/versions.json > /dev/null; then
    aws s3api delete-objects --bucket "$BUCKET" --delete file:///tmp/versions.json > /dev/null
  fi
fi

# 3. Piles en ordre inverse (celles qui importent une sortie partent avant celles qui l'exportent)
piles=""
for modele in $(ls templates/[01][0-9]-*.yaml | sort -r); do
  base=$(basename "$modele" .yaml)
  [[ "$base" == 00-* ]] && continue
  piles="$piles portail-${ENV}-${base#*-}"
done
for pile in $piles; do
  aws cloudformation describe-stacks --stack-name "$pile" > /dev/null 2>&1 || continue
  horodatage "suppression de $pile"
  aws cloudformation delete-stack --stack-name "$pile"
  aws cloudformation wait stack-delete-complete --stack-name "$pile"
done
horodatage "environnement $ENV supprimé (pile portail-bootstrap conservée : rôles OIDC)"
aws cloudformation describe-stacks --query "Stacks[?starts_with(StackName,'portail-${ENV}')].StackName" --output text \
  | sed 's/^$/aucune pile portail-'"$ENV"' restante/'
