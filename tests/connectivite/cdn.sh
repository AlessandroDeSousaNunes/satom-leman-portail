#!/usr/bin/env bash
# Mesures du sprint 11 : CloudFront (cache, en-têtes, API sans cache), ALB fermé hors CloudFront, WAF.
# Usage : bash tests/connectivite/cdn.sh dev [waf]
set -euo pipefail
ENV="${1:-dev}"; MODE="${2:-mesure}"
sortie() { aws cloudformation describe-stacks --stack-name "portail-${ENV}-cloudfront" --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text; }
CDN="https://$(sortie DomaineCloudFront)"
echo "== Distribution $(sortie DistributionId) : $CDN"
aws cloudfront get-distribution --id "$(sortie DistributionId)" \
  --query 'Distribution.[Status,DistributionConfig.HttpVersion,DistributionConfig.WebACLId!=``]' --output text | sed 's/^/etat, HTTP, WAF associe : /'
echo "== Comportements (chemin -> origine)"
aws cloudfront get-distribution --id "$(sortie DistributionId)" \
  --query 'Distribution.DistributionConfig.CacheBehaviors.Items[].[PathPattern,TargetOriginId,ViewerProtocolPolicy]' --output text
echo "== Fichier statique /static/portail.css : 20 requêtes, en-tête x-cache"
for i in $(seq 1 20); do curl -sI "$CDN/static/portail.css" | tr -d '\r' | awk -F': ' 'tolower($1)=="x-cache"{print $2}'; done | sort | uniq -c
echo "== Taux de cache statique sur 50 requêtes (objectif > 80 %)"
for i in $(seq 1 50); do curl -sI "$CDN/static/portail.css" | tr -d '\r' | awk -F': ' 'tolower($1)=="x-cache"{print $2}'; done \
  | awk '/Hit/{h++} END {printf "%d succès de cache sur %d, soit %.0f %%\n", h, NR, 100*h/NR}'
echo "== API à travers CloudFront (jamais en cache)"
curl -s -D - "$CDN/api/health" -o /tmp/api.json | tr -d '\r' | grep -iE '^(HTTP|x-cache|strict-transport|x-content-type)'
cat /tmp/api.json; echo
echo "== Redirection HTTP -> HTTPS"
curl -sI "${CDN/https/http}/" | tr -d '\r' | grep -iE '^(HTTP|location)'
echo "== ALB joint directement depuis Internet (doit échouer : seul CloudFront est autorisé)"
ALB=$(aws elbv2 describe-load-balancers --names "alb-${ENV}-leman-ADSN" --query 'LoadBalancers[0].DNSName' --output text)
if curl -sk -m 8 -o /dev/null -w '%{http_code}' "https://$ALB/health"; then echo " : ALB joignable (ECHEC)"; else echo "ALB injoignable hors CloudFront (délai dépassé) : conforme"; fi
if [ "$MODE" = waf ]; then
  echo "== WAF : 700 requêtes rapides depuis une seule IP (limite 500 / 5 min)"
  for i in $(seq 1 700); do curl -s -o /dev/null -w '%{http_code}\n' "$CDN/api/health"; done | sort | uniq -c
fi
