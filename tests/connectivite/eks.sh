#!/usr/bin/env bash
# Mesures du sprint 9 : cluster EKS, nœuds, application, NetworkPolicy, Ingress (ALB HTTPS) et tests HTTP.
set -euo pipefail
ENV="${1:-dev}"
CLUSTER="eks-portail-${ENV}-ADSN"
echo "== Cluster $CLUSTER (version, état, accès public/privé, chiffrement des secrets, journaux)"
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.[version,status,resourcesVpcConfig.endpointPublicAccess,resourcesVpcConfig.endpointPrivateAccess,length(encryptionConfig),join(`,`,logging.clusterLogging[?enabled].types[])]' --output text
aws eks update-kubeconfig --name "$CLUSTER" > /dev/null
echo "== Nœuds"
kubectl get nodes -o wide --no-headers | awk '{print $1, $2, $5, $6, $8}'
echo "== Namespace portail (profil Pod Security)"
kubectl get ns portail -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'; echo
echo "== Pods et images (digest)"
kubectl -n portail get pods -o custom-columns='POD:.metadata.name,ETAT:.status.phase,NOEUD:.spec.nodeName,IMAGE:.spec.containers[0].image' --no-headers | sed -E 's#(sha256:[0-9a-f]{12})[0-9a-f]+#\1…#'
echo "== Contexte de sécurité du conteneur web"
kubectl -n portail get deploy web -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot} {.spec.template.spec.containers[0].securityContext}'; echo
echo "== NetworkPolicy"
kubectl -n portail get networkpolicy --no-headers | awk '{print $1, $2}'
echo "== Ingress et ALB"
HOTE=$(kubectl -n portail get ingress portail -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "$HOTE"
aws elbv2 describe-load-balancers --query "LoadBalancers[?DNSName=='$HOTE'].[LoadBalancerName,Scheme,State.Code]" --output text
ALB=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?DNSName=='$HOTE'].LoadBalancerArn" --output text)
aws elbv2 describe-listeners --load-balancer-arn "$ALB" --query 'Listeners[].[Protocol,Port,SslPolicy]' --output text
echo "== Tests HTTPS depuis Internet"
bash "$(dirname "$0")/verifier.sh" "https://$HOTE"
