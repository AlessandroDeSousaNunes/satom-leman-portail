#!/usr/bin/env bash
# Mesures du sprint 6 : tables de routage séparées de la Transit Gateway et routes des VPC.
# Attendu : rt-tgw-prod voit dev (et les sites), rt-tgw-dev ne voit que le VPC principal,
#           rt-tgw-sites ne voit que le VPC principal.
set -euo pipefail
ENV="${1:-dev}"
e() { aws cloudformation list-exports --query "Exports[?Name=='$1'].Value" --output text; }
TGW=$(e "portail-${ENV}-TgwId")
echo "== Transit Gateway $TGW (ASN, association par défaut, propagation par défaut, état)"
aws ec2 describe-transit-gateways --transit-gateway-ids "$TGW" \
  --query 'TransitGateways[0].[Options.AmazonSideAsn,Options.DefaultRouteTableAssociation,Options.DefaultRouteTablePropagation,State]' --output text
for rt in $(aws ec2 describe-transit-gateway-route-tables --filters Name=transit-gateway-id,Values="$TGW" \
    --query 'TransitGatewayRouteTables[].TransitGatewayRouteTableId' --output text); do
  nom=$(aws ec2 describe-transit-gateway-route-tables --transit-gateway-route-table-ids "$rt" \
    --query 'TransitGatewayRouteTables[0].Tags[?Key==`Name`].Value|[0]' --output text)
  echo "== $nom ($rt) : associations puis routes actives"
  aws ec2 get-transit-gateway-route-table-associations --transit-gateway-route-table-id "$rt" \
    --query 'Associations[].[ResourceType,ResourceId]' --output text | sed 's/^/   associe : /'
  aws ec2 search-transit-gateway-routes --transit-gateway-route-table-id "$rt" --filters Name=state,Values=active \
    --query 'Routes[].[DestinationCidrBlock,Type,TransitGatewayAttachments[0].ResourceType]' --output text | sed 's/^/   route   : /'
done
echo "== Routes des VPC vers la TGW"
for rt in $(e "portail-${ENV}-RtPrive") $(e "portail-${ENV}-RtDev"); do
  aws ec2 describe-route-tables --route-table-ids "$rt" \
    --query 'RouteTables[0].[Tags[?Key==`Name`].Value|[0], join(`, `, Routes[?TransitGatewayId].DestinationCidrBlock)]' --output text
done
