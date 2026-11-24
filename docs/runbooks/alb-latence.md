# Runbook · alarme `portail-<env>-alb-latence-p95`

**Symptôme** : latence p95 de l'ALB au-dessus du SLO (500 ms) sur deux périodes de 5 minutes.

**Diagnostic**
1. Tableau de bord : la p99 suit-elle ? le nombre de requêtes a-t-il augmenté (charge) ?
2. `kubectl top pods -n portail` : saturation CPU (limite 250m) ?
3. X-Ray, groupe `portail-<env>-ADSN` : quel segment est lent (web, api) ?

**Action corrective**
- Charge : augmenter `replicas` des déploiements (pull request), vérifier l'autoscaling des nœuds.
- Requête lente identifiée : correctif applicatif, test de charge k6 avant fusion.
