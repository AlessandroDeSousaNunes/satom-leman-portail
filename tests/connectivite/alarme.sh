#!/usr/bin/env bash
# Sprint 12 : test de bout en bout de l'alarme 5xx (CloudWatch -> SNS -> e-mail de l'exploitant).
# 1. panne simulée sur l'API (PANNE_SIMULEE=1), 2. trafic réel par CloudFront, 3. attente de l'état ALARM,
# 4. retour à la normale, 5. attente de l'état OK. Chaque étape est horodatée (UTC) pour mesurer les délais.
# Usage : bash tests/connectivite/alarme.sh dev
set -euo pipefail
ENV="${1:-dev}"
ALARME="portail-${ENV}-alb-5xx"
CLUSTER="eks-portail-${ENV}-ADSN"
heure() { date -u +%T; }
etat() { aws cloudwatch describe-alarms --alarm-names "$ALARME" --query 'MetricAlarms[0].StateValue' --output text; }
CDN="https://$(aws cloudformation describe-stacks --stack-name "portail-${ENV}-cloudfront" \
  --query "Stacks[0].Outputs[?OutputKey=='DomaineCloudFront'].OutputValue" --output text)"
aws eks update-kubeconfig --name "$CLUSTER" > /dev/null

echo "== Alarme $ALARME : seuil > 5 réponses 5xx des cibles en 1 min, action SNS"
aws cloudwatch describe-alarms --alarm-names "$ALARME" \
  --query 'MetricAlarms[0].[StateValue,MetricName,Threshold,Period,length(AlarmActions)]' --output text

echo "== [$(heure)] Panne simulée : PANNE_SIMULEE=1 sur le déploiement api"
kubectl -n portail set env deploy/api PANNE_SIMULEE=1 > /dev/null
kubectl -n portail rollout status deploy/api --timeout=180s
debut_panne=$(date +%s)
curl -s -o /dev/null -w "[$(heure)] /api/portefeuilles -> %{http_code}\n" "$CDN/api/portefeuilles"

echo "== Trafic réel par CloudFront jusqu'à l'état ALARM (au plus 10 min)"
alarme_a=""
for i in $(seq 1 60); do
  for j in $(seq 1 20); do curl -s -o /dev/null "$CDN/api/portefeuilles"; done
  if [[ "$(etat)" == ALARM ]]; then alarme_a=$(date +%s); break; fi
  sleep 10
done
if [[ -n "$alarme_a" ]]; then
  echo "[$(heure)] alarme en ALARM, $(( alarme_a - debut_panne )) s après le début de la panne (SNS notifie l'exploitant)"
else
  echo "[$(heure)] ECHEC : alarme toujours $(etat) après 10 min"
fi

echo "== [$(heure)] Retour à la normale : PANNE_SIMULEE retirée"
kubectl -n portail set env deploy/api PANNE_SIMULEE- > /dev/null
kubectl -n portail rollout status deploy/api --timeout=180s
debut_retour=$(date +%s)
curl -s -o /dev/null -w "[$(heure)] /api/portefeuilles -> %{http_code}\n" "$CDN/api/portefeuilles"
for i in $(seq 1 40); do
  if [[ "$(etat)" == OK ]]; then
    echo "[$(heure)] alarme revenue à OK, $(( $(date +%s) - debut_retour )) s après le retour à la normale"; break
  fi
  sleep 15
done

echo "== Historique de l'alarme (changements d'état)"
aws cloudwatch describe-alarm-history --alarm-name "$ALARME" --history-item-type StateUpdate --max-items 4 \
  --query 'AlarmHistoryItems[].[Timestamp,HistorySummary]' --output text
[[ -n "$alarme_a" ]]
