# ADR 0002 · Exécution de l'application sur Kubernetes (EKS)

- **Statut** : proposé (en attente de l'accord du formateur sur le coût et le quota vCPU)
- **Date** : 2026-11-23

## Contexte

Les modules précédents faisaient tourner web-01 et app-01 sur deux instances EC2. Le TP final exige une image de conteneur scannée et signée, et l'équipe veut exécuter le portail sur Kubernetes.

## Décision

- Une seule image (`ghcr.io/alessandrodesousanunes/satom-leman-portail`), deux déploiements Kubernetes : `web` et `api` (variable `SERVICE`).
- Cluster **Amazon EKS** dans les sous-réseaux privés, nœuds gérés t3.small, ALB créé par l'**AWS Load Balancer Controller** à partir de l'Ingress (écouteur HTTPS 443, règle `/api/*`).
- Les groupes de sécurité sg-web / sg-app des modules précédents sont complétés par des **NetworkPolicy** (refus par défaut, api joignable seulement depuis web et l'ALB).
- Profil **Pod Security restricted**, conteneurs non root, système de fichiers en lecture seule, limites CPU et mémoire.
- Le déploiement référence l'image **par digest**, uniquement après signature cosign.

## Conséquences

- Coût : plan de contrôle EKS ≈ 0,10 $/h plus les nœuds. Le cluster est supprimé à la fin de chaque session et recréé par la pipeline (preuve de reproductibilité, sprint 13).
- Le quota de 48 vCPU du compte partagé est déjà atteint : une demande de place est nécessaire avant de créer les nœuds.
- Alternative si EKS est refusé : k3s sur une instance EC2 unique, avec les mêmes manifestes.
