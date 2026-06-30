#!/usr/bin/env bash
# Homelab diagnostic — pushes a status summary to Telegram @anthemion_assistant_bot.
# Cron at 07:00 and 20:00.
#
# Behaviour (option A from 2026-05-15) :
#  - Always writes the full report to /var/log/homelab-diagnostic/latest.md
#  - If verdict = OK    : sends a brief one-liner to Telegram
#  - If verdict = DEGRADED : sends the full detailed report to Telegram
#  - On demand : the user replies "diag" in the bot chat, claude-bot reads
#    the latest report file and returns it.

set -uo pipefail

ENV_FILE="${HOME}/.config/homelab-diagnostic/env"
if [ ! -r "$ENV_FILE" ]; then
  echo "Missing env file: $ENV_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"
: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN not set}"
: "${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID not set}"

REPORT_FILE="/var/log/homelab-diagnostic/latest.md"

# Helpers -----------------------------------------------------------------

read_temp() {
  local path=$1
  [ -r "$path" ] && awk '{printf "%.0f", $1/1000}' "$path" || echo "n/a"
}

container_status() {
  local pattern=$1
  local label=$2
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -Eq "$pattern"; then
    echo "✓ ${label}"
  else
    echo "✗ ${label} DOWN"
    DEGRADED=1
  fi
}

systemd_status() {
  local unit=$1
  local label=$2
  local state
  state=$(systemctl is-active "$unit" 2>/dev/null || echo "inactive")
  if [ "$state" = "active" ]; then
    echo "✓ ${label}"
  else
    echo "✗ ${label} ($state)"
    DEGRADED=1
  fi
}

DEGRADED=0

# Collect (idem version précédente) -------------------------------------

NOW=$(date '+%Y-%m-%d %H:%M')
HOSTNAME=$(hostname)
UPTIME=$(uptime -p | sed 's/^up //')
LOAD=$(awk '{print $1", "$2", "$3}' /proc/loadavg)
RAM=$(free -h --si | awk '/^Mem:/ {print $3 " / " $2}')
DISK_ROOT=$(df -h --output=used,size,pcent / | tail -1 | awk '{print $1 " / " $2 " (" $3 ")"}')
DISK_PCT=$(df -h / | tail -1 | awk '{print $5}' | tr -d "%")
[ "${DISK_PCT:-0}" -gt 85 ] && DEGRADED=1

T_CPU=$(read_temp /sys/class/hwmon/hwmon3/temp1_input)
T_NVME=$(read_temp /sys/class/hwmon/hwmon2/temp1_input)
T_NVME_MAX=$(read_temp /sys/class/hwmon/hwmon2/temp3_input)
T_GPU=$(read_temp /sys/class/hwmon/hwmon5/temp1_input)
T_RAM=$(read_temp /sys/class/hwmon/hwmon4/temp1_input)
T_NET=$(read_temp /sys/class/hwmon/hwmon1/temp1_input)

# Seuils température — au-delà → DÉGRADÉ et trace dans TEMP_ALERTS
TEMP_ALERTS=""
check_temp() {
  local value=$1
  local threshold=$2
  local label=$3
  if [ "$value" != "n/a" ] && [ "${value:-0}" -gt "$threshold" ]; then
    DEGRADED=1
    TEMP_ALERTS+="• ${label}: ${value}°C (seuil ${threshold}°C)
"
  fi
}
check_temp "$T_CPU"      80 "CPU (k10temp)"
check_temp "$T_GPU"      80 "GPU AMD"
check_temp "$T_NVME"     80 "NVMe (composite)"
check_temp "$T_RAM"      70 "RAM SPD"
check_temp "$T_NET"      80 "Ethernet r8169"

LADTC_APP=$(container_status '^app-kmpuu' "LADTC app")
LADTC_DB=$(container_status '^db-kmpuu' "LADTC db")
NEXTCLOUD=$(container_status '^nextcloud-aio-nextcloud$' "Nextcloud")
COLLABORA=$(container_status '^nextcloud-aio-collabora$' "Collabora")
COOLIFY=$(container_status '^coolify$' "Coolify")
CLAUDE_BOT=$(systemd_status claude-bot.service "claude-bot")
SYNC_BOT=$(systemd_status syncthing@claude-bot.service "syncthing@claude-bot")

ups_raw="$(upsc eaton@localhost 2>/dev/null || true)"
UPS_STATUS=$(awk -F": " '/^ups.status:/{print $2}' <<<"$ups_raw")
UPS_CHARGE=$(awk -F": " '/^battery.charge:/{print $2}' <<<"$ups_raw")
UPS_VOLTAGE=$(awk -F": " '/^input.voltage:/{print $2}' <<<"$ups_raw")
[ -z "$UPS_STATUS" ]  && UPS_STATUS="?"
[ -z "$UPS_CHARGE" ]  && UPS_CHARGE="?"
[ -z "$UPS_VOLTAGE" ] && UPS_VOLTAGE="?"
[ "$UPS_STATUS" != "OL" ] && DEGRADED=1
[[ "$UPS_CHARGE" =~ ^[0-9]+$ ]] && [ "$UPS_CHARGE" -lt 95 ] && DEGRADED=1

B2_LOG="/var/log/rclone-b2-backup.log"
B2_COMPLETE="non"
B2_AGE_H="?"
if [ -r "$B2_LOG" ]; then
  b2_line=$(grep -E "B2 backup complete" "$B2_LOG" 2>/dev/null | tail -n 1)
  if [ -n "$b2_line" ]; then
    B2_COMPLETE="oui"
    b2_ts=$(grep -oE "\[[^]]+\]" <<<"$b2_line" | head -n 1 | tr -d "[]")
    if [ -n "$b2_ts" ]; then
      b2_epoch=$(date -d "$b2_ts" +%s 2>/dev/null || echo 0)
      if [ "$b2_epoch" -gt 0 ]; then
        now_epoch=$(date +%s)
        B2_AGE_H=$(( (now_epoch - b2_epoch) / 3600 ))
      fi
    fi
  fi
fi
[ "$B2_COMPLETE" != "oui" ] && DEGRADED=1
[[ "$B2_AGE_H" =~ ^[0-9]+$ ]] && [ "$B2_AGE_H" -gt 36 ] && DEGRADED=1

FB_COUNT="?"
if command -v fail2ban-client >/dev/null; then
  fb_status=$(sudo -n fail2ban-client status sshd 2>/dev/null || true)
  c=$(grep -E "Currently banned" <<<"$fb_status" | grep -oE "[0-9]+$" || true)
  [ -n "$c" ] && FB_COUNT="$c"
fi
[[ "$FB_COUNT" =~ ^[0-9]+$ ]] && [ "$FB_COUNT" -gt 20 ] && DEGRADED=1

url_names=(coolify uptime cloud)
url_targets=(https://coolify.anthemion.dev https://uptime.anthemion.dev https://cloud.anthemion.dev)
URL_LINES=""
for i in "${!url_names[@]}"; do
  name="${url_names[$i]}"
  target="${url_targets[$i]}"
  result=$(curl -sS -o /dev/null -w "%{http_code} %{time_total}" --max-time 5 "$target" 2>/dev/null || echo "ERR 0")
  code="${result%% *}"
  time_s="${result##* }"
  URL_LINES+=$'\n'"• ${name}: ${code} (${time_s}s)"
  [[ ! "$code" =~ ^(200|301|302|401)$ ]] && DEGRADED=1
done

NAS_DATA=$(ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no Steph@192.168.129.21 '
  T_SDA=$(sudo -n smartctl -A /dev/sda -d sntrealtek 2>/dev/null | awk "/^Temperature:/ {print \$2}")
  T_SDB=$(sudo -n smartctl -A /dev/sdb 2>/dev/null | awk "/Temperature_Celsius/ {print \$10}")
  T_SDC=$(sudo -n smartctl -A /dev/sdc 2>/dev/null | awk "/Temperature_Celsius/ {print \$10}")
  V1=$(df -h /volume1 2>/dev/null | tail -1 | awk "{print \$3 \" / \" \$2 \" (\" \$5 \")\"}")
  UP=$(uptime -p 2>/dev/null | sed "s/^up //")
  echo "${T_SDA}|${T_SDB}|${T_SDC}|${V1}|${UP}"
' 2>/dev/null || echo "||||NAS unreachable")
IFS='|' read -r NAS_SDA NAS_SDB NAS_SDC NAS_V1 NAS_UP <<< "$NAS_DATA"
[ -z "$NAS_SDA" ] && [ -z "$NAS_SDB" ] && [ -z "$NAS_SDC" ] && DEGRADED=1

# NAS disk temperature thresholds (Seagate ST4000VN006 rated 65°C; alerte à 55°C)
check_temp "$NAS_SDA" 65 "NAS sda (USB NVMe)"
check_temp "$NAS_SDB" 55 "NAS sdb (HDD)"
check_temp "$NAS_SDC" 55 "NAS sdc (HDD)"

# Verdict + reasons (compact pour le brief)
if [ "$DEGRADED" -eq 0 ]; then
  VERDICT="OK"
else
  VERDICT="DÉGRADÉ"
fi

# Full report (toujours sauvegardé) -------------------------------------

FULL="<b>homelab ${VERDICT} — ${NOW}</b>${TEMP_ALERTS:+

<b>Alarmes température</b>
${TEMP_ALERTS}}

<b>UM880 (${HOSTNAME})</b>
• Uptime: ${UPTIME}
• Load: ${LOAD}
• RAM: ${RAM}
• Disque /: ${DISK_ROOT}

<b>Températures UM880</b>
• CPU (k10temp): ${T_CPU}°C
• NVMe composite: ${T_NVME}°C (max sensor: ${T_NVME_MAX}°C)
• GPU AMD: ${T_GPU}°C
• RAM (SPD): ${T_RAM}°C
• Ethernet (r8169): ${T_NET}°C

<b>Services</b>
${LADTC_APP}
${LADTC_DB}
${NEXTCLOUD}
${COLLABORA}
${COOLIFY}
${CLAUDE_BOT}
${SYNC_BOT}

<b>UPS Eaton</b>
• Status: ${UPS_STATUS}
• Batterie: ${UPS_CHARGE}%
• Voltage entrée: ${UPS_VOLTAGE} V

<b>Sauvegarde B2</b>
• Dernière sauvegarde: ${B2_COMPLETE} (il y a ${B2_AGE_H} h)

<b>fail2ban SSH</b>
• Bans actifs: ${FB_COUNT}

<b>URLs publiques (Cloudflare)</b>${URL_LINES}

<b>NAS Ugreen (192.168.129.21)</b>
• Uptime: ${NAS_UP:-n/a}
• Volume1: ${NAS_V1:-n/a}
• Disque sda (USB NVMe): ${NAS_SDA:-n/a}°C
• Disque sdb (HDD 4To): ${NAS_SDB:-n/a}°C
• Disque sdc (HDD 4To): ${NAS_SDC:-n/a}°C"

# Write report file
mkdir -p "$(dirname "$REPORT_FILE")"
echo "$FULL" > "$REPORT_FILE"
chmod 644 "$REPORT_FILE"

# Decide what to send -----------------------------------------------------

if [ "$DEGRADED" -eq 0 ]; then
  MSG="<b>homelab OK</b> — ${NOW}
↳ envoyer <code>diag</code> au bot pour le détail"
else
  MSG="$FULL"
fi

# Send via Telegram ------------------------------------------------------

RESPONSE=$(curl -s --max-time 10 -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=${MSG}" \
  --data-urlencode "parse_mode=HTML" \
  --data-urlencode "disable_notification=true" || true)

if echo "$RESPONSE" | grep -q '"ok":true'; then
  echo "Telegram OK ($VERDICT)"
else
  echo "Telegram FAILED: $RESPONSE" >&2
  exit 1
fi
