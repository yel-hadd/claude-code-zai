#!/usr/bin/env bash
# z.ai GLM Coding Plan quota, from https://api.z.ai/api/monitor/usage/quota/limit
# Usage: zai-quota.sh [--short|--full|--json]   (cached 60s in ~/.cache/zai-quota.json)
# https://github.com/yel-hadd/claude-code-zai
mode="${1:---short}"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/zai-quota.json"
key="${ZAI_API_KEY:-$(cat "$HOME/.config/zai/api_key" 2>/dev/null)}"
[ -n "$key" ] || { echo "z.ai: no key"; exit 0; }

mkdir -p "$(dirname "$cache")"
if [ ! -s "$cache" ] || [ $(( $(date +%s) - $(stat -c %Y "$cache" 2>/dev/null || stat -f %m "$cache") )) -ge 60 ]; then
  tmp="$cache.$$"
  if curl -s -m 5 https://api.z.ai/api/monitor/usage/quota/limit \
       -H "Authorization: Bearer $key" -H "Accept-Language: en-US,en" -o "$tmp" \
     && jq -e '.success == true' "$tmp" >/dev/null 2>&1; then
    mv "$tmp" "$cache"
  else
    rm -f "$tmp"
  fi
fi
[ -s "$cache" ] || { echo "z.ai: quota unavailable"; exit 0; }

case "$mode" in
  --json) cat "$cache" ;;
  --short)
    # unit 3 = hours, 6 = weeks, 5 = months; nextResetTime is epoch ms
    jq -r '
      def win: if .unit == 3 then "\(.number)h" elif .unit == 6 then "wk" elif .unit == 5 then "mo" else "u\(.unit)" end;
      def reset: if .nextResetTime then " ↻" + ((.nextResetTime / 1000) | strflocaltime("%a %H:%M")) else "" end;
      [.data.limits[] | select(.type != "TIME_LIMIT") | "\(win) \(.percentage)%" + (if .percentage >= 80 then reset else "" end)]
      | join(" · ")' "$cache" ;;
  --full)
    jq -r '
      def win: if .unit == 3 then "\(.number)-hour window" elif .unit == 6 then "Weekly" elif .unit == 5 then "Monthly" else "unit \(.unit) x\(.number)" end;
      "z.ai plan: \(.data.level)",
      (.data.limits[] |
        "\(win) (\(.type)): \(.percentage)% used, \(.currentValue // 0) of \(.usage // "?"), \(.remaining // "?") left" +
        (if .nextResetTime then ", resets \((.nextResetTime / 1000) | strflocaltime("%a %b %d %H:%M %Z"))" else "" end))' "$cache" ;;
esac
