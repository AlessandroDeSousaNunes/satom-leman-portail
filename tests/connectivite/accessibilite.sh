#!/usr/bin/env bash
# Mesures des sprints 3 et 5 avec VPC Reachability Analyzer (sans trafic réel, analyse de configuration).
#   web-01 -> app-01 : 8080 joignable, 22 bloqué       (sprint 3)
#   dev-01 -> app-01 : 8080 joignable via le peering   (sprint 5)
#   dev-01 -> web-01 : 22 bloqué                         (sprint 5)
# Usage : bash tests/connectivite/accessibilite.sh dev
set -euo pipefail
ENV="${1:-dev}"
PILE="portail-${ENV}-dev-peering"
sortie() { aws cloudformation describe-stacks --stack-name "$PILE" --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text; }
WEB=$(sortie Web01); APP=$(sortie App01); DEV=$(sortie Dev01)
echo "web-01=$WEB app-01=$APP dev-01=$DEV"
printf '%-24s %-6s %-10s %-10s %s\n' "chemin" "port" "attendu" "resultat" "explication"

mesurer() {
  local nom=$1 src=$2 dst=$3 port=$4 attendu=$5
  local chemin analyse trouve explication
  chemin=$(aws ec2 create-network-insights-path --source "$src" --destination "$dst" --protocol tcp \
    --destination-port "$port" --tag-specifications "ResourceType=network-insights-path,Tags=[{Key=Name,Value=$nom-$port},{Key=Projet,Value=SatomCloudNetwork},{Key=Equipe,Value=ADSN}]" \
    --query NetworkInsightsPath.NetworkInsightsPathId --output text)
  analyse=$(aws ec2 start-network-insights-analysis --network-insights-path-id "$chemin" \
    --query NetworkInsightsAnalysis.NetworkInsightsAnalysisId --output text)
  for _ in $(seq 1 40); do
    etat=$(aws ec2 describe-network-insights-analyses --network-insights-analysis-ids "$analyse" \
      --query 'NetworkInsightsAnalyses[0].Status' --output text)
    [ "$etat" != running ] && break
    sleep 5
  done
  trouve=$(aws ec2 describe-network-insights-analyses --network-insights-analysis-ids "$analyse" \
    --query 'NetworkInsightsAnalyses[0].NetworkPathFound' --output text)
  explication=$(aws ec2 describe-network-insights-analyses --network-insights-analysis-ids "$analyse" \
    --query 'NetworkInsightsAnalyses[0].Explanations[0].[ExplanationCode,SecurityGroup.Id]' --output text 2>/dev/null | tr '\t' ' ')
  [ "$trouve" = True ] && res=joignable || res=bloque
  printf '%-24s %-6s %-10s %-10s %s\n' "$nom" "$port" "$attendu" "$res" "${explication:-chemin complet}"
}

ECHECS=0
mesurer "web-01 -> app-01" "$WEB" "$APP" 8080 joignable
mesurer "web-01 -> app-01" "$WEB" "$APP" 22 bloque
mesurer "dev-01 -> app-01" "$DEV" "$APP" 8080 joignable
mesurer "dev-01 -> web-01" "$DEV" "$WEB" 22 bloque
[ "$ECHECS" -eq 0 ] || { echo "$ECHECS analyse(s) en échec côté AWS : relancer plus tard"; exit 2; }
