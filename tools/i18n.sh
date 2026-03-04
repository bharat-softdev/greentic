#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MODE="${1:-all}"
AUTH_MODE="${AUTH_MODE:-auto}"
BATCH_SIZE="${BATCH_SIZE:-200}"
LOCALE="${LOCALE:-en}"
EN_PATH="${EN_PATH:-assets/i18n/en.json}"
I18N_TRANSLATOR_MANIFEST="${I18N_TRANSLATOR_MANIFEST:-../greentic-i18n/Cargo.toml}"
LOCALES_META_PATH="${LOCALES_META_PATH:-assets/i18n/locales.json}"
I18N_DIR="${I18N_DIR:-assets/i18n}"

usage() {
  cat <<'USAGE'
Usage: tools/i18n.sh [translate|validate|status|all]

Environment overrides:
  EN_PATH=...                     English source file path (default: assets/i18n/en.json)
  AUTH_MODE=...                   Translator auth mode for translate (default: auto)
  BATCH_SIZE=...                  Keys per translation batch (default: 200)
  LOCALE=...                      CLI locale used for translator output (default: en)
  I18N_TRANSLATOR_MANIFEST=...    Path to translator workspace Cargo.toml

Examples:
  tools/i18n.sh all
  AUTH_MODE=api-key tools/i18n.sh translate
  EN_PATH=assets/i18n/en.json tools/i18n.sh validate
  BATCH_SIZE=200 tools/i18n.sh translate
USAGE
}

seed_lang_files() {
  mkdir -p "$I18N_DIR"

  # Keep aligned with greentic-component/tools/i18n-seed-langs.sh
  local langs=(
    ar ar-AE ar-DZ ar-EG ar-IQ ar-MA ar-SA ar-SD ar-SY ar-TN
    ay bg bn cs da de el en en-GB es et fa fi fr gn gu hi hr ht hu
    id it ja km kn ko lo lt lv ml mr ms my nah ne nl no pa pl pt
    qu ro ru si sk sr sv ta te th tl tr uk ur vi zh
  )

  local lang
  for lang in "${langs[@]}"; do
    local path="$I18N_DIR/${lang}.json"
    if [[ ! -f "$path" ]]; then
      printf "{\n}\n" > "$path"
      echo "created $path"
    fi
  done
}

sync_locales_meta() {
  python3 - <<'PY' "$I18N_DIR" "$LOCALES_META_PATH"
import json
import pathlib
import sys

i18n_dir = pathlib.Path(sys.argv[1])
meta_path = pathlib.Path(sys.argv[2])

locales = []
for p in sorted(i18n_dir.glob("*.json")):
    if p.name == "locales.json":
        continue
    locales.append(p.stem)

payload = {
    "default": "en",
    "supported": locales,
}

meta_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"wrote {meta_path}")
PY
}

translator_cmd() {
  if [[ -f "$I18N_TRANSLATOR_MANIFEST" ]]; then
    echo "cargo run --manifest-path \"$I18N_TRANSLATOR_MANIFEST\" -p greentic-i18n-translator --"
    return 0
  fi

  if command -v greentic-i18n-translator >/dev/null 2>&1; then
    echo "greentic-i18n-translator"
    return 0
  fi

  echo "ERROR: translator not found. Set I18N_TRANSLATOR_MANIFEST or install greentic-i18n-translator." >&2
  exit 1
}

run_translate() {
  local cmd
  cmd="$(translator_cmd)"
  seed_lang_files
  sync_locales_meta
  with_hidden_locales_meta \
    "$cmd --locale \"$LOCALE\" translate --langs all --en \"$EN_PATH\" --auth-mode \"$AUTH_MODE\" --batch-size \"$BATCH_SIZE\""
  sync_locales_meta
}

run_validate() {
  local cmd
  cmd="$(translator_cmd)"
  seed_lang_files
  sync_locales_meta
  with_hidden_locales_meta \
    "$cmd --locale \"$LOCALE\" validate --langs all --en \"$EN_PATH\""
  sync_locales_meta
}

run_status() {
  local cmd
  cmd="$(translator_cmd)"
  seed_lang_files
  sync_locales_meta
  with_hidden_locales_meta \
    "$cmd --locale \"$LOCALE\" status --langs all --en \"$EN_PATH\""
  sync_locales_meta
}

with_hidden_locales_meta() {
  local command="$1"
  local backup_path="${LOCALES_META_PATH}.bak.$$"
  local had_meta=0

  if [[ -f "$LOCALES_META_PATH" ]]; then
    mv "$LOCALES_META_PATH" "$backup_path"
    had_meta=1
  fi

  local exit_code=0
  eval "$command" || exit_code=$?

  if [[ "$had_meta" -eq 1 && -f "$backup_path" ]]; then
    mv "$backup_path" "$LOCALES_META_PATH"
  fi

  if [[ "$had_meta" -eq 0 && -f "$backup_path" ]]; then
    rm -f "$backup_path"
  fi

  return $exit_code
}

if [[ "${MODE}" == "-h" || "${MODE}" == "--help" ]]; then
  usage
  exit 0
fi

case "$MODE" in
  translate) run_translate ;;
  validate) run_validate ;;
  status) run_status ;;
  all)
    run_translate
    run_validate
    run_status
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    usage
    exit 2
    ;;
esac
