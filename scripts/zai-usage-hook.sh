#!/usr/bin/env bash
# UserPromptSubmit hook: answer /zai-usage locally, without calling the model,
# so it still works when the z.ai quota is exhausted.
# https://github.com/yel-hadd/claude-code-zai
prompt="$(jq -r '.prompt // empty')"
case "$prompt" in
  /zai-usage|/zai-usage\ *)
    out="$("$(dirname "$0")/../zai-quota.sh" --full 2>&1)"
    jq -n --arg r "$out" '{decision: "block", reason: $r}'
    ;;
esac
exit 0
