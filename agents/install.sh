#!/usr/bin/env bash
# Install the agent roster to this device's user-scope agents dir.
# Usage: ./install.sh            (copy)
#        ./install.sh --link     (symlink, so edits in this repo stay live)
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${HOME}/.claude/agents"
AGENTS=(architect frontend qa ux dx review)

mkdir -p "$DEST"

mode="copy"
[[ "${1:-}" == "--link" ]] && mode="link"

for a in "${AGENTS[@]}"; do
  src="${SRC}/${a}.md"
  dst="${DEST}/${a}.md"
  if [[ "$mode" == "link" ]]; then
    ln -sf "$src" "$dst"
    echo "linked  ${a} -> ${dst}"
  else
    cp -f "$src" "$dst"
    echo "copied  ${a} -> ${dst}"
  fi
done

echo "Done. ${#AGENTS[@]} agents installed to ${DEST}. Restart Claude Code to pick them up."
