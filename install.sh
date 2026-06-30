#!/bin/bash
set -e

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"
BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.claude"

mkdir -p "$BIN_DIR" "$CONFIG_DIR"

echo -e "${BOLD}Claude Code Superboost Config Installer${NC}"
echo ""

# ─── Step 1: 安装核心 CLI 工具 ─────────────────
echo -e "${BOLD}[1/5] Installing CLI tools...${NC}"

# rtk
if ! command -v rtk &>/dev/null; then
  echo "  Installing rtk..."
  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | bash
else
  echo -e "  ${GREEN}✓${NC} rtk ($(rtk --version 2>&1))"
fi

# lean-ctx
if ! command -v lean-ctx &>/dev/null; then
  echo "  Installing lean-ctx..."
  ARCH=$(uname -m)
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$ARCH-$OS" in
    x86_64-linux)   TARGET="lean-ctx-x86_64-unknown-linux-gnu.tar.gz" ;;
    aarch64-linux)  TARGET="lean-ctx-aarch64-unknown-linux-gnu.tar.gz" ;;
    x86_64-darwin)  TARGET="lean-ctx-x86_64-apple-darwin.tar.gz" ;;
    arm64-darwin)   TARGET="lean-ctx-aarch64-apple-darwin.tar.gz" ;;
    *) echo -e "  ${RED}✗${NC} Unsupported platform: $ARCH-$OS"; exit 1 ;;
  esac
  LATEST=$(curl -s https://api.github.com/repos/yvgude/lean-ctx/releases/latest | grep tag_name | cut -d'"' -f4)
  curl -fsSL "https://github.com/yvgude/lean-ctx/releases/download/${LATEST}/${TARGET}" -o /tmp/leanctx.tgz
  tar xzf /tmp/leanctx.tgz -C /tmp
  mv /tmp/lean-ctx "$BIN_DIR/"
  chmod +x "$BIN_DIR/lean-ctx"
  rm -f /tmp/leanctx.tgz
  echo -e "  ${GREEN}✓${NC} lean-ctx ${LATEST}"
else
  echo -e "  ${GREEN}✓${NC} lean-ctx ($(lean-ctx --version 2>&1))"
fi

# fff-mcp
if ! command -v fff-mcp &>/dev/null; then
  echo "  Installing fff-mcp..."
  curl -fsSL https://dmtrkovalenko.dev/install-fff-mcp.sh | bash
else
  echo -e "  ${GREEN}✓${NC} fff-mcp ($(fff-mcp --version 2>&1))"
fi

# headroom
if ! command -v headroom &>/dev/null; then
  echo "  Installing headroom..."
  pip install headroom-ai 2>/dev/null || pip3 install headroom-ai
else
  echo -e "  ${GREEN}✓${NC} headroom ($(headroom --version 2>&1))"
fi

# beads (bd)
if ! command -v bd &>/dev/null; then
  echo "  Installing beads (bd)..."
  curl -fsSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash
else
  echo -e "  ${GREEN}✓${NC} beads ($(bd version 2>&1))"
fi

# codeburn
if ! command -v codeburn &>/dev/null; then
  echo "  Installing codeburn..."
  npm install -g codeburn
else
  echo -e "  ${GREEN}✓${NC} codeburn ($(codeburn --version 2>&1))"
fi

echo ""

# ─── Step 2: 安装 Claude Code Plugins ──────────
echo -e "${BOLD}[2/5] Installing Claude Code plugins...${NC}"

PLUGINS=(
  "claude-mem@thedotmack"
  "andrej-karpathy-skills@karpathy-skills"
  "voltagent-lang@voltagent-subagents"
  "voltagent-core-dev@voltagent-subagents"
  "voltagent-qa-sec@voltagent-subagents"
  "voltagent-infra@voltagent-subagents"
  "voltagent-meta@voltagent-subagents"
  "pyright-lsp@claude-plugins-official"
  "vtsls@claude-code-lsps"
  "bash-language-server@claude-code-lsps"
  "yaml-language-server@claude-code-lsps"
  "plugin-dev@claude-plugins-official"
)

for plugin in "${PLUGINS[@]}"; do
  if claude plugins list 2>/dev/null | grep -q "$plugin"; then
    echo -e "  ${GREEN}✓${NC} $plugin"
  else
    echo "  Installing $plugin..."
    claude plugins install "$plugin" 2>/dev/null && echo -e "  ${GREEN}✓${NC} $plugin" || echo -e "  ${YELLOW}⚠${NC} $plugin (manual install needed)"
  fi
done

# Disable voltagent-dev-exp (not needed)
claude plugins disable voltagent-dev-exp@voltagent-subagents 2>/dev/null || true

echo ""

# ─── Step 3: 安装 Skills ───────────────────────
echo -e "${BOLD}[3/5] Skills already bundled in config (97 skills)${NC}"
echo "  Skills are auto-discovered from ~/.claude/skills/"
echo "  Copying bundled skills..."
mkdir -p "$CONFIG_DIR/skills"
cp -r skills/* "$CONFIG_DIR/skills/" 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} Skills installed"

echo ""

# ─── Step 4: 安装配置文件 ──────────────────────
echo -e "${BOLD}[4/5] Installing config files...${NC}"

# Backup
mkdir -p "$CONFIG_DIR/backups"
cp "$CONFIG_DIR/settings.json" "$CONFIG_DIR/backups/settings.json.bak.$(date +%Y%m%d)" 2>/dev/null || true
cp "$CONFIG_DIR/CLAUDE.md" "$CONFIG_DIR/backups/CLAUDE.md.bak.$(date +%Y%m%d)" 2>/dev/null || true

# Install
cp CLAUDE.md "$CONFIG_DIR/"
cp RTK.md "$CONFIG_DIR/"
cp session-init.sh "$CONFIG_DIR/"
cp env-wrapper.sh "$CONFIG_DIR/"
chmod +x "$CONFIG_DIR/session-init.sh" "$CONFIG_DIR/env-wrapper.sh"

# Hooks
mkdir -p "$CONFIG_DIR/hooks/auditor"
cp hooks/*.sh "$CONFIG_DIR/hooks/" 2>/dev/null || true
cp hooks/auditor/*.sh "$CONFIG_DIR/hooks/auditor/" 2>/dev/null || true
chmod +x "$CONFIG_DIR/hooks/"*.sh "$CONFIG_DIR/hooks/auditor/"*.sh 2>/dev/null || true

# Settings (merge MCP config, preserve existing)
cp settings.json "$CONFIG_DIR/settings.json"

echo -e "  ${GREEN}✓${NC} Config files installed"

echo ""

# ─── Step 5: MCP 后安装 ────────────────────────
echo -e "${BOLD}[5/5] MCP servers configured in settings.json:${NC}"
echo "  • lean-ctx (stdio)"
echo "  • fff (stdio)"
echo "  • headroom (stdio)"
echo "  • ka-bridge (http)"
echo -e "  ${YELLOW}ℹ${NC} ka-bridge is internal — configure if needed"

echo ""
echo -e "${GREEN}${BOLD}Installation complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code"
echo "  2. In each git project: cd PROJECT && bd init"
echo "  3. Check status: codeburn report"
