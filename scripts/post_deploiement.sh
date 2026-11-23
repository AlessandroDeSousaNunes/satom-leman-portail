#!/usr/bin/env bash
# Étape 7 : vérifications après déploiement (alarmes, conformité, dérive des piles).
set -euo pipefail
ENV="${ENVIRONNEMENT:-prod}"

echo "## Vérifications post-déploiement ($ENV, $(date -u +%FT%TZ))"
echo
echo "### Piles CloudFormation"
aws cloudformation describe-stacks \
  --query "Stacks[?starts_with(StackName, 'portail-${ENV}-')].[StackName,StackStatus]" --output text |
  sed 's/^/- /'

echo
echo "### Dérive des piles"
for pile in $(aws cloudformation describe-stacks \
    --query "Stacks[?starts_with(StackName, 'portail-${ENV}-')].StackName" --output text); do
  id=$(aws cloudformation detect-stack-drift --stack-name "$pile" --query StackDriftDetectionId --output text)
  for _ in $(seq 1 30); do
    etat=$(aws cloudformation describe-stack-drift-detection-status --stack-drift-detection-id "$id" \
      --query '[DetectionStatus,StackDriftStatus]' --output text)
    [[ "$etat" == DETECTION_IN_PROGRESS* ]] || break
    sleep 5
  done
  echo "- $pile : $etat"
done

echo
echo "### Alarmes en état ALARM"
alarmes=$(aws cloudwatch describe-alarms --state-value ALARM --alarm-name-prefix "portail-${ENV}" \
  --query 'MetricAlarms[].AlarmName' --output text)
echo "- ${alarmes:-aucune}"
