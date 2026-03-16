#!/bin/bash
set -euo pipefail

# Show uncommitted changes in Zsh prompt
git config devcontainers-theme.show-dirty 1

# Install Pure prompt
mkdir -p "$HOME/.zsh"
git clone https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure"
sed -i "s|^ZSH_THEME=.*|ZSH_THEME=\"\"\n\nFPATH=\$HOME/.zsh/pure:\$FPATH|" $HOME/.zshrc

cat >>$HOME/.zshrc <<'EOF'

# Pure prompt
autoload -U promptinit; promptinit
prompt pure
psvar[13]=''  # set Pure prompt username to blank
EOF

# --- Persistent shell history ---
# Stored on a named Docker volume at ~/.shell_history/ to survive rebuilds.
HISTDIR="$HOME/.shell_history"
sudo chown "$(id -u):$(id -g)" "$HISTDIR"
touch "$HISTDIR/.bash_history" "$HISTDIR/.zsh_history"

# Redirect HISTFILE in .bashrc (idempotent)
if ! grep -q 'HISTFILE=.*\.shell_history' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export HISTFILE="$HOME/.shell_history/.bash_history"' >> "$HOME/.bashrc"
fi

# Redirect HISTFILE in .zshrc (idempotent)
if [ -f "$HOME/.zshrc" ] && ! grep -q 'HISTFILE=.*\.shell_history' "$HOME/.zshrc" 2>/dev/null; then
    echo 'export HISTFILE="$HOME/.shell_history/.zsh_history"' >> "$HOME/.zshrc"
fi

# --- Persistent Claude Code data ---
# The .claude volume is mounted from Docker and may be owned by root
sudo chown "$(id -u):$(id -g)" "$HOME/.claude"

# --- Persistent claude.json (settings) ---
# Symlink ~/.claude.json into the persistent .claude volume so
# settings survive container rebuilds.
if [ ! -f "$HOME/.claude/claude.json" ]; then
    echo '{}' > "$HOME/.claude/claude.json"
fi
ln -sf "$HOME/.claude/claude.json" "$HOME/.claude.json"

# Welcome message
echo -e "\e[38;5;209m

  ████████████
  ██\e[30m█\e[38;5;209m██████\e[30m█\e[38;5;209m██
████████████████
  ████████████
   █ █    █ █\e[0m

Welcome to the Claude Dev Container!
"

# --- Profile-specific notice ---
if echo "${AWS_REGION:-}" | grep -q '^us-gov'; then
    echo -e "\e[32m✅ AWS GovCloud (${AWS_REGION}) — CUI data is permitted in this environment.\e[0m"
else
    echo -e "\e[33m⚠️  AWS Commercial (${AWS_REGION:-unknown}) — CUI data is NOT permitted in this environment.\e[0m"
fi
echo ""

echo "Type Ctrl-Shift-\` (backtick) to open a new terminal and get started building. 🛠️"
