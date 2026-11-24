#!/usr/bin/env bash
# Certificat TLS de l'Ingress (sprint 9). Le domaine portefeuilles.leman-finance.example est fictif :
# aucun certificat public ACM ne peut être validé. Un certificat auto-signé est généré puis importé
# dans ACM une seule fois (repéré par l'étiquette Usage=ingress-portail-<env>). Affiche son ARN.
# La clé privée ne quitte pas le runner et n'est jamais écrite dans le dépôt.
set -euo pipefail
ENV="${1:-dev}"
DOMAINE="portefeuilles.leman-finance.example"
for arn in $(aws acm list-certificates --certificate-statuses ISSUED --query 'CertificateSummaryList[].CertificateArn' --output text); do
  usage=$(aws acm list-tags-for-certificate --certificate-arn "$arn" --query "Tags[?Key=='Usage'].Value" --output text)
  if [ "$usage" = "ingress-portail-${ENV}" ]; then echo "$arn"; exit 0; fi
done
dossier=$(mktemp -d)
openssl req -x509 -newkey rsa:2048 -nodes -days 90 -subj "/CN=${DOMAINE}" \
  -addext "subjectAltName=DNS:${DOMAINE},DNS:*.elb.amazonaws.com" \
  -keyout "$dossier/cle.pem" -out "$dossier/cert.pem" 2>/dev/null
aws acm import-certificate --certificate "fileb://$dossier/cert.pem" --private-key "fileb://$dossier/cle.pem" \
  --tags Key=Usage,Value="ingress-portail-${ENV}" Key=Projet,Value=SatomCloudNetwork Key=Equipe,Value=ADSN \
  --query CertificateArn --output text
rm -rf "$dossier"
