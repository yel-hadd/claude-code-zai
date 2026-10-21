# z.ai GLM Coding Plan quota, from https://api.z.ai/api/monitor/usage/quota/limit
# Usage: zai-quota.ps1 [-Mode Short|Full|Json]   (cached 60s in %TEMP%\zai-quota.json)
# https://github.com/yel-hadd/claude-code-zai
param([ValidateSet('Short', 'Full', 'Json')][string]$Mode = 'Short')

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$key = $env:ZAI_API_KEY
$keyFile = Join-Path $HOME '.config/zai/api_key'
if (-not $key -and (Test-Path $keyFile)) { $key = "$(Get-Content $keyFile -Raw)".Trim() }
if (-not $key) { 'z.ai: no key'; return }

$tmpDir = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$cache = Join-Path $tmpDir 'zai-quota.json'
if (-not (Test-Path $cache) -or ((Get-Date) - (Get-Item $cache).LastWriteTime).TotalSeconds -ge 60) {
  try {
    $r = Invoke-RestMethod -Uri 'https://api.z.ai/api/monitor/usage/quota/limit' -TimeoutSec 5 `
      -Headers @{ Authorization = "Bearer $key"; 'Accept-Language' = 'en-US,en' }
    if ($r.success) { $r | ConvertTo-Json -Depth 6 | Set-Content -Path $cache -Encoding UTF8 }
  } catch { }
}
if (-not (Test-Path $cache)) { 'z.ai: quota unavailable'; return }
if ($Mode -eq 'Json') { Get-Content $cache -Raw; return }

$q = Get-Content $cache -Raw | ConvertFrom-Json

# unit 3 = hours, 6 = weeks, 5 = months; nextResetTime is epoch ms
function Format-Reset($limit, $format) {
  [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$limit.nextResetTime).ToLocalTime().ToString($format)
}

if ($Mode -eq 'Short') {
  $parts = foreach ($l in $q.data.limits) {
    if ($l.type -eq 'TIME_LIMIT') { continue }
    $w = switch ($l.unit) { 3 { "$($l.number)h" } 6 { 'wk' } 5 { 'mo' } default { "u$($l.unit)" } }
    $s = "$w $($l.percentage)%"
    if ($l.percentage -ge 80 -and $l.nextResetTime) { $s += ' resets ' + (Format-Reset $l 'ddd HH:mm') }
    $s
  }
  $parts -join ' | '
} else {
  "z.ai plan: $($q.data.level)"
  foreach ($l in $q.data.limits) {
    $w = switch ($l.unit) { 3 { "$($l.number)-hour window" } 6 { 'Weekly' } 5 { 'Monthly' } default { "unit $($l.unit) x$($l.number)" } }
    $used = if ($null -ne $l.currentValue) { $l.currentValue } else { 0 }
    $line = "$w ($($l.type)): $($l.percentage)% used, $used of $($l.usage), $($l.remaining) left"
    if ($l.nextResetTime) { $line += ', resets ' + (Format-Reset $l 'ddd MMM dd HH:mm zzz') }
    $line
  }
}
