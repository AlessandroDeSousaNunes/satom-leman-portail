#!/usr/bin/env bash
# État du déploiement : piles du portail et ressources facturées à l'heure.
set -euo pipefail
ENV="${1:-dev}"
echo "== Piles portail-${ENV}-*"
aws cloudformation describe-stacks \
  --query "Stacks[?starts_with(StackName,'portail-${ENV}-') || StackName=='portail-bootstrap'].[StackName,StackStatus]" --output text | sort
echo "== Ressources facturées à l'heure (étiquette Environnement=${ENV}, équipe ADSN)"
f="Name=tag:Equipe,Values=ADSN Name=tag:Environnement,Values=${ENV}"
printf '%-22s %s\n' "Instances" "$(aws ec2 describe-instances --filters $f Name=instance-state-name,Values=running --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value[]' --output text)"
printf '%-22s %s\n' "NAT Gateways" "$(aws ec2 describe-nat-gateways --filter $f Name=state,Values=available --query 'NatGateways[].NatGatewayId' --output text)"
printf '%-22s %s\n' "Transit Gateways" "$(aws ec2 describe-transit-gateways --filters $f Name=state,Values=available --query 'TransitGateways[].TransitGatewayId' --output text)"
printf '%-22s %s\n' "VPN" "$(aws ec2 describe-vpn-connections --filters $f Name=state,Values=available,pending --query 'VpnConnections[].VpnConnectionId' --output text)"
printf '%-22s %s\n' "Clusters EKS" "$(aws eks list-clusters --query 'clusters[?contains(@, `portail`)]' --output text)"
