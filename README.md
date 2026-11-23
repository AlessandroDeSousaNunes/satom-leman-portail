# satom-leman-portail

Portail des portefeuilles du **Groupe Léman Finance SA** (client fictif), reconstruit en infrastructure as code avec une chaîne DevSecOps complète. TP final du cours réseau AWS · Satom IT & Learning Solutions · équipe **ADSN**.

[![pipeline](https://github.com/AlessandroDeSousaNunes/satom-leman-portail/actions/workflows/pipeline.yml/badge.svg)](https://github.com/AlessandroDeSousaNunes/satom-leman-portail/actions/workflows/pipeline.yml)

## Preuves

Toutes les étapes sont capturées, sprint par sprint : [docs/captures](docs/captures/README.md).

## Architecture

| Couche | Technologie |
|---|---|
| Réseau, sécurité, connectivité | AWS CloudFormation (`templates/`), une pile par domaine et par environnement |
| Application | Python 3.12 / Flask, une image pour deux services (`web`, `api`) |
| Exécution | Kubernetes (Amazon EKS), manifestes Kustomize (`k8s/`), ALB créé par l'AWS Load Balancer Controller |
| Chaîne DevSecOps | GitHub Actions (`.github/workflows/pipeline.yml`), authentification AWS par OIDC |

## Arborescence

```
templates/   un YAML par domaine (00 bootstrap, 01 réseau, 02 sécurité, ...)
parameters/  dev.json, prod.json (aucun secret)
policies/    règles cfn-guard
app/         code applicatif et dépendances
k8s/         manifestes Kubernetes (base + overlays dev et prod)
tests/       unitaires, connectivité, charge (k6), DAST (ZAP)
scripts/     déploiement par change set, contrôles de la pipeline
sbom/        inventaires CycloneDX produits par la pipeline
docs/        journal, ADR, rapports, procédures
```

## Pipeline (7 étapes)

1. **Qualité** : cfn-lint, ruff, pytest (couverture ≥ 80 %), SonarQube Cloud (quality gate)
2. **Sécurité statique** : cfn-guard, checkov, Semgrep, gitleaks, pip-audit, Trivy, contrôle des CIDR
3. **Construction** : image Docker, scan Trivy, SBOM CycloneDX (Syft), signature cosign
4. **Déploiement dev** : piles par jeu de modifications (aucune suppression ou remplacement non confirmé), manifestes Kubernetes au digest signé
5. **Tests dynamiques** : connectivité, OWASP ZAP baseline, k6 (runner auto-hébergé dans le VPC)
6. **Validation manuelle**, puis prod
7. **Post-déploiement** : dérive, alarmes, conformité

## Commandes utiles

```bash
pytest                                   # tests unitaires et couverture
cfn-lint templates/*.yaml                # templates
checkov -d templates --framework cloudformation
python scripts/verifier_cidr.py          # chevauchement des réseaux
python scripts/deployer.py templates/01-reseau.yaml parameters/dev.json
```

## Gouvernance

- Aucun commit direct sur `main` : chaque sprint passe par une pull request et la pipeline.
- Messages au format Conventional Commits.
- Décisions d'architecture dans [`docs/adr/`](docs/adr/), suivi et indicateurs DORA dans [`docs/journal.md`](docs/journal.md).
