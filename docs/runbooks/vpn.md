# Runbook · alarmes `portail-<env>-vpn-<site>-tunnel`

**Symptôme** : `TunnelState` < 1 (au moins un tunnel du site tombé).

**Diagnostic**
1. `bash tests/connectivite/vpn.sh <env>` : état des deux tunnels, message (`IPSEC IS DOWN`), rattachement TGW.
2. Côté site : routeur joignable ? pré-clé identique (Secrets Manager `portail/<env>/vpn-pre-cles`) ? IKEv2, AES-256, DH 20 ?
3. Session BGP : ASN 65010 / 65020 côté site, 64512 côté AWS.

**Action corrective**
- Un tunnel sur deux : pas d'interruption (redondance), intervention planifiée côté site.
- Deux tunnels : bascule vers Direct Connect si disponible (ADR 0004), sinon escalade au fournisseur du site.
