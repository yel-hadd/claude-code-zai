# claude-z status line (Windows): model | context used | z.ai quota
# https://github.com/yel-hadd/claude-code-zai
try { $in = [Console]::In.ReadToEnd() | ConvertFrom-Json } catch { $in = $null }
$parts = @(@($in.model.display_name) | Where-Object { $_ })
if ($null -ne $in.context_window.used_percentage) {
  $parts += "ctx $([math]::Floor($in.context_window.used_percentage))%"
}
$parts += & (Join-Path $PSScriptRoot 'zai-quota.ps1') -Mode Short
$parts -join ' | '
