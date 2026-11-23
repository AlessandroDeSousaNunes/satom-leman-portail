# ADR 0001 · Région AWS et emplacement du dépôt

- **Statut** : accepté
- **Date** : 2026-11-23
- **Décideur** : Alessandro De Sousa Nunes (équipe ADSN)

## Contexte

Le dossier de projet demande la région **eu-central-2 (Zurich)** et un dépôt dans l'organisation GitHub `Morrad-Satom-IT`. Pendant les modules 0 à 13, toute l'infrastructure a été construite en **eu-north-1 (Stockholm)**, région du compte de formation partagé. `Morrad-Satom-IT` est un compte personnel GitHub, pas une organisation.

## Décision

- Région par défaut : **eu-north-1**, paramétrable par la variable de dépôt `AWS_REGION`. Aucun nom de région n'est écrit en dur dans les templates.
- Dépôt **public** sur le compte personnel `AlessandroDeSousaNunes/satom-leman-portail`.

## Conséquences

- Les résultats restent comparables aux modules précédents (mêmes quotas, même compte).
- Passer en eu-central-2 se fait en changeant une variable : les templates utilisent `!GetAZs` et des paramètres SSM.
- Le dépôt public permet SonarQube Cloud gratuit et des minutes GitHub Actions illimitées. Aucun secret n'y est stocké : gitleaks le vérifie à chaque exécution, les ARN des rôles (qui contiennent l'identifiant du compte AWS) sont des secrets du dépôt.
- **Risque accepté** : écart à la région imposée par la nLPD (données en Suède, dans l'UE et non en Suisse). Acceptable pour un client fictif sans données réelles ; à revoir avant toute donnée réelle. Propriétaire : ADSN. Revue : fin du sprint 13.
