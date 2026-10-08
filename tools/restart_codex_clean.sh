#!/usr/bin/env bash
# Start with the saved project handoff, without replaying the old session.
set -euo pipefail
if ! ( : </dev/tty ) 2>/dev/null; then
  echo '请在交互终端运行此脚本；它会启动一个全新的 Codex 会话。' >&2
  exit 1
fi
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec codex -C "$project_dir" \
  -c model_auto_compact_token_limit=32000 \
  -c tool_output_token_limit=4000 \
  '读取 docs/CODEX_RESTART_BRIEF.md，按其中约束继续项目。只按需读取文件，不加载旧会话历史。' </dev/tty
