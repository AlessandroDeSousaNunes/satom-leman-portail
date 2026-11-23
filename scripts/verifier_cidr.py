"""Contrôle de la pipeline (sprint 5) : aucun chevauchement de CIDR entre les réseaux du projet.

Compare les VPC de chaque environnement (parameters/*.json) et les réseaux des sites distants.
Code de sortie 1 en cas de chevauchement.
"""

from __future__ import annotations

import ipaddress
import json
import sys
from itertools import combinations
from pathlib import Path

SITES = {
    "site-geneve (VPN)": "172.16.0.0/16",
    "site-lausanne (VPN)": "172.17.0.0/16",
}


def reseaux(dossier: Path = Path("parameters")) -> dict[str, ipaddress.IPv4Network]:
    resultat = {nom: ipaddress.ip_network(cidr) for nom, cidr in SITES.items()}
    for fichier in sorted(dossier.glob("*.json")):
        valeurs = json.loads(fichier.read_text(encoding="utf-8"))
        env = valeurs["Environnement"]
        for cle in ("CidrVpc", "CidrVpcDev"):
            if cle in valeurs:
                resultat[f"{env}:{cle}"] = ipaddress.ip_network(valeurs[cle])
    return resultat


def chevauchements(res: dict[str, ipaddress.IPv4Network]) -> list[str]:
    paires = combinations(res, 2)
    return [f"{a} {res[a]} chevauche {b} {res[b]}" for a, b in paires if res[a].overlaps(res[b])]


def main() -> int:
    res = reseaux()
    for nom, net in res.items():
        print(f"{nom:<24} {net}")
    erreurs = chevauchements(res)
    for e in erreurs:
        print(f"ERREUR : {e}")
    print("OK : aucun chevauchement" if not erreurs else f"{len(erreurs)} chevauchement(s)")
    return 1 if erreurs else 0


if __name__ == "__main__":
    sys.exit(main())
