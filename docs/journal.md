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
| 2026-11-23 | S5 | Incident | VPC Reachability Analyzer renvoie une erreur interne AWS ; le script de mesure comptait l'échec comme « bloqué ». Corrigé (ECHEC signalé) ; mesure remplacée par des sondes TCP réelles (console série) |
| 2026-11-24 | S5 | Mesure | Trafic réel : web-01→app-01 8080 ouvert, 22 fermé ; dev-01→app-01 8080 ouvert par le peering, dev-01→web-01 22 fermé |
| 2026-11-24 | S6 | Réalisation | Bascule du peering vers la TGW (suppressions relues et confirmées), 3 tables séparées ; sondes réelles : dev-01→app-01 8080 ouvert par la TGW |
| 2026-11-24 | Mesures | Décision | Les captures de la console CloudShell se figent : workflow « mesures » à la demande (rôle OIDC en lecture), journaux archivés |
| 2026-11-24 | S7 | Incident | Pré-clé VPN non générée : droit secretsmanager:GetRandomPassword manquant au rôle d'exécution ; ajouté, limité aux secrets portail/* (PR #19) |
| 2026-11-24 | S7 | Mesure | 2 VPN BGP, IKEv2, AES-256, DH 20 ; tunnels DOWN (sites fictifs) donc alarmes TunnelState en ALARM : alarme prouvée |
| 2026-11-24 | Sécurité | Incident | Une correction écrivait le numéro de compte dans un workflow public : bloquée ; le numéro est lu à l'exécution et masqué |
| 2026-11-24 | S8 | Mesure | dxgw-leman (ASN 64513) associée à la TGW, seul 10.10.0.0/16 annoncé, 0 interface virtuelle (ADR 0004) |
| 2026-11-24 | S6–S8 | Réalisation | Fin de session : démontage en ordre inverse (Direct Connect, VPN, TGW) |
| 2026-11-24 | S9 | Incident | Deux échecs du cluster : ecr:CreateRepository puis iam:ListAttachedRolePolicies manquants au rôle d'exécution ; ajoutés (rôles portail uniquement) |
| 2026-11-24 | S9 | Décision | Image copiée de GHCR vers un ECR privé chiffré (même digest signé), lue par le rôle des nœuds |
| 2026-11-24 | S11 | Incident | La sécurité bloque la PR #26 : écriture IAM sans restriction (CKV_AWS_111) ; droits limités aux ressources du compte |
| 2026-11-24 | S11–S12 | Gouvernance | En synchronisant les pull requests empilées, la PR #27 (sprint 12) a été intégrée à la branche du sprint 11 : le sprint 12 est arrivé sur main par la PR #26, vérifiée par la pipeline complète. Écart de processus noté, pas d'impact sur le contenu |
| 2026-11-24 | S11 | Décision | ADR 0005 : écarts CloudFront acceptés temporairement (domaine fictif) |

## Indicateurs DORA

| Sprint | Fréquence de déploiement (dev / prod) | Délai commit → prod | Taux d'échec des changements | MTTR |
|---|---|---|---|---|
| G0 | 0 / 0 | — | — | — |
| S1–S3 | 2 / 0 (1 échec) | — | 1 sur 2 (50 %), corrigé par PR #10 | 25 min (échec 09:57 → dev déployé 10:22) |
| S5–S8 | 9 / 0 (2 échecs) | — | 2 sur 9 (22 %) : droits Secrets Manager, mesure VPN | 35 min (sprint 7 : échec 08:36 → VPN déployés 09:11) |

## Contrôles techniques par sprint

| Sprint | Qualité (SonarQube) | Sécurité (IaC, SAST, SCA, secrets) | Mesure | Gate |
|---|---|---|---|---|
| G0 | SonarQube à configurer | étapes 1 à 3 vertes, 2 vulnérabilités corrigées | — | dépôt, branche protégée, OIDC, budget : passé |
| S1–S3 | ruff, pytest 98 % | cfn-guard (8 règles), checkov, gitleaks verts | describe-subnets, routes, SG conformes | G1 en attente de SonarQube |
