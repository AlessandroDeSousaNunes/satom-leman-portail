# Rapport final · Portail Léman Finance (équipe ADSN)

TP final DevSecOps · dépôt public `AlessandroDeSousaNunes/satom-leman-portail` · région eu-north-1 · 25.11.2026

## 1. Architecture

Le portail des portefeuilles (Flask, une image pour deux rôles, `web` et `api`) est déployé **uniquement par la pipeline** GitHub Actions. Elle s'authentifie à AWS par OIDC, sans clé, avec un rôle au moindre privilège. Les ressources passent par des jeux de modifications CloudFormation relus : tout remplacement ou toute suppression exige une confirmation explicite.

| Couche | Réalisation | Modèle |
|---|---|---|
| Réseau | VPC 10.10.0.0/16 sur 2 zones, sous-réseaux publics, privés, NAT et pare-feu, NACL, journaux de flux chiffrés KMS | 01, 02 |
| Sortie Internet | NAT dédiée ; Network Firewall prêt mais reporté (ADR 0006) | 03 |
| Interconnexion | peering puis Transit Gateway (3 tables), 2 VPN BGP IKEv2, Direct Connect Gateway (conception, ADR 0004) | 04 à 07 |
| Calcul | EKS 1.34 (secrets chiffrés KMS, journaux du plan de contrôle), 1 nœud t3.medium (ADR 0008), Pod Security *restricted*, NetworkPolicy à refus par défaut, conteneurs non root en lecture seule | 08, `k8s/` |
| Exposition | ALB créé par l'AWS Load Balancer Controller, joignable **seulement par CloudFront** (liste de préfixes) ; CloudFront avec OAC vers un S3 chiffré KMS pour `/static/*` ; WAF régional sur l'ALB (ADR 0007) | 11 |
| DNS | Zone publique (bascule PRIMARY/SECONDARY sur surveillance d'état), zone privée associée au VPC | 10 |
| Exploitation | Tableau de bord, 3 alarmes avec runbooks, SNS chiffré vers l'exploitant, X-Ray | 12 |

**Chaîne logicielle** : qualité (ruff, 21 tests, couverture 97,9 %, SonarQube Cloud), sécurité statique (cfn-lint, cfn-guard 8 règles, checkov, Semgrep, gitleaks, pip-audit), image (Trivy, SBOM CycloneDX, signature cosign sans clé, déploiement par digest), déploiement dev, tests dynamiques (ZAP, k6, Lighthouse), validation manuelle avant prod, vérifications post-déploiement.

## 2. Résultats des mesures

| Domaine | Indicateur | Mesure (25.11) | Seuil | Statut |
|---|---|---|---|---|
| Qualité | Quality gate SonarQube | Passed (0 problème sur le nouveau code) | Passed | ✅ |
| Qualité | Couverture | 97,9 % (21 tests) | ≥ 80 % | ✅ |
| Sécurité | Findings critiques IaC, SAST, SCA | 0 (checkov 188 contrôles Kubernetes, cfn-guard, Semgrep, Trivy) | 0 | ✅ |
| Sécurité | Secrets dans le dépôt | 0 (gitleaks) | 0 | ✅ |
| Sécurité | DAST ZAP baseline | 0 alerte, 66 contrôles passés | 0 *high* | ✅ |
| Performance | p95 / p99 sous charge (k6, 20 VU, 3 min, 2 passages) | 134 / 237 ms et 190 / 324 ms | < 500 ms / < 1 s | ✅ |
| Performance | Taux d'erreur sous charge | 0 % (0 sur 7 998 puis 0 sur 7 656 requêtes) | < 0,5 % | ✅ |
| Performance | Lighthouse (page d'accueil) | performance 100, accessibilité 100, bonnes pratiques 96, SEO 100 | ≥ 85 / ≥ 90 | ✅ |
| Performance | Taux de cache statique | 100 % (50 GET sur 50 servis en 200 depuis le cache) | > 80 % | ✅ |
| Connectivité | Résolution DNS | 23,7 ms en moyenne (max 25 ms) | < 100 ms | ✅ |
| Connectivité | Bascule DNS après panne simulée | 50 s vers la maintenance, retour en 40 s | < 60 s | ✅ |
| Connectivité | Peering, TGW, VPN, DX | trafic réel par sondes TCP ; 2 VPN en BGP, Direct Connect en conception | conformes | ✅ |
| Sécurité | WAF : limitation de débit par IP | 1er blocage 403 après 26 s d'envoi soutenu | blocage | ✅ |
| Sécurité | Accès direct à l'ALB | refusé (aucune réponse) | refusé | ✅ |
| Monitoring | Alerte 5xx de bout en bout | panne 14:29:30 → ALARM 14:33:52 → mail reçu 14:33 (4 min 22 s) ; OK notifié à 14:42 | < 5 min | ✅ |
| Fiabilité | RTO / RPO | voir section 2.1 | documentés | (exercice du sprint 13) |
| Sécurité | Score Security Hub | non mesuré : service non activé sur le compte partagé | ≥ 90 % | ⚠️ écart 3 |

### 2.1 Reprise après sinistre (sprint 13)

Suppression complète de `dev` depuis le dépôt (workflow `reprise`, confirmation écrite), puis recréation par la pipeline. Le **RPO est nul par conception** : l'application est sans état, la configuration et l'infrastructure sont dans Git, et l'image est signée et adressée par digest. Le RTO mesuré est consigné dans `docs/journal.md`.

## 3. Écarts par rapport au cahier des charges

1. **Région eu-north-1 au lieu d'eu-central-2** : la SCP de l'organisation interdit Zurich (ADR 0001, 0007).
2. **WAF régional sur l'ALB au lieu d'un WAF CloudFront, et DNSSEC non activé** : les deux exigent us-east-1, interdit au rôle de la pipeline par la SCP. Le WAF régional filtre tout le trafic, puisque l'ALB n'accepte que CloudFront (ADR 0007).
3. **Security Hub, GuardDuty, AWS Config** : services de niveau compte, non activés sur le compte partagé de la classe ; leur activation est demandée au formateur.
4. **Sprint 4 (Network Firewall) reporté** : un incident interne AWS bloque toutes les opérations Network Firewall du compte (ADR 0006).
5. **Un seul nœud EKS en dev** : le quota du compte est à 62/64 vCPU (ADR 0008).
6. **Domaine fictif `leman-finance.example`** : non délégable, sans certificat public. L'origine est jointe en HTTP derrière CloudFront, et la résolution est vérifiée sur les serveurs faisant autorité (ADR 0005).

## 4. Actions correctives (incidents réels de la pipeline)

| Constat | Correction | PR |
|---|---|---|
| Groupe de sécurité de l'ALB au-delà du quota (liste CloudFront de 52 entrées référencée deux fois) | une seule règle HTTP 80 depuis CloudFront | #31 |
| CloudFront en 504 : la NACL publique n'acceptait que 443 | règle NACL 80 (le SG limite à CloudFront) | #37 |
| Fichiers statiques en 403 : la clé KMS n'autorisait pas CloudFront (OAC) | déclaration limitée aux distributions du compte | #40 |
| Nœuds EKS refusés : rôle lié au service absent, création bloquée par la SCP | créé une fois par l'administrateur | — |
| Droits manquants découverts au déploiement (ECR, IAM, Secrets Manager) | ajout ciblé, jamais `*` sur l'écriture (checkov CKV_AWS_111) | #19, #36 |
| `verifier.sh` s'arrêtait en silence et la pipeline le croyait vert | correction et `pipefail` | #38 |
| Mesures trompeuses (HEAD en cache masquant un 403, WAF testé en rafale trop courte) | mesures en GET réels, envoi soutenu chronométré | #41 |
| SonarQube : note de sécurité C sur le nouveau code (action non épinglée, `pip` sans version) | action épinglée par SHA, plus de `pip` | #33 |
| Une capture publiée montrait le numéro de compte dans l'en-tête de la console | masque élargi, PR remplacée | #45 |

## 5. Risques acceptés

| Risque | Justification | Levée |
|---|---|---|
| Pas de redondance des nœuds EKS en dev | quota vCPU partagé ; la bascule DNS couvre la panne | relever le quota, ou en prod |
| Origine ALB en HTTP derrière CloudFront | domaine fictif, pas de certificat public ; ALB limité aux IP CloudFront | domaine réel avec certificat ACM |
| Pas de DNSSEC ni de WAF CloudFront | SCP de l'organisation | autorisation d'us-east-1 |
| Exemption de la limitation de débit pour les tests de charge | jeton secret dans Secrets Manager, masqué, uniquement pour cette règle | rotation du jeton |
| Pare-feu réseau absent | incident AWS | reprise du sprint 4 |

## 6. Gouvernance

Chaque changement passe par une pull request, protégée par 4 contrôles obligatoires, un historique linéaire et un relecteur pour la prod. Les décisions sont tracées dans 8 ADR, et le journal de projet porte les indicateurs DORA par sprint. Environ 180 captures, avec le numéro de compte masqué, sont publiées dans `docs/captures`. Les ressources facturées à l'heure (EKS, NAT, TGW, VPN) sont démontées à la fin de chaque séance.
