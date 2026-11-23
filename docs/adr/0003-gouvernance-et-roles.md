# ADR 0003 · Relecture, roles IAM et deploiement

- **Statut** : accepté
- **Date** : 2026-11-23

## Contexte

Le TP demande une relecture de chaque pull request par un autre membre, une authentification OIDC et un rôle de déploiement au moindre privilège. L'équipe ADSN compte une seule personne.

## Décision

- `main` est protégée : pas de push direct, pull request obligatoire, pipeline (étapes 1 à 3) verte obligatoire avant fusion.
- **Dérogation** : la relecture par un autre membre est remplacée par la relecture du formateur sur les pull requests et par l'approbation manuelle de l'environnement `prod` (étape 6). Propriétaire : ADSN. Revue : chaque gate.
- Deux rôles IAM, créés une seule fois par la pile `portail-bootstrap` :
  - `role-gha-portail-ADSN`, pris par GitHub Actions via OIDC, limité aux piles `portail-*` et à la transmission du rôle d'exécution, et restreint à la branche `main` et aux environnements `dev` et `prod` du dépôt ;
  - `role-cfn-portail-ADSN`, utilisé par CloudFormation pour créer l'infrastructure, limité à la région et aux rôles IAM nommés `*portail*`.
- Chaque mise à jour de pile passe par un jeu de modifications ; `scripts/deployer.py` refuse toute suppression ou tout remplacement non confirmé.

## Conséquences

- Aucune clé d'accès longue durée : rien à faire tourner, rien à fuiter.
- Une pull request d'un fork ne peut pas prendre le rôle (condition `sub` sur le dépôt et la branche).
- **Constat du 23.11** : GitHub émet désormais le claim `sub` avec les identifiants immuables du propriétaire et du dépôt (`repo:AlessandroDeSousaNunes@260914278/satom-leman-portail@1468484199:environment:dev`). Le premier déploiement a été refusé (`Not authorized to perform sts:AssumeRoleWithWebIdentity`) ; le diagnostic du jeton a montré ce format, la condition du rôle l'accepte maintenant. Avantage : un dépôt supprimé puis recréé sous le même nom ne peut pas prendre le rôle.
