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
# GET réels (une réponse HEAD en cache ne prouve rien) ; seul un 200 servi depuis le cache compte
statique() { curl -s -o /dev/null -D - "$CDN/static/portail.css" | tr -d '\r' \
  | awk -F': ' 'NR==1{code=$0} tolower($1)=="x-cache"{print code " | " $2}'; }
echo "== Fichier statique /static/portail.css : 20 requêtes GET (statut | x-cache)"
for i in $(seq 1 20); do statique; done | sort | uniq -c
echo "== Taux de cache statique sur 50 requêtes GET (objectif > 80 %, réponses 200 seulement)"
for i in $(seq 1 50); do statique; done \
  | awk '/ 200 / && /Hit/{h++} END {printf "%d succès de cache (200) sur %d, soit %.0f %%\n", h, NR, 100*h/NR}'
echo "== API à travers CloudFront (jamais en cache)"
curl -s -D - "$CDN/api/health" -o /tmp/api.json | tr -d '\r' | grep -iE '^(HTTP|x-cache|strict-transport|x-content-type)'
cat /tmp/api.json; echo
echo "== Redirection HTTP -> HTTPS"
curl -sI "${CDN/https/http}/" | tr -d '\r' | grep -iE '^(HTTP|location)'
echo "== ALB joint directement depuis Internet (doit échouer : seul CloudFront est autorisé)"
ALB=$(aws elbv2 describe-load-balancers --names "alb-${ENV}-leman-ADSN" --query 'LoadBalancers[0].DNSName' --output text)
if curl -sk -m 8 -o /dev/null -w '%{http_code}' "https://$ALB/health"; then echo " : ALB joignable (ECHEC)"; else echo "ALB injoignable hors CloudFront (délai dépassé) : conforme"; fi
if [ "$MODE" = waf ]; then
  # Une règle de limitation de débit WAF agit avec 30 à 60 s de retard : envoi soutenu pendant 4 min au plus,
  # par salves de 25 requêtes parallèles, jusqu'au premier 403, chronométré.
  echo "== WAF : envoi soutenu depuis une seule IP (limite 500 requêtes / 5 min par IP de visiteur)"
  debut=$(date +%s); total=0; bloque=0; premier=""
  while (( $(date +%s) - debut < 240 )); do
    for code in $(seq 1 25 | xargs -P 25 -I{} curl -s -o /dev/null -w '%{http_code}\n' "$CDN/api/health"); do
      total=$((total + 1))
      if [[ "$code" == 403 ]]; then
        bloque=$((bloque + 1)); [[ -z "$premier" ]] && premier="$total requêtes, $(( $(date +%s) - debut )) s"
      fi
    done
    (( bloque >= 50 )) && break
  done
  echo "requêtes envoyées : $total ; bloquées (403) : $bloque"
  echo "premier blocage : ${premier:-aucun en 240 s}"
  echo "== Réponse bloquée (extrait)"
  curl -s -D - -o /dev/null "$CDN/api/health" | tr -d '\r' | grep -iE '^(HTTP|x-cache|server)'
fi
