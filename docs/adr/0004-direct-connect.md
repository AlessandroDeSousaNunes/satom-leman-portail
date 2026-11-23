# ADR 0004 · Direct Connect : voie principale et bascule vers le VPN

- **Statut** : accepté (conception, sans connexion physique)
- **Date** : 2026-11-23

## Contexte

Le sprint 8 demande une passerelle Direct Connect `dxgw-leman` (ASN 64513) associée à la Transit Gateway, avec des préfixes filtrés et sans route par défaut. Aucune connexion physique n'est commandée : pas de port, pas d'interface virtuelle, pas de mesure de débit.

## Décision

1. **Code** : `templates/07-direct-connect.yaml` crée la passerelle et son association à la TGW (types `AWS::DirectConnect::DirectConnectGateway` et `AWS::DirectConnect::DirectConnectGatewayAssociation`).
2. **Filtrage AWS vers les sites** : `AllowedPrefixesToDirectConnectGateway` = CIDR du VPC principal uniquement. Le VPC dev et toute route par défaut ne sont jamais annoncés.
3. **Filtrage des sites vers AWS** (sur les routeurs clients) : n'accepter que les préfixes des VPC du portail (`10.0.0.0/16`, pas de `0.0.0.0/0`), refuser tout le reste (prefix-list + route-map en entrée).
4. **Voie principale = Direct Connect, secours = VPN** :
   - côté sites : `local-preference 200` sur les routes reçues par Direct Connect, `100` sur celles du VPN ;
   - côté AWS : les routes apprises par Direct Connect sont préférées à celles du VPN pour un même préfixe (ordre de préférence de la TGW : statique, puis Direct Connect, puis VPN) ; les sites annoncent aussi un `AS-path` allongé (prepend ×3) sur le VPN.
5. **Bascule** : à la perte de la session BGP Direct Connect, les préfixes disparaissent et la TGW utilise les routes VPN restantes ; temps de bascule = temps de détection BGP (hold time 90 s, ou ~1 s avec BFD). La bascule a été démontrée sur la maquette GNS3 du module 8 (deux routeurs FRR, coupure de l'interface Direct Connect).

## Conséquences

- La passerelle Direct Connect n'est pas facturée sans interface virtuelle ; elle est créée seulement pendant les sessions (`AvecDirectConnect`).
- Pas de mesure de débit fictive : la mesure du sprint 8 est la présence de l'association, ses préfixes autorisés et l'attachement `direct-connect-gateway` visible sur la TGW.
- Écart accepté : pas de test de bascule de bout en bout sur AWS (aucun site réel). Propriétaire : ADSN. Revue : gate G2.
