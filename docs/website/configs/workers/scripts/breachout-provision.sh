#!/bin/bash
# Wordt via SSH forced-command aangeroepen door de webserver
set -euo pipefail
read -r cmd sid ids extra <<< "${SSH_ORIGINAL_COMMAND:-}"
[ -z "${extra:-}" ] || { echo "ongeldige opdracht"; exit 2; }
[[ "${sid:-}" =~ ^[A-Za-z0-9-]{8,64}$ ]] || { echo "ongeldig sessie-id"; exit 2; }
case "$cmd" in
  create)
    [[ "${ids:-}" =~ ^[a-z0-9-]+(,[a-z0-9-]+){0,19}$ ]] || { echo "ongeldige challenge-lijst"; exit 2; }
    exec /usr/local/bin/breachout-worker create "$sid" "$ids" ;;
  destroy)
    exec /usr/local/bin/breachout-worker destroy "$sid" ;;
  *) echo "gebruik: create <sessie-id> <id1,id2,...> | destroy <sessie-id>"; exit 2 ;;
esac
