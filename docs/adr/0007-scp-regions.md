# ADR 0007 · SCP de l'organisation : régions interdites, DNSSEC et WAF CloudFront

- **Statut** : accepté
- **Date** : 2026-11-24
- **Propriétaire** : ADSN
- **Date de revue** : si la SCP de l'organisation évolue

## Constat

Le compte de formation appartient à une organisation AWS dont une **politique de contrôle de service (SCP)** :

- interdit **eu-central-2 (Zurich)**, région demandée par le dossier de projet (complète l'ADR 0001) ;
- interdit **us-east-1** au rôle de la pipeline (`explicit deny in a service control policy` sur `cloudformation:GetTemplateSummary`), alors que le rôle de console de l'administrateur y a accès.

Deux exigences du TP reposent sur us-east-1 :

| Exigence | Pourquoi us-east-1 | Effet de la SCP |
|---|---|---|
| Sprint 10 : DNSSEC de la zone publique | Route 53 n'accepte qu'une clé KMS asymétrique en us-east-1 | clé impossible à créer par la pipeline |
| Sprint 11 : AWS WAF sur CloudFront | une WebACL de portée CLOUDFRONT n'existe qu'en us-east-1 | WebACL impossible à créer par la pipeline |

## Décision

- **WAF** : WebACL **régionale** associée à l'ALB d'origine (`templates/11-waf.yaml`), mêmes règles gérées AWS, et limitation de débit sur l'**IP du visiteur** (`FORWARDED_IP`, en-tête `X-Forwarded-For` posé par CloudFront). L'ALB n'acceptant que CloudFront, tout le trafic du portail passe par ce WAF.
- **DNSSEC** : non activé. Le code (`KeySigningKey`, `DNSSEC` dans `10-dns.yaml`) reste prêt et s'active en fournissant `CleDnssecArn`. Le domaine étant fictif et non délégué, aucune chaîne de confiance ne pourrait de toute façon être publiée chez un registre.
- Aucune ressource n'est créée à la main en us-east-1 pour contourner la SCP : ce serait contraire à la règle « rien n'est déployé à la main ».

## Conséquences

- checkov CKV_AWS_68 (WAF sur la distribution) : exception déclarée dans `11-cloudfront.yaml`, renvoi à cet ADR.
- Contrôle Security Hub équivalent : finding attendu sur la distribution, accepté par cet ADR.
- À lever si l'organisation autorise us-east-1 au rôle de déploiement : WebACL CLOUDFRONT et clé DNSSEC par la pipeline.
