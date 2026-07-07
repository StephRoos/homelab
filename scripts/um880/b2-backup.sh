#!/bin/bash
set -euo pipefail
LOG=/var/log/rclone-b2-backup.log
PG_DUMP_DIR=/mnt/nas/backups/pg
PG_CONTAINER=postgres-shared
PG_PASS_FILE=/home/steph/.secrets/postgres-shared.pass
IMMICH_DUMP_DIR=/mnt/nas/backups/immich-db
IMMICH_PG_CONTAINER=immich-postgres

echo "[$(date -Iseconds)] Starting B2 backup" >> "$LOG"

# Postgres dump (shared) avant sync B2
if docker ps --format '{{.Names}}' | grep -q "^${PG_CONTAINER}$"; then
  DUMP_FILE="${PG_DUMP_DIR}/pgdumpall-$(date +%Y%m%d-%H%M%S).sql.gz"
  echo "[$(date -Iseconds)] Dumping ${PG_CONTAINER} -> ${DUMP_FILE}" >> "$LOG"
  docker exec -e PGPASSWORD="$(cat "$PG_PASS_FILE")" "$PG_CONTAINER" \
    pg_dumpall -U admin | gzip > "$DUMP_FILE"
  # Garder les 7 derniers dumps localement
  ls -1t "${PG_DUMP_DIR}"/pgdumpall-*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm -f
  echo "[$(date -Iseconds)] Dump complete ($(du -h "$DUMP_FILE" | cut -f1))" >> "$LOG"
else
  echo "[$(date -Iseconds)] WARN ${PG_CONTAINER} not running, skipping pg dump" >> "$LOG"
fi

# Immich postgres dump avant sync B2 (albums, dates, visages, stacks)
if docker ps --format '{{.Names}}' | grep -q "^${IMMICH_PG_CONTAINER}$"; then
  IMMICH_DUMP_FILE="${IMMICH_DUMP_DIR}/immich-$(date +%Y%m%d-%H%M%S).sql.gz"
  echo "[$(date -Iseconds)] Dumping ${IMMICH_PG_CONTAINER} -> ${IMMICH_DUMP_FILE}" >> "$LOG"
  docker exec "$IMMICH_PG_CONTAINER" pg_dumpall --clean --if-exists -U immich | gzip > "$IMMICH_DUMP_FILE"
  # Garder les 7 derniers dumps localement
  ls -1t "${IMMICH_DUMP_DIR}"/immich-*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm -f
  echo "[$(date -Iseconds)] Immich dump complete ($(du -h "$IMMICH_DUMP_FILE" | cut -f1))" >> "$LOG"
else
  echo "[$(date -Iseconds)] WARN ${IMMICH_PG_CONTAINER} not running, skipping immich dump" >> "$LOG"
fi

rclone sync /mnt/nas/nextcloud b2:homelab-backup-anthemion/nextcloud --log-file="$LOG" --log-level INFO
rclone sync /mnt/nas/appdata   b2:homelab-backup-anthemion/appdata   --log-file="$LOG" --log-level INFO
rclone sync /mnt/nas/backups   b2:homelab-backup-anthemion/backups   --log-file="$LOG" --log-level INFO

# Immich: originaux uniquement (exclure les derivables regenerables: thumbs, encoded-video)
rclone sync /mnt/nas/immich/library b2:homelab-backup-anthemion/immich-library \
  --exclude 'thumbs/**' --exclude 'encoded-video/**' \
  --log-file="$LOG" --log-level INFO

echo "[$(date -Iseconds)] B2 backup complete" >> "$LOG"
