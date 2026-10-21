# UserPromptSubmit hook (Windows): answer /zai-usage locally, without calling the model,
# so it still works when the z.ai quota is exhausted.
# https://github.com/yel-hadd/claude-code-zai
try { $in = [Console]::In.ReadToEnd() | ConvertFrom-Json } catch { exit 0 }
if ("$($in.prompt)".Trim() -match '^/zai-usage(\s|$)') {
  $out = (& (Join-Path $PSScriptRoot '../zai-quota.ps1') -Mode Full) -join "`n"
  @{ decision = 'block'; reason = $out } | ConvertTo-Json -Compress
}
exit 0
