#!/usr/bin/env bash
set -euo pipefail
preview_dir=$(cd "$(dirname "$0")" && pwd)
case "${1:-greeter}" in
  greeter) export QS_PREVIEW_LOCK=0 ;;
  lock) export QS_PREVIEW_LOCK=1 ;;
  *) echo "usage: $0 [greeter|lock]" >&2; exit 2 ;;
esac
exec quickshell --path "$preview_dir/preview.qml"
