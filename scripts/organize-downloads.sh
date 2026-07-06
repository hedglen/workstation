#!/usr/bin/env bash
# organize-downloads.sh
# Scans ~/Downloads, categorizes loose files by type, detects duplicates by hash.
# Runs in DRY_RUN mode by default. Pass --run to actually move files.
# Generates a rollback script after each live run.

set -euo pipefail

# Derive Windows home dynamically so this works on any PC
WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')
WIN_HOME="/mnt/c/Users/${WIN_USER}"
DOWNLOADS="${WIN_HOME}/Downloads"
LOG_DIR="${WIN_HOME}/workstation/scripts/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ROLLBACK_SCRIPT="$LOG_DIR/rollback_${TIMESTAMP}.sh"
DRY_RUN=true

# ── argument parsing ──────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --run) DRY_RUN=false ;;
    --dry-run) DRY_RUN=true ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

mkdir -p "$LOG_DIR"

# ── category map (extension → subfolder) ─────────────────────────────────────
declare -A EXT_MAP=(
  # Images
  [jpg]="Images"   [jpeg]="Images"  [png]="Images"   [gif]="Images"
  [webp]="Images"  [bmp]="Images"   [tiff]="Images"  [ico]="Images"
  [svg]="Images/SVG"
  # Documents
  [pdf]="Documents"  [doc]="Documents"   [docx]="Documents"
  [xls]="Documents"  [xlsx]="Documents"  [ppt]="Documents"
  [pptx]="Documents" [txt]="Documents"   [md]="Documents"
  [csv]="Documents"  [odt]="Documents"   [rtf]="Documents"
  # Archives
  [zip]="Compressed"  [rar]="Compressed"  [7z]="Compressed"
  [tar]="Compressed"  [gz]="Compressed"   [bz2]="Compressed"
  [xz]="Compressed"   [cab]="Compressed"
  # Music
  [mp3]="Music"  [flac]="Music"  [aac]="Music"  [wav]="Music"
  [ogg]="Music"  [m4a]="Music"   [wma]="Music"
  # Video
  [mp4]="Video"  [mkv]="Video"  [avi]="Video"  [mov]="Video"
  [wmv]="Video"  [webm]="Video" [m4v]="Video"  [flv]="Video"
  # Programs / Installers
  [exe]="Programs"  [msi]="Programs"  [msix]="Programs"
  [appx]="Programs" [deb]="Programs"  [rpm]="Programs"
  [dmg]="Programs"  [pkg]="Programs"
)

# ── helpers ───────────────────────────────────────────────────────────────────
log() { echo "$*"; }
move_file() {
  local src="$1" dst_dir="$2"
  local filename
  filename=$(basename "$src")
  local dst="$dst_dir/$filename"

  # handle name collision
  if [[ -e "$dst" ]]; then
    local base="${filename%.*}" ext="${filename##*.}"
    dst="$dst_dir/${base}_${TIMESTAMP}.${ext}"
  fi

  if $DRY_RUN; then
    log "  [DRY-RUN] MOVE: \"$src\" → \"$dst\""
  else
    mkdir -p "$dst_dir"
    mv "$src" "$dst"
    echo "mv \"$dst\" \"$src\"" >> "$ROLLBACK_SCRIPT"
    log "  MOVED: \"$(basename "$src")\" → ${dst_dir##$DOWNLOADS/}"
  fi
}

# ── duplicate detection ───────────────────────────────────────────────────────
detect_duplicates() {
  log ""
  log "════════════════════════════════════════"
  log " DUPLICATE DETECTION (by MD5 hash)"
  log "════════════════════════════════════════"

  declare -A hash_map
  local dup_count=0

  while IFS= read -r -d '' file; do
    # skip system files
    [[ "$(basename "$file")" == "desktop.ini" ]] && continue
    local hash
    hash=$(md5sum "$file" | cut -d' ' -f1)
    if [[ -n "${hash_map[$hash]+_}" ]]; then
      log "  DUPLICATE: \"$(basename "$file")\""
      log "    same as: \"${hash_map[$hash]##$DOWNLOADS/}\""
      ((dup_count++)) || true
    else
      hash_map[$hash]="$file"
    fi
  done < <(find "$DOWNLOADS" -maxdepth 2 -type f -print0 | sort -z)

  if [[ $dup_count -eq 0 ]]; then
    log "  No duplicates found."
  else
    log ""
    log "  Total duplicate files: $dup_count"
    log "  (Duplicates are flagged only — not moved automatically)"
  fi
}

# ── main scan ─────────────────────────────────────────────────────────────────
log ""
log "════════════════════════════════════════"
log " DOWNLOADS ORGANIZER"
log " Mode: $(${DRY_RUN} && echo 'DRY RUN' || echo 'LIVE')"
log " Scan: $DOWNLOADS"
log " Time: $(date)"
log "════════════════════════════════════════"
log ""

if ! $DRY_RUN; then
  echo "#!/usr/bin/env bash" > "$ROLLBACK_SCRIPT"
  echo "# Rollback script generated $TIMESTAMP" >> "$ROLLBACK_SCRIPT"
  echo "set -euo pipefail" >> "$ROLLBACK_SCRIPT"
  echo "" >> "$ROLLBACK_SCRIPT"
  chmod +x "$ROLLBACK_SCRIPT"
fi

moved=0
skipped=0
unknown=0

# Only process files at the TOP LEVEL of Downloads (not inside existing subfolders)
while IFS= read -r -d '' file; do
  filename=$(basename "$file")

  # skip system/hidden files
  if [[ "$filename" == "desktop.ini" || "$filename" == .* ]]; then
    log "  [SKIP] system/hidden: $filename"
    ((skipped++)) || true
    continue
  fi

  # get lowercase extension
  ext="${filename##*.}"
  ext="${ext,,}"

  if [[ -n "${EXT_MAP[$ext]+_}" ]]; then
    dst_dir="$DOWNLOADS/${EXT_MAP[$ext]}"
    # don't move if already in the right place
    if [[ "$(dirname "$file")" == "$dst_dir" ]]; then
      log "  [OK] already in place: $filename"
      ((skipped++)) || true
    else
      move_file "$file" "$dst_dir"
      ((moved++)) || true
    fi
  else
    log "  [UNKNOWN] no category for: $filename (.$ext)"
    ((unknown++)) || true
  fi

done < <(find "$DOWNLOADS" -maxdepth 1 -type f -print0)

log ""
log "────────────────────────────────────────"
log " Files to move : $moved"
log " Skipped       : $skipped"
log " Unknown type  : $unknown"
log "────────────────────────────────────────"

detect_duplicates

if ! $DRY_RUN && [[ $moved -gt 0 ]]; then
  log ""
  log "Rollback script saved to:"
  log "  $ROLLBACK_SCRIPT"
  log ""
  log "To undo, run:"
  log "  bash \"$ROLLBACK_SCRIPT\""
fi

log ""
