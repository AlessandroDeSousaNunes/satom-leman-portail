#!/usr/bin/env bash
# Lit les derniers résultats des sondes TCP (console série des instances de test).
# Usage : bash tests/connectivite/sondes.sh dev [nombre de lignes]
set -euo pipefail
ENV="${1:-dev}"; N="${2:-4}"
PILE="portail-${ENV}-dev-peering"
sortie() { aws cloudformation describe-stacks --stack-name "$PILE" --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text; }
for n in Web01 Dev01; do
  id=$(sortie "$n")
  echo "== $n ($id) : dernières sondes"
  aws ec2 get-console-output --instance-id "$id" --latest --query Output --output text \
    | grep -aoE 'SONDE [0-9:]+ [^ ]+ -> [0-9.:]+ (OUVERT|FERME)' | tail -n "$N"
done
