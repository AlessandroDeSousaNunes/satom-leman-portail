# Journal de projet · portail Léman Finance (équipe ADSN)

## Entrées

| Date | Sprint / gate | Type | Description |
|---|---|---|---|
| 2026-11-23 | G0 | Réalisation | Dépôt public créé, arborescence, application, manifestes Kubernetes, templates 00 à 02, pipeline en 7 étapes |
| 2026-11-23 | G0 | Décision | ADR 0001 (région eu-north-1, dépôt personnel public), ADR 0002 (EKS), ADR 0003 (relecture et rôles IAM) |
| 2026-11-23 | G0 | Constat | La pipeline bloque deux vraies vulnérabilités : Flask 3.1.2 (PYSEC-2026-2151, pip-audit) et zlib (CVE-2026-85091, Trivy). Corrigées par Flask 3.1.3 et la mise à jour des paquets Debian |
| 2026-11-23 | G0 | Réalisation | Nettoyage des ressources manuelles du labo (modules 0 à 13) avant le TP final ; le pare-feu nfw-prod-leman-ADSN reste bloqué par une erreur interne AWS |
| 2026-11-23 | G0 | Réalisation | Pile portail-bootstrap : rôle GitHub Actions (OIDC, sans clé) et rôle d'exécution CloudFormation |
| 2026-11-23 | G0 | Incident | Premier déploiement refusé : GitHub émet le claim sub avec identifiants immuables. Diagnostic du jeton, condition du rôle corrigée (ADR 0003) |
| 2026-11-23 | S1–S3 | Incident | portail-dev-securite annulée : nom de groupe de sécurité en `sg-…` refusé par EC2. Correction + nouvelle règle cfn-guard (PR #10) |
| 2026-11-23 | S1–S3 | Réalisation | Piles dev réseau, sécurité et sortie Internet déployées par la pipeline ; mesures describe-subnets, routes et groupes de sécurité conformes ; mise en prod refusée (reportée au sprint 13) |

## Indicateurs DORA

| Sprint | Fréquence de déploiement (dev / prod) | Délai commit → prod | Taux d'échec des changements | MTTR |
|---|---|---|---|---|
| G0 | 0 / 0 | — | — | — |
| S1–S3 | 2 / 0 (1 échec) | — | 1 sur 2 (50 %), corrigé par PR #10 | 25 min (échec 09:57 → dev déployé 10:22) |

## Contrôles techniques par sprint

| Sprint | Qualité (SonarQube) | Sécurité (IaC, SAST, SCA, secrets) | Mesure | Gate |
|---|---|---|---|---|
| G0 | SonarQube à configurer | étapes 1 à 3 vertes, 2 vulnérabilités corrigées | — | dépôt, branche protégée, OIDC, budget : passé |
| S1–S3 | ruff, pytest 98 % | cfn-guard (8 règles), checkov, gitleaks verts | describe-subnets, routes, SG conformes | G1 en attente de SonarQube |
