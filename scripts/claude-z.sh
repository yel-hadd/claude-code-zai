# claude-z: Claude Code on the z.ai GLM Coding Plan (bash and zsh).
# Sourced from ~/.bashrc or ~/.zshrc. Key lives in ~/.config/zai/api_key (chmod 600).
# https://github.com/yel-hadd/claude-code-zai
# No GLM Coding Plan yet? https://z.ai/subscribe?ic=BY27XR8RLD (referral link, 10% off your first subscription)

unalias claude-z zai-usage 2>/dev/null

function claude-z {
  local key_file="$HOME/.config/zai/api_key"
  if [ ! -s "$key_file" ]; then
    echo "claude-z: missing z.ai key in $key_file" >&2
    echo "No GLM Coding Plan yet? https://z.ai/subscribe?ic=BY27XR8RLD (referral link, 10% off your first subscription)" >&2
    return 1
  fi
  local key; key="$(cat "$key_file")"
  CLAUDE_CONFIG_DIR="$HOME/.claude-z" \
  ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic" \
  ANTHROPIC_AUTH_TOKEN="$key" \
  ZAI_API_KEY="$key" \
  API_TIMEOUT_MS=3000000 \
  ANTHROPIC_MODEL='glm-5.3[1m]' \
  ANTHROPIC_DEFAULT_OPUS_MODEL='glm-5.3[1m]' \
  ANTHROPIC_DEFAULT_SONNET_MODEL='glm-5.3[1m]' \
  ANTHROPIC_DEFAULT_HAIKU_MODEL='glm-5.3-flash[1m]' \
  CLAUDE_CODE_SUBAGENT_MODEL='glm-5.3[1m]' \
  CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000 \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    claude "$@"
}

# z.ai quota without starting Claude Code (works even when a limit is exhausted)
function zai-usage {
  "$HOME/.claude-z/zai-quota.sh" --full
}
