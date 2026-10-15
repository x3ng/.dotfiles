#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/../deploy/lib.sh"

# fcitx5 只管理"静态"配置：只有 fcitx5-configtool 会改写的文件。
#
# 动态文件留在 ~/.config/fcitx5（fcitx5 会自动回写，接管它们必然打架）：
#   profile                  退出时 + AutoSavePeriod=30min autosave 无条件重写
#   conf/pinyin.conf         首次运行、云拼音快捷键、autosave 都会写
#   conf/chttrans.conf       覆写 save()，autosave/退出时重写
#   conf/punctuation.conf    覆写 save()，autosave/退出时重写
#   conf/notifications.conf  记录"不再显示"，autosave/退出时重写
#   conf/cached_layouts      运行时枚举 xkb 布局的缓存
# 依据：fcitx5 standardpath.cpp 的 safeSave = mkstemp + rename（无内容比对，
# 会把 symlink 替换成普通文件），instance.cpp 的退出保存与 autosave。
#
# 在 configtool 里改过静态文件后，链接会被 rename 冲掉：重新执行
# ./deploy/deploy fcitx5 回链（旧文件先备份为 *.backup.<时间戳>）。

STATIC=(
  config
  conf/classicui.conf
  conf/clipboard.conf
)

case "${1:-install}" in
  install)
    for f in "${STATIC[@]}"; do
      if [[ ! -e "$SCRIPT_DIR/$f" ]]; then
        log_warn "skip (not in repo): $f"
        continue
      fi
      dot_link "$SCRIPT_DIR/$f" "$HOME/.config/fcitx5/$f"
    done
    ;;
  uninstall)
    for f in "${STATIC[@]}"; do
      dot_unlink "$HOME/.config/fcitx5/$f"
    done
    ;;
  *)
    echo "usage: $0 {install|uninstall}" >&2
    exit 1
    ;;
esac
