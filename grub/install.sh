#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../deploy/lib.sh
source "$SCRIPT_DIR/../deploy/lib.sh"

# Override only for another distribution's GRUB directory or an isolated test.
GRUB_DIR="${GRUB_DIR:-/boot/grub}"
TARGET="$GRUB_DIR/custom.cfg"
MARKER="# Managed by dotfiles/grub. Appearance only; NixOS owns the boot entries."

fail() { log_err "$*"; exit 1; }

case "${1:-install}" in
  install|uninstall) ;;
  *) echo "usage: $0 {install|uninstall}" >&2; exit 2 ;;
esac

[[ "$GRUB_DIR" == /* && "$GRUB_DIR" != / ]] || fail "GRUB_DIR must be an absolute GRUB directory"
if ! is_dry_run && [[ $EUID -ne 0 ]]; then
  fail "run: sudo ./deploy/deploy grub"
fi

if ! is_dry_run; then
  [[ -d "$GRUB_DIR" && ! -L "$GRUB_DIR" ]] || fail "GRUB directory is missing or is a symlink: $GRUB_DIR"
  if [[ "$GRUB_DIR" == /boot/grub ]]; then
    mountpoint -q /boot || fail "/boot must be mounted before deploying the theme"
  fi
fi

# Never take over a custom.cfg owned by another tool or a manual configuration.
if ! is_dry_run && [[ -e "$TARGET" || -L "$TARGET" ]]; then
  [[ -f "$TARGET" && ! -L "$TARGET" ]] || fail "unexpected custom.cfg type: $TARGET"
  IFS= read -r first_line < "$TARGET" || true
  [[ "$first_line" == "$MARKER" ]] || fail "refusing to replace an unmanaged $TARGET"
fi

# Only the former installer's exact resource names and directory format are
# eligible for removal. Unexpected files or symlinks are left for inspection.
cleanup_legacy_themes() {
  local dir name entry safe
  local -a resources=(theme.txt font16.pf2 font20.pf2 font32.pf2 LICENSE-DejaVu.txt select_c.png select_n.png select_s.png select_w.png select_e.png select_nw.png select_ne.png select_sw.png select_se.png)
  for dir in "$GRUB_DIR"/themes/dotfiles-graphite-*; do
    [[ -e "$dir" || -L "$dir" ]] || continue
    name="${dir##*/}"
    if [[ -L "$GRUB_DIR/themes" || -L "$dir" || ! -d "$dir" || ! "$name" =~ ^dotfiles-graphite-[0-9a-f]{16}$ ]]; then
      log_warn "skip unrecognized theme target: $dir"
      continue
    fi
    safe=1
    for entry in "$dir"/* "$dir"/.[!.]* "$dir"/..?*; do
      [[ -e "$entry" || -L "$entry" ]] || continue
      case "${entry##*/}" in
        theme.txt|font16.pf2|font20.pf2|font32.pf2|LICENSE-DejaVu.txt|select_c.png|select_n.png|select_s.png|select_w.png|select_e.png|select_nw.png|select_ne.png|select_sw.png|select_se.png)
          [[ -f "$entry" && ! -L "$entry" ]] || safe=0 ;;
        *) safe=0 ;;
      esac
    done
    if [[ "$safe" != 1 ]]; then
      log_warn "keep theme directory containing unexpected files: $dir"
      continue
    fi
    if is_dry_run; then
      log_info "DRY: remove unused legacy resources: $dir"
    else
      for name in "${resources[@]}"; do
        [[ -f "$dir/$name" && ! -L "$dir/$name" ]] || continue
        rm -- "$dir/$name"
      done
      rmdir -- "$dir"
      log_info "removed unused legacy resources: $dir"
    fi
  done
}

if [[ "${1:-install}" == uninstall ]]; then
  if is_dry_run; then
    log_info "DRY: remove managed $TARGET (restore the ordinary GRUB menu)"
  elif [[ -f "$TARGET" ]]; then
    rm -- "$TARGET"
    sync -f "$GRUB_DIR"
    log_info "disabled custom appearance; boot entries and EFI files unchanged"
  else
    log_info "skip (appearance loader already absent)"
  fi
  cleanup_legacy_themes
  if ! is_dry_run; then sync -f "$GRUB_DIR"; fi
  exit 0
fi

files=(theme.txt font16.pf2 font20.pf2 font32.pf2 LICENSE-DejaVu.txt)
for file in "${files[@]}"; do
  [[ -s "$SCRIPT_DIR/graphite/$file" && ! -L "$SCRIPT_DIR/graphite/$file" ]] || fail "missing theme resource: $file"
done
digest="$(cd "$SCRIPT_DIR/graphite"; sha256sum "${files[@]}" | sha256sum)"
theme_name="dotfiles-graphite-${digest:0:16}"
theme_dir="$GRUB_DIR/themes/$theme_name"

if is_dry_run; then
  log_info "DRY: copy complete theme resources to $theme_dir"
  log_info "DRY: atomically publish $TARGET after resources are installed"
  exit 0
fi

[[ ! -L "$GRUB_DIR/themes" ]] || fail "themes directory must not be a symlink"
install -d -m 0755 "$GRUB_DIR/themes"
stage=""
loader=""
cleanup() {
  [[ -z "$loader" ]] || rm -f -- "$loader"
  [[ -z "$stage" ]] || rm -rf -- "$stage"
}
trap cleanup EXIT

if [[ -e "$theme_dir" || -L "$theme_dir" ]]; then
  [[ -d "$theme_dir" && ! -L "$theme_dir" ]] || fail "unexpected theme target: $theme_dir"
  for file in "${files[@]}"; do
    if [[ -L "$theme_dir/$file" ]] || ! cmp -s "$SCRIPT_DIR/graphite/$file" "$theme_dir/$file"; then
      fail "existing theme resource differs: $theme_dir/$file"
    fi
  done
else
  stage="$(mktemp -d "$GRUB_DIR/themes/.graphite-stage.XXXXXX")"
  chmod 0755 "$stage"
  for file in "${files[@]}"; do
    install -m 0644 "$SCRIPT_DIR/graphite/$file" "$stage/$file"
  done
  mv -- "$stage" "$theme_dir"
  stage=""
fi

# Flush complete resources before publishing the loader that refers to them.
sync -f "$theme_dir"
loader="$(mktemp "$GRUB_DIR/.custom.cfg.XXXXXX")"
sed "s/@THEME@/$theme_name/g" "$SCRIPT_DIR/custom.cfg.in" > "$loader"
chmod 0644 "$loader"
if [[ -n "${GRUB_SCRIPT_CHECK:-}" ]]; then
  "$GRUB_SCRIPT_CHECK" "$loader"
elif command -v grub-script-check >/dev/null 2>&1; then
  grub-script-check "$loader"
fi
if [[ -f "$TARGET" ]] && cmp -s "$loader" "$TARGET"; then
  log_info "skip (theme already deployed)"
  exit 0
fi
if [[ -f "$TARGET" ]]; then
  cp -- "$TARGET" "$TARGET.backup.$(date +%Y%m%d%H%M%S).$$"
fi
mv -f -- "$loader" "$TARGET"
loader=""
sync -f "$GRUB_DIR"
log_info "theme installed; next boot uses $theme_name"
log_info "disable with: sudo ./deploy/deploy --undo grub"
