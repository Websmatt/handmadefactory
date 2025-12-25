#!/usr/bin/env bash
set -euo pipefail

# ==== KONFIG DOPASUJ TYLKO TĘ LINIĘ (albo nadpisz COMPOSE_FILE przez env) ====
COMPOSE_FILE="${COMPOSE_FILE:-/home/administrator/docker-compose.yml}"  # ← PODMIEŃ na swoją ścieżkę
SERVICE="${SERVICE:-postgres}"
DB_USER="${DB_USER:-appsmith}"
SRC_DB_DEFAULT="${SRC_DB_DEFAULT:-loluli}"   # nazwa bazy w archiwum (źródłowa)
FIVE_DIR="${FIVE_DIR:-/var/backups/postgres/fivemin}"
TMP_DIR="${TMP_DIR:-/var/backups/postgres/tmp}"

export COMPOSE_FILE

usage() {
  cat <<'USAGE'
Użycie:
  restore_from_fivemin.sh latest [--db <cel_db>] [--skip-globals] [--no-prebackup]
  restore_from_fivemin.sh at <YYYY-MM-DD_HHMMSS> [--db <cel_db>] [--skip-globals] [--no-prebackup]
  restore_from_fivemin.sh files <globals.sql.zst|-> <loluli.tar.zst> [--db <cel_db>] [--skip-globals] [--no-prebackup]
  restore_from_fivemin.sh table <schema.tabela> [--at <TS>|--latest] [--db <cel_db>] [--no-prebackup]

Opis:
  latest                  – przywróć z najnowszego snapshotu z FIVE_DIR
  at <TS>                 – przywróć z konkretnego timestampu (np. 2025-09-29_191500)
  files g.sql.zst db.tar  – przywróć z podanych plików (globals możesz pominąć wpisując "-")
  table schema.tabela     – przywróć jedną tabelę (do istniejącej bazy)
Opcje:
  --db <cel_db>           – docelowa nazwa bazy (domyślnie: loluli)
  --skip-globals          – nie importuj globals (role/tablespaces)
  --no-prebackup          – nie rób pre-backupu bieżącego stanu
  --latest / --at <TS>    – dla trybu table: wybór archiwum (domyślnie --latest)
USAGE
}

need() { command -v "$1" >/dev/null 2>&1 || { echo "Brak polecenia: $1"; exit 1; }; }

find_latest_pair() {
  local g d
  g="$(ls -1t "$FIVE_DIR"/*_globals.sql.zst 2>/dev/null | head -1 || true)"
  d="$(ls -1t "$FIVE_DIR"/*_"$SRC_DB_DEFAULT".tar.zst 2>/dev/null | head -1 || true)"
  [[ -z "$d" ]] && { echo "Nie znaleziono żadnego *_${SRC_DB_DEFAULT}.tar.zst w $FIVE_DIR"; exit 1; }
  echo "$g|$d"
}

find_pair_by_ts() {
  local ts="$1"
  local g="$FIVE_DIR/${ts}_globals.sql.zst"
  local d="$FIVE_DIR/${ts}_${SRC_DB_DEFAULT}.tar.zst"
  [[ ! -f "$d" ]] && { echo "Brak pliku: $d"; exit 1; }
  # globals mogą być pominięte; jeśli brak – zwróć pusty komponent
  [[ -f "$g" ]] || g=""
  echo "$g|$d"
}

prebackup_now() {
  local db="$1"
  mkdir -p "$TMP_DIR"
  local out="$TMP_DIR/${db}_preRestore_$(date +%F_%H%M%S).tar"
  echo "[i] Pre-backup aktualnej bazy do: $out"
  docker compose exec -T "$SERVICE" pg_dump -U "$DB_USER" -d "$db" -F t > "$out" || {
    echo "[!] Ostrzeżenie: pre-backup nieudany (może baza nie istnieje?). Kontynuuję."
  }
}

terminate_sessions() {
  local db="$1"
  docker compose exec -T "$SERVICE" psql -U "$DB_USER" -d postgres -c \
    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${db}';" >/dev/null || true
}

drop_and_create_db() {
  local db="$1"
  docker compose exec -T "$SERVICE" psql -U "$DB_USER" -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS ${db};"
  docker compose exec -T "$SERVICE" psql -U "$DB_USER" -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${db};"
}

restore_globals() {
  local globals_file="$1"
  [[ -n "$globals_file" ]] || return 0
  echo "[i] Import globals: $globals_file"
  zstd -dc "$globals_file" | docker compose exec -T "$SERVICE" psql -U "$DB_USER" -d postgres || true
}

restore_db_tar() {
  local db="$1"
  local tar_file="$2"
  echo "[i] Restore bazy '${db}' z: $tar_file"
  zstd -dc "$tar_file" \
   | docker compose exec -T "$SERVICE" pg_restore -U "$DB_USER" -d "$db" --clean --if-exists
}

restore_one_table() {
  local db="$1"
  local table="$2"   # schema.table
  local tar_file="$3"
  echo "[i] Restore tabeli ${table} do bazy ${db} z: $tar_file"
  zstd -dc "$tar_file" \
   | docker compose exec -T "$SERVICE" pg_restore -U "$DB_USER" -d "$db" --clean --if-exists -t "$table"
}

# ===== main =====
[[ $# -lt 1 ]] && { usage; exit 1; }
need docker
need zstd

MODE="$1"; shift
TARGET_DB="$SRC_DB_DEFAULT"
SKIP_GLOBALS="no"
DO_PREBACKUP="yes"
TABLE_ARG=""
USE_TS=""
USE_LATEST="no"
GLOBALS_FILE=""
DB_TAR_FILE=""

# proste parsowanie opcji
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db) TARGET_DB="$2"; shift 2 ;;
    --skip-globals) SKIP_GLOBALS="yes"; shift ;;
    --no-prebackup) DO_PREBACKUP="yes"; DO_PREBACKUP="no"; shift ;;
    --at) USE_TS="$2"; shift 2 ;;
    --latest) USE_LATEST="yes"; shift ;;
    *) 
      if [[ "$MODE" == "at" && -z "${TS_SET:-}" ]]; then
        TS="$1"; TS_SET=1; shift
      elif [[ "$MODE" == "files" && -z "$GLOBALS_FILE" ]]; then
        GLOBALS_FILE="$1"; shift
      elif [[ "$MODE" == "files" && -z "$DB_TAR_FILE" ]]; then
        DB_TAR_FILE="$1"; shift
      elif [[ "$MODE" == "table" && -z "$TABLE_ARG" ]]; then
        TABLE_ARG="$1"; shift
      else
        echo "Nieznana opcja/argument: $1"; usage; exit 1
      fi
    ;;
  esac
done

case "$MODE" in
  latest)
    pair="$(find_latest_pair)"; GLOBALS="$(echo "$pair" | cut -d'|' -f1)"; DBTAR="$(echo "$pair" | cut -d'|' -f2)"
  ;;
  at)
    TS="${TS:-${USE_TS:-}}"
    [[ -z "$TS" ]] && { echo "Podaj timestamp: at <YYYY-MM-DD_HHMMSS>"; exit 1; }
    pair="$(find_pair_by_ts "$TS")"; GLOBALS="$(echo "$pair" | cut -d'|' -f1)"; DBTAR="$(echo "$pair" | cut -d'|' -f2)"
  ;;
  files)
    [[ "$GLOBALS_FILE" == "-" ]] && GLOBALS_FILE=""
    GLOBALS="$GLOBALS_FILE"; DBTAR="$DB_TAR_FILE"
    [[ -f "$DBTAR" ]] || { echo "Brak pliku bazy: $DBTAR"; exit 1; }
    [[ -n "$GLOBALS" && ! -f "$GLOBALS" ]] && { echo "Brak pliku globals: $GLOBALS"; exit 1; }
  ;;
  table)
    [[ -z "$TABLE_ARG" ]] && { echo "Podaj tabelę: table <schema.tabela>"; exit 1; }
    if [[ -n "$USE_TS" ]]; then
      pair="$(find_pair_by_ts "$USE_TS")"
    else
      pair="$(find_latest_pair)"
    fi
    GLOBALS=""  # niepotrzebne przy pojedynczej tabeli
    DBTAR="$(echo "$pair" | cut -d'|' -f2)"
  ;;
  *)
    usage; exit 1 ;;
esac

echo "[i] Cel DB: $TARGET_DB"
echo "[i] Plik bazy: ${DBTAR:-<none>}"
echo "[i] Plik globals: ${GLOBALS:-(pomijam)}"

# scenariusze
if [[ "$MODE" == "table" ]]; then
  [[ "$DO_PREBACKUP" == "yes" ]] && prebackup_now "$TARGET_DB"
  terminate_sessions "$TARGET_DB"
  restore_one_table "$TARGET_DB" "$TABLE_ARG" "$DBTAR"
  echo "[OK] Przywrócono tabelę ${TABLE_ARG} do bazy ${TARGET_DB}."
  exit 0
fi

# pełne odtworzenie bazy
[[ "$DO_PREBACKUP" == "yes" ]] && prebackup_now "$TARGET_DB"
terminate_sessions "$TARGET_DB"
drop_and_create_db "$TARGET_DB"
[[ "$SKIP_GLOBALS" == "yes" ]] || restore_globals "$GLOBALS"
restore_db_tar "$TARGET_DB" "$DBTAR"

echo "[OK] Przywrócono bazę '${TARGET_DB}'."
echo "     Weryfikacja (przykład): docker compose exec -T ${SERVICE} psql -U ${DB_USER} -d ${TARGET_DB} -c '\dt'"
