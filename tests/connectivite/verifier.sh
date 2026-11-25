#!/usr/bin/env bash
# Tests de connectivité du portail déployé : santé web et API, en-têtes de sécurité, temps de réponse.
set -euo pipefail
URL="${1:?URL du portail, ex. https://alb-dev...}"
echec=0

verifier() {
  local chemin="$1" attendu="$2"
  local code temps
  read -r code temps < <(curl -sk -o /dev/null -w '%{http_code} %{time_total}\n' "$URL$chemin")
  if [[ "$code" == "$attendu" ]]; then
    printf 'OK    %-28s %s en %ss\n' "$chemin" "$code" "$temps"
  else
    printf 'ECHEC %-28s %s (attendu %s)\n' "$chemin" "$code" "$attendu"
    echec=1
  fi
}

verifier /health 200
verifier / 200
verifier /api/health 200
verifier /api/portefeuilles 200
verifier /api/portefeuilles/PF-999 404

for entete in strict-transport-security x-content-type-options content-security-policy x-frame-options; do
  if curl -skI "$URL/" | grep -qi "^$entete:"; then
    echo "OK    en-tête $entete"
  else
    echo "ECHEC en-tête $entete absent"
    echec=1
  fi
done
exit "$echec"
