# Runbook · alarme `portail-<env>-alb-5xx`

**Symptôme** : plus de 5 réponses 5xx des cibles en une minute ; e-mail SNS « ALARM ».

**Diagnostic**
1. Tableau de bord `portail-<env>-ADSN` : les 5xx viennent-elles des cibles (`HTTPCode_Target_5XX`) ou de l'ALB (`HTTPCode_ELB_5XX`) ?
2. `kubectl -n portail get pods` : redémarrages, `CrashLoopBackOff`, `OOMKilled` ?
3. `kubectl -n portail logs deploy/api --since=10m | grep '"statut": 5'` : journaux JSON, champ `requete_id` à suivre dans les traces X-Ray.
4. Dernier déploiement : `gh run list --workflow pipeline --limit 3`.

**Action corrective**
- Déploiement fautif : `kubectl -n portail rollout undo deploy/api` puis correctif par pull request.
- Pods à court de mémoire : augmenter `resources.limits` par pull request.
- Fin d'incident : l'alarme repasse en OK (e-mail SNS « OK ») ; noter l'heure dans `docs/journal.md` (MTTR).
