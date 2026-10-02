#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"

TARGET="/etc/keyd/thinkpad.conf"

case "${1:-install}" in
  install|uninstall)
    if ! is_dry_run && [[ $EUID -ne 0 ]]; then
      log_err "keyd needs root to manage /etc/keyd/"
      echo "  run: sudo ./deploy/deploy keyd"
      exit 1
    fi
    if [[ "${1:-install}" == "install" ]]; then
      dot_template "$SCRIPT_DIR/thinkpad.conf" "$TARGET"
    else
      dot_untemplate "$TARGET"
    fi
    log_info "if keyd is already running, apply the change with: sudo keyd reload"
    ;;
  *)
    echo "usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
