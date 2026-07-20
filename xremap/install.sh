#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"

TARGET="/etc/xremap/config.yml"

case "${1:-install}" in
  install)
    if ! is_dry_run && [[ ! -t 0 ]] && [[ -z "${XREMAP_SKIP_REVIEW:-}" ]]; then
      log_err "xremap is device-specific — review the config before deploying"
      echo "  interactively: sudo ./deploy/deploy xremap"
      echo "  noninteractive: sudo XREMAP_SKIP_REVIEW=1 ./deploy/deploy xremap"
      exit 1
    fi

    if ! is_dry_run && [[ $EUID -ne 0 ]]; then
      log_err "xremap needs root to install to /etc/xremap/"
      echo "  run with sudo or as root"
      exit 1
    fi

    if ! is_dry_run && [[ -t 0 ]] && [[ -z "${XREMAP_SKIP_REVIEW:-}" ]]; then
      echo "  xremap config is device-specific (keyboard remap)."
      echo "  Current config:"
      echo "  ---"
      cat "$SCRIPT_DIR/config.yml" | sed 's/^/  /'
      echo "  ---"
      read -rp "  deploy as-is? [y/N] " yn
      case "$yn" in
        [Yy]*) ;;
        *) log_info "cancelled"; exit 0 ;;
      esac
    fi

    dot_template "$SCRIPT_DIR/config.yml" "$TARGET"
    ;;
  uninstall)
    dot_untemplate "$TARGET"
    ;;
  *)
    echo "usage: $0 {install|uninstall}" >&2
    echo "  sudo XREMAP_SKIP_REVIEW=1 $0 install  skip interactive review" >&2
    exit 1
    ;;
esac
