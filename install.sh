#!/usr/bin/env bash
# claude-code-zai installer for Linux and macOS.
# Sets up `claude-z`: Claude Code on the z.ai GLM Coding Plan, with z.ai web search,
# web reader and vision MCP tools, a quota status line and /zai-usage.
#
#   curl -fsSL https://raw.githubusercontent.com/yel-hadd/claude-code-zai/v1.0.0/install.sh | bash
#   ./install.sh [--no-mcp] [--ref TAG] | --uninstall [--purge]
#
# Non-interactive: ZAI_API_KEY=... ./install.sh
# https://github.com/yel-hadd/claude-code-zai
set -euo pipefail

REPO="yel-hadd/claude-code-zai"
REF="v1.0.0"
DEST="$HOME/.claude-z"
KEY_FILE="$HOME/.config/zai/api_key"
MARK_BEGIN="# >>> claude-z >>>"
MARK_END="# <<< claude-z <<<"
FILES="scripts/claude-z.sh scripts/zai-quota.sh scripts/statusline.sh scripts/zai-usage-hook.sh scripts/zai-usage.md config/settings.json"
MCP_NAMES="web-search-prime web-reader zai-mcp-server"

action=do_install; purge=0; with_mcp=1
while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) action=do_uninstall ;;
    --purge) purge=1 ;;
    --no-mcp) with_mcp=0 ;;
    --ref) REF="$2"; shift ;;
    -h|--help) sed -n '2,10p' "$0" 2>/dev/null || true; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

say()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# rc files to manage: existing ~/.bashrc and ~/.zshrc, plus the one for the login shell
rc_files() {
  local shell_name; shell_name="$(basename "${SHELL:-bash}")"
  local list=""
  [ -f "$HOME/.bashrc" ] && list="$list $HOME/.bashrc"
  [ -f "$HOME/.zshrc" ] && list="$list $HOME/.zshrc"
  case "$shell_name" in
    zsh) case "$list" in *"$HOME/.zshrc"*) ;; *) list="$list $HOME/.zshrc" ;; esac ;;
    bash)
      if [ "$(uname -s)" = Darwin ]; then
        list="$list $HOME/.bash_profile"   # macOS Terminal starts login shells
      else
        case "$list" in *"$HOME/.bashrc"*) ;; *) list="$list $HOME/.bashrc" ;; esac
      fi ;;
  esac
  echo "$list"
}

strip_block() {  # remove our marked block from file $1, in place
  [ -f "$1" ] || return 0
  grep -qF "$MARK_BEGIN" "$1" || return 0
  local tmp; tmp="$(mktemp)"
  awk -v b="$MARK_BEGIN" -v e="$MARK_END" '$0==b{skip=1;next} $0==e{skip=0;next} !skip' "$1" > "$tmp"
  cat "$tmp" > "$1"; rm -f "$tmp"
}

zclaude() { CLAUDE_CONFIG_DIR="$DEST" claude "$@"; }

mcp_exists() {
  [ -f "$DEST/.claude.json" ] && jq -e --arg n "$1" '.mcpServers[$n] != null' "$DEST/.claude.json" >/dev/null 2>&1
}

do_uninstall() {
  say "Removing claude-z"
  for rc in $HOME/.bashrc $HOME/.zshrc $HOME/.bash_profile; do
    if [ -f "$rc" ] && grep -qF "$MARK_BEGIN" "$rc"; then strip_block "$rc"; say "Cleaned $rc"; fi
  done
  if command -v claude >/dev/null; then
    for n in $MCP_NAMES; do mcp_exists "$n" && zclaude mcp remove -s user "$n" >/dev/null 2>&1 && say "Removed MCP server $n"; done
  fi
  if [ -f "$DEST/settings.json" ] && command -v jq >/dev/null; then
    local tmp; tmp="$(mktemp)"
    jq '
      (if (.statusLine.command // "") | test("claude-z/statusline") then del(.statusLine) else . end)
      | (if .hooks.UserPromptSubmit then
           .hooks.UserPromptSubmit |= map(select(([.hooks[]?.command] | any(test("zai-usage-hook"))) | not))
           | (if (.hooks.UserPromptSubmit | length) == 0 then del(.hooks.UserPromptSubmit) else . end)
           | (if (.hooks | length) == 0 then del(.hooks) else . end)
         else . end)
      | (if .permissions.deny then .permissions.deny -= ["WebSearch"] else . end)
    ' "$DEST/settings.json" > "$tmp" && mv "$tmp" "$DEST/settings.json"
    say "Cleaned $DEST/settings.json"
  fi
  rm -f "$DEST/claude-z.sh" "$DEST/zai-quota.sh" "$DEST/statusline.sh" \
        "$DEST/hooks/zai-usage-hook.sh" "$DEST/commands/zai-usage.md"
  rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/zai-quota.json"
  if [ "$purge" = 1 ]; then rm -f "$KEY_FILE"; say "Deleted $KEY_FILE"; else say "Kept your key in $KEY_FILE (use --purge to delete it)"; fi
  say "Done. $DEST is kept because it holds your claude-z history and settings."
}

do_install() {
  command -v curl >/dev/null || die "curl is required"
  command -v jq >/dev/null || die "jq is required. Install it first (Fedora: sudo dnf install jq, Debian/Ubuntu: sudo apt install jq, macOS: brew install jq)"
  command -v claude >/dev/null || warn "Claude Code not found. Install it: curl -fsSL https://claude.ai/install.sh | bash"

  # 1. key
  mkdir -p "$(dirname "$KEY_FILE")"
  if [ -n "${ZAI_API_KEY:-}" ]; then
    (umask 077; printf '%s' "$ZAI_API_KEY" > "$KEY_FILE")
    say "Saved key from ZAI_API_KEY to $KEY_FILE"
  elif [ -s "$KEY_FILE" ]; then
    say "Using existing key in $KEY_FILE"
  else
    [ -r /dev/tty ] || die "No terminal to ask for the key. Run with ZAI_API_KEY=... set."
    printf 'Paste your z.ai API key (input hidden): ' > /dev/tty
    local key; IFS= read -rs key < /dev/tty; echo > /dev/tty
    key="$(printf '%s' "$key" | tr -d '[:space:]')"
    [ -n "$key" ] || die "No key entered"
    (umask 077; printf '%s' "$key" > "$KEY_FILE")
    say "Saved key to $KEY_FILE"
  fi
  chmod 600 "$KEY_FILE"

  # 2. files: from this clone if we are in one, else from GitHub at $REF
  local src="" here
  # shellcheck disable=SC2015
  here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
  [ -n "$here" ] && [ -f "$here/scripts/claude-z.sh" ] && src="$here"
  stage="$(mktemp -d)"
  trap 'rm -rf "$stage"' EXIT
  for f in $FILES; do
    mkdir -p "$stage/$(dirname "$f")"
    if [ -n "$src" ]; then cp "$src/$f" "$stage/$f"
    else curl -fsSL "https://raw.githubusercontent.com/$REPO/$REF/$f" -o "$stage/$f" || die "Download failed: $f"
    fi
  done
  say "Installing scripts from ${src:-github.com/$REPO@$REF} into $DEST"
  mkdir -p "$DEST/hooks" "$DEST/commands"
  install -m 755 "$stage/scripts/zai-quota.sh" "$stage/scripts/statusline.sh" "$DEST/"
  install -m 644 "$stage/scripts/claude-z.sh" "$DEST/"
  install -m 755 "$stage/scripts/zai-usage-hook.sh" "$DEST/hooks/"
  install -m 644 "$stage/scripts/zai-usage.md" "$DEST/commands/"

  # 3. settings: merge, keeping whatever is already there
  local settings="$DEST/settings.json" tmp; tmp="$(mktemp)"
  [ -s "$settings" ] || echo '{}' > "$settings"
  cp "$settings" "$settings.bak.claude-z"
  jq --slurpfile t "$stage/config/settings.json" '
    $t[0] as $t
    | .permissions.deny = (((.permissions.deny // []) + $t.permissions.deny) | unique)
    | (if (.statusLine == null) or ((.statusLine.command // "") | test("claude-z/statusline"))
       then .statusLine = $t.statusLine else . end)
    | ($t.hooks.UserPromptSubmit[0].hooks[0].command) as $cmd
    | (if ([.hooks.UserPromptSubmit[]?.hooks[]?.command] | index($cmd))
       then . else .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + $t.hooks.UserPromptSubmit) end)
  ' "$settings" > "$tmp" && mv "$tmp" "$settings"
  if ! jq -e '(.statusLine.command // "") | test("claude-z/statusline")' "$settings" >/dev/null; then
    warn "Kept your existing statusLine in $settings; the z.ai quota status line was not enabled"
  fi
  say "Merged settings into $settings (backup: $settings.bak.claude-z)"

  # 4. shell rc block
  for rc in $(rc_files); do
    [ -f "$rc" ] && cp "$rc" "$rc.bak.claude-z"
    strip_block "$rc"
    # start on a fresh line, or the marker gets glued to the file's last line
    if [ -s "$rc" ] && [ -n "$(tail -c1 "$rc")" ]; then echo >> "$rc"; fi
    {
      echo "$MARK_BEGIN"
      echo '# claude-z: Claude Code on z.ai GLM. Managed by github.com/yel-hadd/claude-code-zai (install.sh --uninstall removes it)'
      # shellcheck disable=SC2016
      echo '[ -f "$HOME/.claude-z/claude-z.sh" ] && . "$HOME/.claude-z/claude-z.sh"'
      echo "$MARK_END"
    } >> "$rc"
    say "Added claude-z to $rc"
  done

  # 5. MCP servers (key stays out of the config: ${ZAI_API_KEY} is expanded at runtime)
  if [ "$with_mcp" = 1 ] && command -v claude >/dev/null; then
    # shellcheck disable=SC2016
    local bearer='Authorization: Bearer ${ZAI_API_KEY}' envkey='Z_AI_API_KEY=${ZAI_API_KEY}'
    mcp_exists web-search-prime || zclaude mcp add -s user -t http web-search-prime \
      https://api.z.ai/api/mcp/web_search_prime/mcp --header "$bearer" >/dev/null
    mcp_exists web-reader || zclaude mcp add -s user -t http web-reader \
      https://api.z.ai/api/mcp/web_reader/mcp --header "$bearer" >/dev/null
    mcp_exists zai-mcp-server || zclaude mcp add -s user zai-mcp-server \
      -e "$envkey" -e Z_AI_MODE=ZAI -- npx -y @z_ai/mcp-server@latest >/dev/null
    say "MCP servers ready: $MCP_NAMES"
  fi

  # 6. checks
  if command -v node >/dev/null; then
    local major; major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
    [ "$major" -ge 22 ] || warn "Node.js $major found; the z.ai vision tool needs Node.js 22 or newer"
  else
    warn "Node.js not found; the z.ai vision tool (zai-mcp-server) needs Node.js 22 or newer"
  fi
  say "Quota: $("$DEST/zai-quota.sh" --short)"
  echo
  say "Installed. Open a new terminal (or source your shell rc), then run: claude-z"
  echo "    zai-usage          quota report, no Claude needed"
  echo "    /zai-usage         same report inside claude-z, works even when the quota is used up"
}

"$action"
