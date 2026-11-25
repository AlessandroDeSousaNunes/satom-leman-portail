#!/usr/bin/env bash
# Mesures du sprint 10 : résolution depuis l'extérieur (serveurs faisant autorité), temps de réponse,
# DNSSEC, surveillance d'état. Option « bascule » : panne simulée de l'ALB et bascule chronométrée.
# Usage : bash tests/connectivite/dns.sh dev [bascule]
set -euo pipefail
ENV="${1:-dev}"; MODE="${2:-mesure}"
ZONE="${ENV}.leman-finance.example"; NOM="portefeuilles.${ZONE}"
sortie() { aws cloudformation describe-stacks --stack-name "portail-${ENV}-dns" --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text; }
NS=$(sortie ServeursDeNoms | cut -d, -f1)
HC=$(sortie SurveillanceAlbId)
echo "== Zone $ZONE, serveur faisant autorité : $NS (domaine fictif, non délégué)"
reponse() { dig +norecurse +noall +answer "@$NS" "$NOM" CNAME | awk '{print $5}'; }
echo "== Résolution de $NOM"
dig +norecurse "@$NS" "$NOM" CNAME | grep -E "^${NOM}|Query time"
echo "== Temps de résolution sur 10 requêtes (objectif < 100 ms)"
for i in $(seq 1 10); do dig +norecurse "@$NS" "$NOM" CNAME | awk '/Query time/{print $4}'; done \
  | awk '{s+=$1; if($1>m)m=$1} END {printf "moyenne %.1f ms, maximum %d ms\n", s/NR, m}'
echo "== DNSSEC (ADR 0007 : clé KMS en us-east-1 interdite par la SCP, non activé)"
cles=$(dig +norecurse +dnssec "@$NS" "$ZONE" DNSKEY | grep -cE "DNSKEY\s+25[67]" || true)
echo "clés DNSKEY publiées : $cles"
aws route53 get-dnssec --hosted-zone-id "$(sortie ZonePubliqueId)" --query 'Status.ServeSignature' --output text   | sed 's/^/statut DNSSEC de la zone : /'
echo "== Surveillance d'état de l'ALB ($HC)"
aws route53 get-health-check-status --health-check-id "$HC" \
  --query 'HealthCheckObservations[].StatusReport.Status' --output text | tr '\t' '\n' | sort | uniq -c | head -5
echo "== Aucun enregistrement de la zone publique vers une adresse privée"
aws route53 list-resource-record-sets --hosted-zone-id "$(sortie ZonePubliqueId)" \
  --query "ResourceRecordSets[?Type=='A'].ResourceRecords[].Value" --output text | tr '\t' '\n' \
  | grep -cE '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)' | sed 's/^/adresses privées publiées : /' || true

if [ "$MODE" = bascule ]; then
  CLUSTER="eks-portail-${ENV}-ADSN"
  aws eks update-kubeconfig --name "$CLUSTER" > /dev/null
  echo "== Panne simulée : web mis à 0 réplique ($(date -u +%T))"
  kubectl -n portail scale deploy/web --replicas=0
  debut=$(date +%s)
  for i in $(seq 1 60); do
    cible=$(reponse)
    if [[ "$cible" == maintenance* ]]; then
      echo "bascule DNS vers $cible après $(( $(date +%s) - debut )) s (objectif < 60 s)"; break
    fi
    sleep 5
  done
  echo "== Retour à la normale ($(date -u +%T))"
  kubectl -n portail scale deploy/web --replicas=2
  kubectl -n portail rollout status deploy/web --timeout=180s
  debut=$(date +%s)
  for i in $(seq 1 60); do
    cible=$(reponse)
    if [[ -n "$cible" && "$cible" != maintenance* ]]; then
      echo "retour sur le portail (CloudFront ou ALB) après $(( $(date +%s) - debut )) s : $cible"; break
    fi
    sleep 5
  done
fi
