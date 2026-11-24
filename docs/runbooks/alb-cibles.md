# Runbook · alarme `portail-<env>-alb-cibles-non-saines`

**Symptôme** : au moins une cible non saine derrière l'ALB pendant 2 minutes ; la bascule DNS Route 53 peut se déclencher si toutes le sont.

**Diagnostic**
1. `aws elbv2 describe-target-health` sur les groupes cibles de l'ALB : raison (`Target.Timeout`, `Target.ResponseCodeMismatch`).
2. `kubectl -n portail get pods -o wide` et sondes `readinessProbe` (`/health`, `/api/health`).
3. NetworkPolicy : l'ALB (10.0.0.0/8) atteint-il les pods sur 8080 ?

**Action corrective**
- Pods non prêts : `kubectl -n portail rollout restart deploy/<web|api>`.
- Règle réseau : corriger la NetworkPolicy ou le groupe de sécurité par pull request.
