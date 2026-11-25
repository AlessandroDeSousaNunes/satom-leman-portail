# ADR 0006 · Sprint 4 (Network Firewall) : déploiement reporté

- **Statut** : accepté (report temporaire)
- **Date** : 2026-11-24
- **Propriétaire** : ADSN
- **Date de revue** : dès que le formateur confirme le retour à la normale du service

## Contexte

Le template `03-sortie-internet.yaml` contient le pare-feu du sprint 4 : sous-réseau `sub-fw-1a`, politique stateful avec liste de domaines autorisés, journaux FLOW et ALERT chiffrés, routes privé → pare-feu → NAT et retour NAT → pare-feu. Il est validé par cfn-lint, cfn-guard et checkov et s'active par `AvecPareFeu=true`.

Depuis le 23.11, AWS Network Firewall renvoie `InternalServerError` sur le compte de formation : le pare-feu du labo `nfw-prod-leman-ADSN` ne peut pas être supprimé (CLI et console, routes et journalisation déjà retirées), et les pare-feu de trois autres équipes restent en « Synchronisation en cours ». Reachability Analyzer a renvoyé la même famille d'erreur.

## Décision

- Ne pas créer de nouveau pare-feu tant que l'incident n'est pas résolu : il risquerait de rester lui aussi impossible à supprimer (≈ 0,40 $/h).
- Signaler l'incident au formateur (preuves : captures `lab-05` à `lab-07`).
- Dès le retour à la normale : `AvecNat=true`, `AvecPareFeu=true` dans `parameters/dev.json`, puis mesures du sprint 4 (domaine autorisé : `pypi.org` passe ; domaine non autorisé : `example.org` bloqué et consigné dans `/portail/dev/pare-feu/alertes`).

## Conséquences

- Gate G2 : le sprint 4 est le seul sprint non mesuré ; les sprints 5 à 8 sont mesurés.
- Le code est prêt : le report ne demande aucune modification du dépôt, seulement deux paramètres.
