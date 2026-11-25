# ADR 0008 · Quota vCPU du compte partagé : un seul nœud EKS en dev

- **Statut** : accepté
- **Date** : 2026-11-25
- **Propriétaire** : ADSN
- **Date de revue** : si le quota du compte est relevé, ou avant tout déploiement prod

## Constat

Le compte de formation est partagé par toute la classe. Mesure du 25.11 (CloudShell, lecture seule) :
quota « Running On-Demand Standard instances » de **64 vCPU**, dont **62 déjà utilisés**. Les deux nœuds
t3.small prévus par l'ADR 0002 demandent 4 vCPU : la création du groupe de nœuds échouerait.

## Décision

- dev : **un seul nœud géré t3.medium** (2 vCPU, 4 Go). Le t3.small (2 Go, 11 pods par nœud) est trop juste
  pour le contrôleur ALB, CoreDNS, l'agent Pod Identity et les 4 pods du portail.
- Paramètre `NombreNoeuds` (défaut 2, prod inchangée) ; `ScalingConfig` min = souhaité = max, pour ne jamais
  dépasser le quota.
- Les contraintes de répartition des pods restent en `ScheduleAnyway` : les 2 réplicas de web et d'api
  tournent sur le même nœud, les PodDisruptionBudget restent actifs.
- Le cluster est supprimé dès la fin des mesures de la session : il occupe les 2 derniers vCPU de la classe.

## Risque accepté

Pas de redondance des nœuds sur deux zones en dev : une panne du nœud ou de sa zone rend le portail
indisponible jusqu'au remplacement automatique du nœud (quelques minutes). La bascule DNS du sprint 10 vers
la page de maintenance couvre ce cas. À lever en relevant le quota (demande Service Quotas) ou en prod.
