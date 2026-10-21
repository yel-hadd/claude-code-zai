#!/usr/bin/env bash
# claude-z status line: model · context used · z.ai quota
# https://github.com/yel-hadd/claude-code-zai
input="$(cat)"
model="$(jq -r '.model.display_name // .model.id // "GLM"' <<<"$input")"
ctx="$(jq -r '.context_window.used_percentage // empty | floor' <<<"$input" 2>/dev/null)"
quota="$("$(dirname "$0")/zai-quota.sh" --short)"
printf '%s' "$model"
[ -n "$ctx" ] && printf ' · ctx %s%%' "$ctx"
printf ' · %s\n' "$quota"
