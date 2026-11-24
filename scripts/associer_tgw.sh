#!/usr/bin/env bash
# Étape de la pipeline (sprints 7 et 8) : CloudFormation ne renvoie pas l'identifiant de l'attachement TGW
# d'un VPN ni d'une passerelle Direct Connect. Ce script, idempotent :
#   - associe chaque attachement vpn / direct-connect-gateway à la table rt-tgw-sites ;
#   - propage ses routes dans rt-tgw-prod (le VPC principal voit les sites, le VPC dev jamais).
set -euo pipefail
ENV="${1:-dev}"
exporte() { aws cloudformation list-exports --query "Exports[?Name=='$1'].Value" --output text; }
TGW=$(exporte "portail-${ENV}-TgwId")
[ -z "$TGW" ] && { echo "pas de Transit Gateway : rien à associer"; exit 0; }
SITES=$(exporte "portail-${ENV}-RtTgwSites")
PROD=$(exporte "portail-${ENV}-RtTgwProd")

for a in $(aws ec2 describe-transit-gateway-attachments \
    --filters Name=transit-gateway-id,Values="$TGW" Name=resource-type,Values=vpn,direct-connect-gateway Name=state,Values=available \
    --query 'TransitGatewayAttachments[].TransitGatewayAttachmentId' --output text); do
  assoc=$(aws ec2 describe-transit-gateway-attachments --transit-gateway-attachment-ids "$a" \
    --query 'TransitGatewayAttachments[0].Association.TransitGatewayRouteTableId' --output text)
  if [ "$assoc" = "None" ]; then
    aws ec2 associate-transit-gateway-route-table --transit-gateway-route-table-id "$SITES" \
      --transit-gateway-attachment-id "$a" --query 'Association.State' --output text
    echo "$a associé à rt-tgw-sites"
  else
    echo "$a déjà associé ($assoc)"
  fi
  # propagation idempotente : une propagation déjà active renvoie une erreur "Duplicate", ignorée
  if sortie=$(aws ec2 enable-transit-gateway-route-table-propagation --transit-gateway-route-table-id "$PROD"       --transit-gateway-attachment-id "$a" --query 'Propagation.State' --output text 2>&1); then
    echo "$a propagé dans rt-tgw-prod ($sortie)"
  elif grep -q Duplicate <<< "$sortie"; then
    echo "$a déjà propagé dans rt-tgw-prod"
  else
    echo "$sortie" >&2; exit 1
  fi
done
