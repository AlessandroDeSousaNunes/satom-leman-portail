#!/usr/bin/env bash
# Sprint 13 : suppression complète de l'environnement dev depuis le dépôt (exercice de reprise après sinistre).
# La recréation se fait ensuite par la pipeline (workflow_dispatch), qui mesure le RTO.
# Usage : bash scripts/supprimer_env.sh dev
set -euo pipefail
ENV="${1:?environnement}"
[ "$ENV" = dev ] || { echo "REFUS : seul l'environnement dev peut être supprimé par ce script"; exit 2; }
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
if [ -n "$BUCKET" ] && [ "$BUCKET" != None ]; then
  horodatage "vidage du bucket $BUCKET (toutes les versions)"
  python - "$BUCKET" <<'EOF'
import sys, boto3
boto3.resource("s3").Bucket(sys.argv[1]).object_versions.delete()
EOF
fi

# 3. Piles en ordre inverse (celles qui importent une sortie partent avant celles qui l'exportent)
piles=$(python - "$ENV" <<'EOF'
import sys
from pathlib import Path
sys.path.insert(0, "scripts")
from deployer import nom_pile
modeles = sorted(Path("templates").glob("[01][0-9]-*.yaml"), reverse=True)
print(" ".join(nom_pile(m, sys.argv[1]) for m in modeles if not m.stem.startswith("00-")))
EOF
)
for pile in $piles; do
  aws cloudformation describe-stacks --stack-name "$pile" > /dev/null 2>&1 || continue
  horodatage "suppression de $pile"
  aws cloudformation delete-stack --stack-name "$pile"
  aws cloudformation wait stack-delete-complete --stack-name "$pile"
done
horodatage "environnement $ENV supprimé (pile portail-bootstrap conservée : rôles OIDC)"
aws cloudformation describe-stacks --query "Stacks[?starts_with(StackName,'portail-${ENV}')].StackName" --output text \
  | sed 's/^$/aucune pile portail-'"$ENV"' restante/'
