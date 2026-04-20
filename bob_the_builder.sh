#!/bin/bash

INPUT_FILE=""
BASE_PATH="."
FORCE=false
DRY_RUN=false
ASSUME_YES=false
KEEP_BACKUP=false
PREVIEW=false
QUIET=false
NO_BACKUP=false
LENIENT=false
BACKUP_DIR=""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo "Usage:"
  echo "  bob_the_builder <architecture.txt> [dest]"
  echo ""
  echo "Options:"
  echo "  --preview"
  echo "  --dry-run"
  echo "  --force"
  echo "  --y"
  echo "  --keep-backup"
  echo "  --no-backup"
  echo "  --quiet"
  echo "  --lenient"
  echo "  --source chatgpt"
  echo " --source claude"
  exit 0
fi

declare -a indent_stack
declare -a path_parts
declare -a type_stack   # 👈 IMPORTANT: track file/dir

log() { [ "$QUIET" = false ] && echo -e "${BLUE}$1${NC}"; }
ok() { [ "$QUIET" = false ] && echo -e "${GREEN}$1${NC}"; }
warn() { [ "$QUIET" = false ] && echo -e "${YELLOW}$1${NC}"; }

is_file() {
  [[ "$1" == *.* && ! "$1" =~ ^\.+$ ]]
}

usage() {
  echo "Usage: $0 <architecture.txt> [dest] [--preview] [--force] [--dry-run] [--y] [--keep-backup] [--no-backup] [--quiet] [--lenient] [--source chatgpt] [--source claude]"
  exit 1
}

# --- args ---
for arg in "$@"; do
  case $arg in
    --preview) PREVIEW=true ;;
    --force) FORCE=true ;;
    --dry-run) DRY_RUN=true ;;
    --quiet) QUIET=true ;;
    --no-backup) NO_BACKUP=true ;;
    --keep-backup) KEEP_BACKUP=true ;;
    --lenient) LENIENT=true ;;
    --y) ASSUME_YES=true ;;
    *)
      if [ -z "$INPUT_FILE" ]; then
        INPUT_FILE="$arg"
      elif [ "$BASE_PATH" = "." ]; then
        BASE_PATH="$arg"
      fi
      ;;
  esac
done

[ -z "$INPUT_FILE" ] && usage
[ ! -f "$INPUT_FILE" ] && { echo "Error: file not found"; exit 1; }
[ ! -r "$INPUT_FILE" ] && { echo "Error: unreadable file"; exit 1; }
[ ! -s "$INPUT_FILE" ] && { echo "Error: empty file"; exit 1; }

BACKUP_DIR="$BASE_PATH/.backup_$(date +%s)"

ask_overwrite() {
  local file="$1"
  $FORCE && return 0
  $ASSUME_YES && return 0

  while true; do
    echo -n "File exists → $file | keep (k) / overwrite (o): "
    read -n 1 choice < /dev/tty
    echo ""
    case "$choice" in
      k|K) return 1 ;;
      o|O) return 0 ;;
      *) warn "press k or o" ;;
    esac
  done
}

backup_file() {
  local file="$1"
  [ ! -f "$file" ] && return
  [ "$NO_BACKUP" = true ] && return

  local abs_base=$(realpath "$BASE_PATH")
  local abs_file=$(realpath "$file")
  local rel_path="${abs_file#$abs_base/}"
  local backup_path="$BACKUP_DIR/$rel_path"

  mkdir -p "$(dirname "$backup_path")"
  cp "$file" "$backup_path"

  warn "backup → $rel_path"
}

print_preview() {
  local prefix=""
  for ((i=0; i<level; i++)); do prefix="$prefix  "; done

  if [[ "$name" == *.* ]]; then
    echo "${prefix}- 📄 $name"
  else
    echo "${prefix}- 📁 $name"
  fi
}

[ "$DRY_RUN" = false ] && mkdir -p "$BASE_PATH"

LINE_INDEX=0

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  ((LINE_INDEX++))

  # normalize tabs
  line=$(echo "$line" | sed $'s/\t/  /g')

  name=$(echo "$line" | sed -E 's/^ *//' | sed 's:/*$::')

  if [ $LINE_INDEX -eq 1 ]; then
    BASE_NAME=$(basename "$BASE_PATH")
  fi

  indent=$(expr match "$line" ' *')

  # --- STRICT MODE ---
  if [ "$LENIENT" = false ]; then
    if (( indent % 2 != 0 )); then
      echo "Error: invalid indentation (use --lenient)"
      exit 1
    fi
    level=$((indent / 2))
  else
    # --- LENIENT MODE (FIXED) ---
    level=0
    found=false

    for i in "${!indent_stack[@]}"; do
      if [ "${indent_stack[$i]}" -eq "$indent" ]; then
        level=$i
        found=true
        break
      fi
    done

    if [ "$found" = false ]; then
      level=${#indent_stack[@]}
      indent_stack[$level]=$indent
    fi

    for ((i=level+1; i<20; i++)); do unset indent_stack[$i]; done
  fi

  # skip root duplication
  if [ $LINE_INDEX -eq 1 ] && [ "$name" = "$BASE_NAME" ]; then
    continue
  fi

  # 🔥 CRITICAL FIX: prevent file as parent
  parent_level=$((level - 1))
  if [ $parent_level -ge 0 ]; then
    if [ "${type_stack[$parent_level]}" = "file" ]; then
      level=$parent_level
    fi
  fi

  # store
  path_parts[$level]="$name"
  type_stack[$level]=$(is_file "$name" && echo "file" || echo "dir")

  for ((i=level+1; i<20; i++)); do
    unset path_parts[$i]
    unset type_stack[$i]
  done

  # build path
  full="$BASE_PATH"
  for ((i=0; i<=level; i++)); do
    full="$full/${path_parts[$i]}"
  done

  if [ "$PREVIEW" = true ]; then
    print_preview
    continue
  fi

  if is_file "$name"; then
    [ "$DRY_RUN" = true ] && log "[DRY] file $full" && continue

    mkdir -p "$(dirname "$full")"

    if [ -f "$full" ]; then
      if ask_overwrite "$full"; then
        backup_file "$full"
        > "$full"
        ok "overwrite $full"
      else
        log "keep $full"
      fi
    else
      touch "$full"
      ok "create $full"
    fi
  else
    [ "$DRY_RUN" = true ] && log "[DRY] dir $full" && continue
    mkdir -p "$full"
    ok "dir $full"
  fi

done < "$INPUT_FILE"

# --- backup cleanup ---
if [ -d "$BACKUP_DIR" ]; then
  echo ""
  warn "Backup created → $BACKUP_DIR"

  if [ "$KEEP_BACKUP" = true ]; then
    log "backup kept (--keep-backup)"
  elif [ "$ASSUME_YES" = true ]; then
    rm -rf "$BACKUP_DIR"
    ok "backup deleted (--y)"
  else
    read -p "Delete backup? (y/n): " confirm < /dev/tty
    if [[ "$confirm" == "y" ]]; then
      rm -rf "$BACKUP_DIR"
      ok "backup deleted"
    else
      log "backup kept"
    fi
  fi
fi

if [ "$QUIET" = false ]; then
  echo ""
  ok "Done 🚀"
fi
