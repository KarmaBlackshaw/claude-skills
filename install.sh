#!/usr/bin/env bash
#
# Install Claude skills (and their bundled agents) from KarmaBlackshaw/claude-skills
#
# Each skill folder may include an optional `agents/` subdirectory. When the
# skill installs, any `*.md` files in `<skill>/agents/` are copied to
# ~/.claude/agents/ so they're picked up alongside the skill.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/KarmaBlackshaw/claude-skills/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/KarmaBlackshaw/claude-skills/main/install.sh | bash -s figma-to-vue
#   curl -fsSL https://raw.githubusercontent.com/KarmaBlackshaw/claude-skills/main/install.sh | bash -s plan-and-build
#

set -euo pipefail

REPO_URL="https://github.com/KarmaBlackshaw/claude-skills.git"
SKILLS_DIR="$HOME/.claude/skills"
AGENTS_DIR="$HOME/.claude/agents"
TMP_DIR="$(mktemp -d)"
SKILL_FILTER="${1:-}"

# Cleanup on exit
trap 'rm -rf "$TMP_DIR"' EXIT

# Color codes (only if stdout is a terminal)
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi

info()    { echo -e "${BLUE}→${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}!${NC} $1"; }
error()   { echo -e "${RED}✗${NC} $1" >&2; }

# Check prerequisites
if ! command -v git >/dev/null 2>&1; then
  error "git is required but not installed."
  exit 1
fi

# Clone the repo
info "Cloning claude-skills repo..."
git clone --depth 1 --quiet "$REPO_URL" "$TMP_DIR/claude-skills"
REPO="$TMP_DIR/claude-skills"
SKILLS_ROOT="$REPO/skills"   # skills live under skills/ in the monorepo

# Ensure target directories exist
mkdir -p "$SKILLS_DIR" "$AGENTS_DIR"

# Determine which skills to install
if [ -n "$SKILL_FILTER" ]; then
  if [ ! -f "$SKILLS_ROOT/$SKILL_FILTER/SKILL.md" ]; then
    error "Skill '$SKILL_FILTER' not found in repo."
    info "Available skills:"
    find "$SKILLS_ROOT" -maxdepth 2 -name "SKILL.md" -exec dirname {} \; | xargs -n1 basename | sort -u | sed 's/^/  - /'
    exit 1
  fi
  SKILLS_TO_INSTALL=("$SKILL_FILTER")
else
  mapfile -t SKILLS_TO_INSTALL < <(
    find "$SKILLS_ROOT" -maxdepth 2 -name "SKILL.md" -exec dirname {} \; \
      | xargs -n1 basename \
      | sort -u
  )
fi

if [ ${#SKILLS_TO_INSTALL[@]} -eq 0 ]; then
  error "No skills found to install."
  exit 1
fi

INSTALLED_SKILLS=0
INSTALLED_AGENTS=0

# Install each skill (and its bundled agents)
for skill in "${SKILLS_TO_INSTALL[@]}"; do
  TARGET="$SKILLS_DIR/$skill"
  SOURCE="$SKILLS_ROOT/$skill"

  if [ -d "$TARGET" ] || [ -L "$TARGET" ]; then
    warn "Skill '$skill' already installed at $TARGET"
    info "Backing up to ${TARGET}.bak"
    rm -rf "${TARGET}.bak"
    mv "$TARGET" "${TARGET}.bak"
  fi

  info "Installing skill: $skill..."
  cp -r "$SOURCE" "$TARGET"

  # Verify SKILL.md exists and has valid frontmatter
  if [ ! -f "$TARGET/SKILL.md" ]; then
    error "Install failed: $TARGET/SKILL.md missing"
    exit 1
  fi
  if ! head -1 "$TARGET/SKILL.md" | grep -q '^---$'; then
    error "Install failed: $TARGET/SKILL.md has invalid frontmatter"
    exit 1
  fi

  success "skill: $skill → $TARGET"
  INSTALLED_SKILLS=$((INSTALLED_SKILLS + 1))

  # Install bundled agents, if any
  if [ -d "$SOURCE/agents" ]; then
    while IFS= read -r -d '' agent_file; do
      agent_name="$(basename "$agent_file")"
      AGENT_TARGET="$AGENTS_DIR/$agent_name"

      if [ -e "$AGENT_TARGET" ] || [ -L "$AGENT_TARGET" ]; then
        warn "Agent '$agent_name' already installed at $AGENT_TARGET"
        info "Backing up to ${AGENT_TARGET}.bak"
        rm -f "${AGENT_TARGET}.bak"
        mv "$AGENT_TARGET" "${AGENT_TARGET}.bak"
      fi

      info "  Installing bundled agent: $agent_name..."
      cp "$agent_file" "$AGENT_TARGET"

      if ! head -1 "$AGENT_TARGET" | grep -q '^---$'; then
        error "Install failed: $AGENT_TARGET has invalid frontmatter"
        exit 1
      fi

      success "  agent: $agent_name → $AGENT_TARGET"
      INSTALLED_AGENTS=$((INSTALLED_AGENTS + 1))
    done < <(find "$SOURCE/agents" -maxdepth 1 -name "*.md" ! -name "README.md" -print0)
  fi
done

echo ""
if [ "$INSTALLED_AGENTS" -gt 0 ]; then
  success "Done. Installed $INSTALLED_SKILLS skill(s) + $INSTALLED_AGENTS agent(s)."
else
  success "Done. Installed $INSTALLED_SKILLS skill(s)."
fi
warn "Restart Claude Code fully (quit, don't just close the window) to load."
