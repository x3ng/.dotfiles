#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"

case "${1:-install}" in
  install)
    # refuse non-interactive invocation unless env var is preset
    if ! is_dry_run && [[ ! -t 0 ]] && [[ -z "${MIHOMO_SUB_URL:-}" ]]; then
      log_err "mihomo needs interactive input (SUB_URL)"
      echo "  interactively: sudo ./deploy/deploy mihomo"
      echo "  noninteractive: sudo MIHOMO_SUB_URL=<url> ./deploy/deploy mihomo"
      exit 1
    fi

    if ! is_dry_run && [[ $EUID -ne 0 ]]; then
      log_err "mihomo needs root to install to /etc/mihomo/"
      echo "  run with sudo or as root"
      exit 1
    fi

    sub_url="${MIHOMO_SUB_URL:-}"
    if is_dry_run && [[ -z "$sub_url" ]]; then
      sub_url="<SUB_URL>"
    fi
    if [[ -z "$sub_url" ]]; then
      read -rp "  订阅地址 (SUB_URL): " sub_url
    fi
    if [[ -z "$sub_url" ]]; then
      log_err "SUB_URL is required"
      exit 1
    fi

    dot_template \
      "$SCRIPT_DIR/config.yaml" \
      "/etc/mihomo/config.yaml" \
      SUB_URL="$sub_url"
    ;;
  uninstall)
    dot_untemplate "/etc/mihomo/config.yaml"
    ;;
  *)
    echo "usage: $0 {install|uninstall}" >&2
    echo "  sudo MIHOMO_SUB_URL=<url> $0 install  skip interactive prompt" >&2
    exit 1
    ;;
esac
