#!/usr/bin/env bash
set -euo pipefail

# Domyślne ustawienia
DIR="/var/backups/postgres/fivemin"
FROM_RAW=""
TO_RAW=""
SINCE_RAW=""
NAME_GLOB="*"
LIMIT=0                 # 0 = bez limitu
CSV_MODE="no"
ORDER="asc"             # domyślnie najstarsze -> najnowsze (użyj --desc aby odwrócić)
TZ_DISPLAY="${TZ_DISPLAY:-Europe/Warsaw}"
export TZ="$TZ_DISPLAY"

usage() {
  cat <<'EOF'
Użycie:
  list_backups.sh [--dir <katalog>] [--from "<czas>"] [--to "<czas>"] [--since <okres>]
                  [--name "<glob>"] [--limit N] [--csv] [--asc|--desc]

Przykłady:
  list_backups.sh
  list_backups.sh --since 2h --name "*_loluli.tar.zst"
  list_backups.sh --from "2025-09-29_19:15" --to "2025-09-29 21:00"
  list_backups.sh --csv --since 3d
  list_backups.sh --asc --limit 10   # 10 najnowszych, pokazanych rosnąco
EOF
}

to_epoch() {
  local raw="${1:-}"; [[ -z "$raw" ]] && { echo ""; return; }
  raw="${raw//./-}"; raw="${raw//_/ }"
  date -d "$raw" +%s 2>/dev/null || { echo ""; return; }
}

since_to_seconds() {
  local s="${1,,}"; [[ -z "$s" ]] && { echo ""; return; }
  s="${s/mins/min}"; s="${s/minute/min}"; s="${s/minutes/min}"
  case "$s" in
    *w)   echo $(( ${s%w} * 7 * 24 * 3600 ));;
    *d)   echo $(( ${s%d} * 24 * 3600 ));;
    *h)   echo $(( ${s%h} * 3600 ));;
    *m)   echo $(( ${s%m} * 60 ));;
    *min) echo $(( ${s%min} * 60 ));;
    *s)   echo $(( ${s%s} ));;
    *[0-9]) echo "$s" ;;
    *) echo ""; return 1;;
  esac
}

hr() { numfmt --to=iec --suffix=B --padding=7 ${1:-0} 2>/dev/null || echo "${1:-0}B"; }

# --- Args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)   DIR="$2"; shift 2 ;;
    --from)  FROM_RAW="$2"; shift 2 ;;
    --to)    TO_RAW="$2"; shift 2 ;;
    --since) SINCE_RAW="$2"; shift 2 ;;
    --name)  NAME_GLOB="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --csv)   CSV_MODE="yes"; shift ;;
    --asc)   ORDER="asc"; shift ;;
    --desc)  ORDER="desc"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Nieznana opcja: $1"; usage; exit 1 ;;
  esac
done

[[ -d "$DIR" ]] || { echo "Brak katalogu: $DIR"; exit 1; }

FROM_EPOCH="$(to_epoch "$FROM_RAW")"
TO_EPOCH="$(to_epoch "$TO_RAW")"

# --since → ustawia FROM, jeśli nie podano --from
if [[ -n "$SINCE_RAW" && -z "$FROM_EPOCH" ]]; then
  secs="$(since_to_seconds "$SINCE_RAW" || true)"
  [[ -z "$secs" ]] && { echo "Nieprawidłowy --since: $SINCE_RAW"; exit 1; }
  FROM_EPOCH=$(( $(date +%s) - secs ))
fi
[[ -z "$FROM_EPOCH" ]] && FROM_EPOCH=0
[[ -z "$TO_EPOCH"   ]] && TO_EPOCH=9999999999

# ===== ZBIERANIE PLIKÓW (robust via find) =====
LINES=()
if command -v mapfile >/dev/null 2>&1; then
  mapfile -t LINES < <(find "$DIR" -maxdepth 1 -type f -name "$NAME_GLOB" -printf '%T@|%p|%s\n' 2>/dev/null)
else
  while IFS= read -r line; do LINES+=("$line"); done < <(
    find "$DIR" -maxdepth 1 -type f -name "$NAME_GLOB" -printf '%T@|%p|%s\n' 2>/dev/null
  )
fi

ROWS=()
for line in "${LINES[@]}"; do
  IFS='|' read -r epoch_f path_f bytes_f <<< "$line"
  epoch="${epoch_f%.*}"
  (( epoch < FROM_EPOCH || epoch > TO_EPOCH )) && continue
  name="$(basename "$path_f")"
  mtime="$(date -d "@$epoch" '+%F %T')"
  size_h="$(hr "$bytes_f")"
  ROWS+=( "$name"$'\t'"$mtime"$'\t'"$size_h"$'\t'"$epoch"$'\t'"$bytes_f" )
done

# Sort po kol.4 (epoch)
if [[ "$ORDER" == "asc" ]]; then
  SORT_CMD="sort -t $'\t' -k4,4n"
else
  SORT_CMD="sort -t $'\t' -k4,4nr"
fi

# Funkcja wyboru top-N zgodnie z kierunkiem sortu
pick_topN() {
  if (( LIMIT > 0 )); then
    if [[ "$ORDER" == "asc" ]]; then tail -n "$LIMIT"; else head -n "$LIMIT"; fi
  else
    cat
  fi
}

if [[ "$CSV_MODE" == "yes" ]]; then
  echo "File,CreatedAt,SizeBytes,SizeHuman"
  printf "%s\n" "${ROWS[@]}" \
    | eval "$SORT_CMD" \
    | pick_topN \
    | awk -F '\t' '{printf "%s,%s,%s,%s\n",$1,$2,$5,$3}'
else
  tmp="/tmp/.list_backups.$$.$RANDOM.tbl"
  {
    echo -e "Plik\tUtworzono\tRozmiar"
    printf "%s\n" "${ROWS[@]}" \
      | eval "$SORT_CMD" \
      | pick_topN \
      | cut -f1-3
  } > "$tmp"
  if command -v column >/dev/null 2>&1; then column -t -s $'\t' "$tmp"; else cat "$tmp"; fi
  rm -f "$tmp" 2>/dev/null || true

  total="${#ROWS[@]}"; shown="$total"
  (( LIMIT > 0 && total > LIMIT )) && shown="$LIMIT/$total"
  echo
  echo "Katalog: $DIR | Nazwa: '$NAME_GLOB' | Zakres: $( [[ $FROM_EPOCH -gt 0 ]] && date -d \"@$FROM_EPOCH\" '+%F %T' || echo '-' ) → $( [[ $TO_EPOCH -lt 9999999999 ]] && date -d \"@$TO_EPOCH\" '+%F %T' || echo '-' ) | Sort: $ORDER | TZ: $TZ_DISPLAY"
  echo "Wyników: $shown"
fi
