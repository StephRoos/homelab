#!/usr/bin/env bash
# Morning homelab check + crypto dead-man's-switch
# Cron: 0 7 * * * /home/steph/homelab/scripts/um880/homelab-morning.sh
#
# Ce script lance le diagnostic homelab habituel et ajoute une vérification
# de sécurité sur l'agent crypto : si un processus agent_trading_v2.py tourne
# en AGENT_MODE=live, on s'assure que la double barrière AGENT_LIVE_CONFIRM
# est bien présente. Sinon, on alerte immédiatement.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${HOME}/.config/homelab-diagnostic/env"

# -----------------------------------------------------------------------------
# Crypto dead-man's-switch
# -----------------------------------------------------------------------------

# Cherche un processus agent_trading_v2.py en cours.
CRYPTO_PID=$(pgrep -f "agent_trading_v2\.py" || true)
CRYPTO_ALERT=""

if [ -n "$CRYPTO_PID" ]; then
  # Récupère l'environnement du processus (lecture depuis /proc/PID/environ).
  CRYPTO_ENV="/proc/${CRYPTO_PID}/environ"
  if [ -r "$CRYPTO_ENV" ]; then
    AGENT_MODE=$(tr '\0' '\n' < "$CRYPTO_ENV" | grep '^AGENT_MODE=' | cut -d= -f2)
    AGENT_LIVE_CONFIRM=$(tr '\0' '\n' < "$CRYPTO_ENV" | grep '^AGENT_LIVE_CONFIRM=' | cut -d= -f2)

    if [ "$AGENT_MODE" = "live" ] && [ "$AGENT_LIVE_CONFIRM" != "OUI-ARGENT-REEL" ]; then
      CRYPTO_ALERT="ALERTE CRYPTO : processus agent_trading_v2.py en mode LIVE sans double barrière AGENT_LIVE_CONFIRM. PID ${CRYPTO_PID}"
    fi
  fi
fi

# Vérifie aussi qu'aucun cron/auto-lancement n'a laissé AGENT_MODE=live dans le .env
# sans confirmation (second filet).
CRYPTO_DIR="${HOME}/Projects/crypto"
if [ -f "${CRYPTO_DIR}/.env" ]; then
  ENV_MODE=$(grep '^AGENT_MODE=' "${CRYPTO_DIR}/.env" | cut -d= -f2 | tr -d '"' || true)
  ENV_CONFIRM=$(grep '^AGENT_LIVE_CONFIRM=' "${CRYPTO_DIR}/.env" | cut -d= -f2 | tr -d '"' || true)
  if [ "$ENV_MODE" = "live" ] && [ "$ENV_CONFIRM" != "OUI-ARGENT-REEL" ]; then
    CRYPTO_ALERT="ALERTE CRYPTO : .env en AGENT_MODE=live sans AGENT_LIVE_CONFIRM correcte."
  fi
fi

# -----------------------------------------------------------------------------
# Diagnostic homelab existant
# -----------------------------------------------------------------------------

if [ -x "${SCRIPT_DIR}/homelab-diagnostic.sh" ]; then
  "${SCRIPT_DIR}/homelab-diagnostic.sh"
  DIAG_EXIT=$?
else
  echo "homelab-diagnostic.sh introuvable" >&2
  DIAG_EXIT=1
fi

# -----------------------------------------------------------------------------
# Alerte Telegram si dead-man's-switch déclenché
# -----------------------------------------------------------------------------

if [ -n "$CRYPTO_ALERT" ] && [ -r "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  : "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN not set}"
  : "${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID not set}"

  curl -s --max-time 10 -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${CRYPTO_ALERT}" \
    --data-urlencode "disable_notification=false" >/dev/null 2>&1 || true
fi

exit "$DIAG_EXIT"
