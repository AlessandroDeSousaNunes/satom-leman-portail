#!/usr/bin/env bash
# Mesures du sprint 8 : passerelle Direct Connect, préfixes autorisés, attachement sur la TGW.
set -euo pipefail
ENV="${1:-dev}"
for g in $(aws directconnect describe-direct-connect-gateways \
    --query "directConnectGateways[?starts_with(directConnectGatewayName,'dxgw-leman-${ENV}')].directConnectGatewayId" --output text); do
  aws directconnect describe-direct-connect-gateways --direct-connect-gateway-id "$g" \
    --query 'directConnectGateways[0].[directConnectGatewayName,amazonSideAsn,directConnectGatewayState]' --output text | sed 's/^/== passerelle (nom, ASN, etat) : /'
  aws directconnect describe-direct-connect-gateway-associations --direct-connect-gateway-id "$g" \
    --query 'directConnectGatewayAssociations[].[associatedGateway.id,associatedGateway.type,associationState, join(`,`, allowedPrefixesToDirectConnectGateway[].cidr)]' \
    --output text | sed 's/^/   association (passerelle, type, etat, prefixes annonces) : /'
  echo "   interfaces virtuelles (aucune connexion physique commandee) : $(aws directconnect describe-virtual-interfaces --query "length(virtualInterfaces[?directConnectGatewayId=='$g'])")"
done
TGW=$(aws cloudformation list-exports --query "Exports[?Name=='portail-${ENV}-TgwId'].Value" --output text)
echo "== Attachements de la TGW $TGW"
aws ec2 describe-transit-gateway-attachments --filters Name=transit-gateway-id,Values="$TGW" \
  --query 'TransitGatewayAttachments[].[ResourceType,ResourceId,State,Association.TransitGatewayRouteTableId]' --output text
