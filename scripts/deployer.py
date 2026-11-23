"""Déploie un template CloudFormation par jeu de modifications (change set).

Règle du TP (section 2.1, étape 4) : aucune suppression ni remplacement non confirmé.
Le script crée le change set, l'affiche, puis :
- l'exécute s'il ne contient que des ajouts ou des modifications sans remplacement ;
- le refuse (code 2) s'il contient une suppression ou un remplacement, sauf --confirmer-remplacement.

Usage : python scripts/deployer.py templates/01-reseau.yaml parameters/dev.json [--role-cfn ARN]
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import boto3
from botocore.exceptions import ClientError, WaiterError

ORDRE = {
    "00-bootstrap": "bootstrap",
    "01-reseau": "reseau",
    "02-securite": "securite",
    "03-sortie-internet": "sortie-internet",
}


def nom_pile(template: Path, environnement: str) -> str:
    base = template.stem
    suffixe = ORDRE.get(base, base.split("-", 1)[-1])
    return f"portail-{environnement}-{suffixe}"


def parametres_du_template(cfn, corps: str, valeurs: dict[str, str]) -> list[dict[str, str]]:
    """Ne garde que les paramètres déclarés par le template."""
    resume = cfn.get_template_summary(TemplateBody=corps)
    declares = {p["ParameterKey"] for p in resume["Parameters"]}
    return [{"ParameterKey": k, "ParameterValue": v} for k, v in valeurs.items() if k in declares]


def pile_existe(cfn, pile: str) -> bool:
    try:
        etat = cfn.describe_stacks(StackName=pile)["Stacks"][0]["StackStatus"]
    except ClientError:
        return False
    return etat != "REVIEW_IN_PROGRESS"


def changements_dangereux(changements: list[dict]) -> list[str]:
    alertes = []
    for c in changements:
        rc = c["ResourceChange"]
        if rc["Action"] == "Remove" or rc.get("Replacement") in ("True", "Conditional"):
            alertes.append(f"{rc['Action']} {rc['LogicalResourceId']} (remplacement={rc.get('Replacement')})")
    return alertes


def deployer(template: Path, fichier_parametres: Path, role_cfn: str | None, confirmer: bool) -> int:
    valeurs = json.loads(fichier_parametres.read_text(encoding="utf-8"))
    environnement = valeurs["Environnement"]
    pile = nom_pile(template, environnement)
    corps = template.read_text(encoding="utf-8")
    cfn = boto3.client("cloudformation")

    type_cs = "UPDATE" if pile_existe(cfn, pile) else "CREATE"
    nom_cs = f"cs-{int(time.time())}"
    options = {
        "StackName": pile,
        "ChangeSetName": nom_cs,
        "ChangeSetType": type_cs,
        "TemplateBody": corps,
        "Parameters": parametres_du_template(cfn, corps, valeurs),
        "Capabilities": ["CAPABILITY_NAMED_IAM"],
        "Tags": [
            {"Key": "Projet", "Value": "SatomCloudNetwork"},
            {"Key": "Equipe", "Value": valeurs.get("Equipe", "ADSN")},
            {"Key": "Environnement", "Value": environnement},
        ],
    }
    if role_cfn:
        options["RoleARN"] = role_cfn
    print(f"== {pile} : jeu de modifications {nom_cs} ({type_cs})")
    cfn.create_change_set(**options)

    try:
        cfn.get_waiter("change_set_create_complete").wait(
            StackName=pile, ChangeSetName=nom_cs, WaiterConfig={"Delay": 5, "MaxAttempts": 120}
        )
    except WaiterError:
        detail = cfn.describe_change_set(StackName=pile, ChangeSetName=nom_cs)
        raison = detail.get("StatusReason", "")
        if "didn't contain changes" in raison or "No updates" in raison:
            print("   aucun changement : rien à déployer")
            cfn.delete_change_set(StackName=pile, ChangeSetName=nom_cs)
            return 0
        print(f"   echec de creation du change set : {raison}")
        return 1

    detail = cfn.describe_change_set(StackName=pile, ChangeSetName=nom_cs)
    changements = detail["Changes"]
    for c in changements:
        rc = c["ResourceChange"]
        remplacement = rc.get("Replacement", "-")
        print(f"   {rc['Action']:<7} {rc['LogicalResourceId']:<28} {rc['ResourceType']:<40} {remplacement}")

    alertes = changements_dangereux(changements)
    if alertes and not confirmer:
        print("   REFUS : suppression ou remplacement non confirmé :")
        for a in alertes:
            print(f"     - {a}")
        return 2

    cfn.execute_change_set(StackName=pile, ChangeSetName=nom_cs)
    attente = "stack_create_complete" if type_cs == "CREATE" else "stack_update_complete"
    debut = time.time()
    try:
        cfn.get_waiter(attente).wait(StackName=pile, WaiterConfig={"Delay": 10, "MaxAttempts": 180})
    except WaiterError:
        evenements = cfn.describe_stack_events(StackName=pile)["StackEvents"]
        for e in evenements:
            if e["ResourceStatus"].endswith("FAILED"):
                print(f"   ECHEC {e['LogicalResourceId']} : {e.get('ResourceStatusReason', '')}")
        return 1
    sorties = cfn.describe_stacks(StackName=pile)["Stacks"][0].get("Outputs", [])
    print(f"   {pile} deployee en {time.time() - debut:.0f} s")
    for s in sorties:
        print(f"   sortie {s['OutputKey']} = {s['OutputValue']}")
    return 0


def main() -> int:
    parseur = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parseur.add_argument("template", type=Path)
    parseur.add_argument("parametres", type=Path)
    parseur.add_argument("--role-cfn", default=None, help="role d'execution CloudFormation")
    parseur.add_argument("--confirmer-remplacement", action="store_true")
    args = parseur.parse_args()
    return deployer(args.template, args.parametres, args.role_cfn, args.confirmer_remplacement)


if __name__ == "__main__":
    sys.exit(main())
