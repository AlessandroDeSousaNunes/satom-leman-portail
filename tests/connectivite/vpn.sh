#!/usr/bin/env bash
# Mesures du sprint 7 : VPN site à site (BGP, IKEv2), état des tunnels, rattachement TGW, alarmes TunnelState.
set -euo pipefail
ENV="${1:-dev}"
f="Name=tag:Equipe,Values=ADSN Name=tag:Environnement,Values=${ENV} Name=state,Values=available,pending"
for v in $(aws ec2 describe-vpn-connections --filters $f --query 'VpnConnections[].VpnConnectionId' --output text); do
  echo "== $(aws ec2 describe-vpn-connections --vpn-connection-ids "$v" --query 'VpnConnections[0].Tags[?Key==`Name`].Value|[0]' --output text) ($v)"
  aws ec2 describe-vpn-connections --vpn-connection-ids "$v" --query 'VpnConnections[0].{passerelle_client:CustomerGatewayId,routage:(Options.StaticRoutesOnly && `statique` || `BGP`),etat:State}' --output text
  aws ec2 describe-customer-gateways --customer-gateway-ids "$(aws ec2 describe-vpn-connections --vpn-connection-ids "$v" --query 'VpnConnections[0].CustomerGatewayId' --output text)" \
    --query 'CustomerGateways[0].[IpAddress,BgpAsn]' --output text | sed 's/^/   site (IP, ASN) : /'
  aws ec2 describe-vpn-connections --vpn-connection-ids "$v" \
    --query 'VpnConnections[0].Options.TunnelOptions[].[OutsideIpAddress, join(`,`, IkeVersions[].Value), join(`,`, Phase1EncryptionAlgorithms[].Value), join(`,`, Phase1DHGroupNumbers[].to_string(Value))]' \
    --output text | sed 's/^/   tunnel (IP AWS, IKE, chiffrement, DH) : /'
  aws ec2 describe-vpn-connections --vpn-connection-ids "$v" \
    --query 'VpnConnections[0].VgwTelemetry[].[OutsideIpAddress,Status,StatusMessage]' --output text | sed 's/^/   etat tunnel : /'
  aws ec2 describe-transit-gateway-attachments --filters Name=resource-id,Values="$v" \
    --query 'TransitGatewayAttachments[0].[TransitGatewayAttachmentId,Association.TransitGatewayRouteTableId,Association.State]' --output text | sed 's/^/   attachement TGW, table, etat : /'
done
echo "== Pré-clés : secret Secrets Manager créé par la pile (la valeur n'est jamais lue ni affichée)"
aws cloudformation describe-stack-resources --stack-name "portail-${ENV}-vpn" --logical-resource-id PreCles --query 'StackResources[0].[ResourceType,PhysicalResourceId,ResourceStatus]' --output text | sed -E 's/-[A-Za-z0-9]{6}$//'
echo "== Alarmes TunnelState"
aws cloudwatch describe-alarms --alarm-name-prefix "portail-${ENV}-vpn" \
  --query 'MetricAlarms[].[AlarmName,StateValue,StateReason]' --output text | cut -c1-160
