# ADR 0005 · CloudFront : écarts de sécurité acceptés temporairement

- **Statut** : accepté (dérogation temporaire, section 3.2 du TP)
- **Date** : 2026-11-24
- **Propriétaire** : ADSN
- **Date de revue** : 2026-12-04, ou dès qu'un vrai nom de domaine est disponible

## Contexte

Le domaine `leman-finance.example` est fictif (réservé par la RFC 2606) : aucun certificat public ACM ne peut être validé pour lui. L'ALB du sprint 9 porte donc un certificat auto-signé, que CloudFront refuse comme origine HTTPS.

checkov signale trois écarts sur `templates/11-cloudfront.yaml`.

## Décision et risques acceptés

| Contrôle | Écart | Risque | Mesure compensatoire |
|---|---|---|---|
| CKV2_AWS_72 | CloudFront joint l'ALB en HTTP (port 80) | trafic en clair entre CloudFront et l'ALB, sur le réseau AWS | l'ALB n'accepte que la liste de préfixes gérée `com.amazonaws.global.cloudfront.origin-facing` ; le visiteur est toujours en HTTPS (redirection) ; aucune donnée réelle |
| CKV_AWS_174 | certificat CloudFront par défaut, TLS minimal imposé par AWS | négociation TLS 1.0/1.1 possible côté visiteur | en-têtes de sécurité (HSTS), WAF ; un certificat ACM en us-east-1 lève l'écart dès qu'un vrai domaine existe |
| CKV_AWS_86 / CKV_AWS_18 | pas de journaux d'accès CloudFront ni S3 | traçabilité réduite des accès | métriques CloudWatch de la distribution, journaux du WAF (chiffrés KMS), journaux de flux VPC |

Ces exceptions sont déclarées dans le template (métadonnées `checkov.skip`) avec un renvoi à cet ADR : la pipeline reste bloquante pour tout autre écart.

## Conséquences

- Avec un vrai domaine : certificat ACM public en us-east-1 pour CloudFront, certificat ACM public sur l'ALB, origine en `https-only`, journaux d'accès standard activés ; les trois exceptions sont alors supprimées.
