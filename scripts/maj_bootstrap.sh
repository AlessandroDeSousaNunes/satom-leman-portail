#!/usr/bin/env bash
# Mise à jour de la pile portail-bootstrap (rôles IAM), seule pile déployée par l'administrateur.
# Jeu de modifications relu : refus si un remplacement ou une suppression est annoncé.
# Usage (CloudShell, dans le dépôt cloné) : bash scripts/maj_bootstrap.sh nom-du-jeu
set -euo pipefail
CS="${1:?nom du jeu de modifications}"
PILE=portail-bootstrap
aws cloudformation create-change-set --stack-name "$PILE" --change-set-name "$CS" \
  --template-body file://templates/00-bootstrap.yaml \
  --parameters ParameterKey=FournisseurOidcExistant,UsePreviousValue=true \
  --capabilities CAPABILITY_NAMED_IAM --query Id --output text > /dev/null
aws cloudformation wait change-set-create-complete --stack-name "$PILE" --change-set-name "$CS"
aws cloudformation describe-change-set --stack-name "$PILE" --change-set-name "$CS" \
  --query 'Changes[].ResourceChange.[Action,LogicalResourceId,Replacement]' --output text | tee /tmp/cs.txt
if grep -qE 'Remove|True' /tmp/cs.txt; then
  echo "REFUS : suppression ou remplacement annoncé"; exit 2
fi
aws cloudformation execute-change-set --stack-name "$PILE" --change-set-name "$CS"
aws cloudformation wait stack-update-complete --stack-name "$PILE"
aws cloudformation describe-stacks --stack-name "$PILE" --query 'Stacks[0].[StackStatus,LastUpdatedTime]' --output text
