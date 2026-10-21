# claude-code-zai installer for Windows (PowerShell 5.1 and 7).
# Sets up `claude-z`: Claude Code on the z.ai GLM Coding Plan, with z.ai web search,
# web reader and vision MCP tools, a quota status line and /zai-usage.
#
#   irm https://raw.githubusercontent.com/yel-hadd/claude-code-zai/v1.0.0/install.ps1 | iex
#   .\install.ps1 [-NoMcp] [-Ref TAG] | -Uninstall [-Purge]
#   & ([scriptblock]::Create((irm <url>))) -Uninstall      # options when piping
#
# Non-interactive: $env:ZAI_API_KEY = '...'; .\install.ps1
# https://github.com/yel-hadd/claude-code-zai
param(
  [switch]$Uninstall,
  [switch]$Purge,
  [switch]$NoMcp,
  [string]$Ref = 'v1.0.0'
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$Repo = 'yel-hadd/claude-code-zai'
$Dest = Join-Path $HOME '.claude-z'
$KeyFile = Join-Path $HOME '.config/zai/api_key'
$MarkBegin = '# >>> claude-z >>>'
$MarkEnd = '# <<< claude-z <<<'
$McpNames = 'web-search-prime', 'web-reader', 'zai-mcp-server'
$OnWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or $IsWindows
$PsExe = if ($OnWindows) { 'powershell' } else { 'pwsh' }
$Files = @(
  @{ Src = 'scripts/claude-z.ps1';       Dst = 'claude-z.ps1' },
  @{ Src = 'scripts/zai-quota.ps1';      Dst = 'zai-quota.ps1' },
  @{ Src = 'scripts/statusline.ps1';     Dst = 'statusline.ps1' },
  @{ Src = 'scripts/zai-usage-hook.ps1'; Dst = 'hooks/zai-usage-hook.ps1' },
  @{ Src = 'scripts/zai-usage.md';       Dst = 'commands/zai-usage.md' }
)

function Say($m) { Write-Host "==> $m" }
function Warn($m) { Write-Warning $m }

# Forward-slash absolute path: works whichever shell Claude Code uses to run commands
function Fwd($p) { $p -replace '\\', '/' }
$StatusCmd = "$PsExe -NoProfile -ExecutionPolicy Bypass -File $(Fwd (Join-Path $Dest 'statusline.ps1'))"
$HookCmd = "$PsExe -NoProfile -ExecutionPolicy Bypass -File $(Fwd (Join-Path $Dest 'hooks/zai-usage-hook.ps1'))"

function Get-ProfilePaths {
  if ($OnWindows) {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    @((Join-Path $docs 'WindowsPowerShell/profile.ps1'), (Join-Path $docs 'PowerShell/profile.ps1'))
  } else {
    @($PROFILE.CurrentUserAllHosts)
  }
}

function Remove-Block($path) {
  if (-not (Test-Path $path)) { return $false }
  $lines = @(Get-Content $path)
  if ($lines -notcontains $MarkBegin) { return $false }
  $out = New-Object System.Collections.Generic.List[string]
  $skip = $false
  foreach ($l in $lines) {
    if ($l -eq $MarkBegin) { $skip = $true; continue }
    if ($l -eq $MarkEnd) { $skip = $false; continue }
    if (-not $skip) { $out.Add($l) }
  }
  Set-Content -Path $path -Value $out
  return $true
}

function Invoke-ZClaude {
  $old = $env:CLAUDE_CONFIG_DIR
  $env:CLAUDE_CONFIG_DIR = $Dest
  try { & claude @args 2>&1 | Out-Null } finally { $env:CLAUDE_CONFIG_DIR = $old }
}

function Test-Mcp($name) {
  $f = Join-Path $Dest '.claude.json'
  if (-not (Test-Path $f)) { return $false }
  $j = Get-Content $f -Raw | ConvertFrom-Json
  return [bool]($j.mcpServers -and $j.mcpServers.PSObject.Properties[$name])
}

function Read-Settings {
  $f = Join-Path $Dest 'settings.json'
  if ((Test-Path $f) -and "$(Get-Content $f -Raw)".Trim()) { return (Get-Content $f -Raw | ConvertFrom-Json) }
  return [pscustomobject]@{}
}

function Write-Settings($obj) {
  # UTF-8 without BOM: Windows PowerShell 5.1's -Encoding UTF8 adds one, which JSON parsers may reject
  $json = $obj | ConvertTo-Json -Depth 20
  [IO.File]::WriteAllText((Join-Path $Dest 'settings.json'), $json, (New-Object Text.UTF8Encoding $false))
}

function Set-Prop($obj, $name, $value) {
  if ($obj.PSObject.Properties[$name]) { $obj.$name = $value }
  else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}

function Test-OurHookEntry($entry) {
  foreach ($h in @($entry.hooks)) { if ("$($h.command)" -match 'zai-usage-hook') { return $true } }
  return $false
}

function Invoke-Uninstall {
  Say 'Removing claude-z'
  foreach ($p in Get-ProfilePaths) { if (Remove-Block $p) { Say "Cleaned $p" } }
  if (Get-Command claude -ErrorAction SilentlyContinue) {
    foreach ($n in $McpNames) { if (Test-Mcp $n) { Invoke-ZClaude mcp remove -s user $n; Say "Removed MCP server $n" } }
  }
  if (Test-Path (Join-Path $Dest 'settings.json')) {
    $s = Read-Settings
    if ($s.statusLine -and "$($s.statusLine.command)" -match 'claude-z[\\/]statusline') { $s.PSObject.Properties.Remove('statusLine') }
    if ($s.hooks -and $s.hooks.UserPromptSubmit) {
      $kept = @($s.hooks.UserPromptSubmit | Where-Object { -not (Test-OurHookEntry $_) })
      if ($kept.Count) { $s.hooks.UserPromptSubmit = $kept } else { $s.hooks.PSObject.Properties.Remove('UserPromptSubmit') }
      if (-not @($s.hooks.PSObject.Properties).Count) { $s.PSObject.Properties.Remove('hooks') }
    }
    if ($s.permissions -and $s.permissions.deny) { $s.permissions.deny = @($s.permissions.deny | Where-Object { $_ -ne 'WebSearch' }) }
    Write-Settings $s
    Say "Cleaned $(Join-Path $Dest 'settings.json')"
  }
  foreach ($f in $Files) { Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $Dest $f.Dst) }
  $tmpDir = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
  Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $tmpDir 'zai-quota.json')
  if ($Purge) { Remove-Item -Force -ErrorAction SilentlyContinue $KeyFile; Say "Deleted $KeyFile" }
  else { Say "Kept your key in $KeyFile (use -Purge to delete it)" }
  Say "Done. $Dest is kept because it holds your claude-z history and settings."
}

function Invoke-Install {
  if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Warn 'Claude Code not found. Install it: irm https://claude.ai/install.ps1 | iex'
  }

  # 1. key
  New-Item -ItemType Directory -Force (Split-Path $KeyFile) | Out-Null
  if ($env:ZAI_API_KEY) {
    Set-Content -Path $KeyFile -Value $env:ZAI_API_KEY.Trim() -NoNewline
    Say "Saved key from ZAI_API_KEY to $KeyFile"
  } elseif ((Test-Path $KeyFile) -and "$(Get-Content $KeyFile -Raw)".Trim()) {
    Say "Using existing key in $KeyFile"
  } else {
    $sec = Read-Host 'Paste your z.ai API key (input hidden)' -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    $key = ($key -replace '\s', '')
    if (-not $key) { throw 'No key entered' }
    Set-Content -Path $KeyFile -Value $key -NoNewline
    Say "Saved key to $KeyFile"
  }
  if ($OnWindows) { icacls $KeyFile /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null }
  else { chmod 600 $KeyFile }

  # 2. files: from this clone if we are in one, else from GitHub at $Ref
  $src = if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'scripts/claude-z.ps1'))) { $PSScriptRoot } else { $null }
  Say "Installing scripts from $(if ($src) { $src } else { "github.com/$Repo@$Ref" }) into $Dest"
  foreach ($f in $Files) {
    $target = Join-Path $Dest $f.Dst
    New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
    if ($src) { Copy-Item -Force (Join-Path $src $f.Src) $target }
    else { Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/$Repo/$Ref/$($f.Src)" -OutFile $target }
    if ($OnWindows) { Unblock-File $target }
  }

  # 3. settings: merge, keeping whatever is already there
  $settingsFile = Join-Path $Dest 'settings.json'
  if (Test-Path $settingsFile) { Copy-Item -Force $settingsFile "$settingsFile.bak.claude-z" }
  $s = Read-Settings
  if (-not $s.permissions) { Set-Prop $s 'permissions' ([pscustomobject]@{}) }
  Set-Prop $s.permissions 'deny' (@(@($s.permissions.deny) + 'WebSearch' | Where-Object { $_ } | Select-Object -Unique))
  if (-not $s.statusLine -or "$($s.statusLine.command)" -match 'claude-z[\\/]statusline') {
    Set-Prop $s 'statusLine' ([pscustomobject]@{ type = 'command'; command = $StatusCmd; padding = 0 })
  } else {
    Warn "Kept your existing statusLine in $settingsFile; the z.ai quota status line was not enabled"
  }
  if (-not $s.hooks) { Set-Prop $s 'hooks' ([pscustomobject]@{}) }
  $ups = @($s.hooks.UserPromptSubmit | Where-Object { $_ })
  if (-not ($ups | Where-Object { Test-OurHookEntry $_ })) {
    $ups += [pscustomobject]@{ hooks = @([pscustomobject]@{ type = 'command'; command = $HookCmd; timeout = 15 }) }
  }
  Set-Prop $s.hooks 'UserPromptSubmit' $ups
  Write-Settings $s
  Say "Merged settings into $settingsFile"

  # 4. profile block
  foreach ($p in Get-ProfilePaths) {
    New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null
    if (Test-Path $p) { Copy-Item -Force $p "$p.bak.claude-z"; Remove-Block $p | Out-Null }
    # start on a fresh line, or the marker gets glued to the file's last line
    if ((Test-Path $p) -and ($raw = [IO.File]::ReadAllText($p)) -and -not $raw.EndsWith("`n")) { Add-Content -Path $p -Value '' }
    Add-Content -Path $p -Value @(
      $MarkBegin,
      '# claude-z: Claude Code on z.ai GLM. Managed by github.com/yel-hadd/claude-code-zai (install.ps1 -Uninstall removes it)',
      '$czScript = Join-Path $HOME ''.claude-z/claude-z.ps1''; if (Test-Path $czScript) { . $czScript }; Remove-Variable czScript',
      $MarkEnd
    )
    Say "Added claude-z to $p"
  }
  if ($OnWindows -and (Get-ExecutionPolicy) -in 'Restricted', 'AllSigned') {
    Warn 'PowerShell blocks profile scripts here. Run once: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
  }

  # 5. MCP servers (key stays out of the config: ${ZAI_API_KEY} is expanded at runtime)
  if (-not $NoMcp -and (Get-Command claude -ErrorAction SilentlyContinue)) {
    $bearer = 'Authorization: Bearer ${ZAI_API_KEY}'
    if (-not (Test-Mcp 'web-search-prime')) {
      Invoke-ZClaude mcp add -s user -t http web-search-prime https://api.z.ai/api/mcp/web_search_prime/mcp --header $bearer
    }
    if (-not (Test-Mcp 'web-reader')) {
      Invoke-ZClaude mcp add -s user -t http web-reader https://api.z.ai/api/mcp/web_reader/mcp --header $bearer
    }
    if (-not (Test-Mcp 'zai-mcp-server')) {
      $launch = if ($OnWindows) { @('cmd', '/c', 'npx') } else { @('npx') }
      $mcpArgs = @('mcp', 'add', '-s', 'user', 'zai-mcp-server', '-e', 'Z_AI_API_KEY=${ZAI_API_KEY}', '-e', 'Z_AI_MODE=ZAI', '--') +
        $launch + @('-y', '@z_ai/mcp-server@latest')
      Invoke-ZClaude @mcpArgs
    }
    Say "MCP servers ready: $($McpNames -join ', ')"
  }

  # 6. checks
  if (Get-Command node -ErrorAction SilentlyContinue) {
    $major = [int]((node -p "process.versions.node.split('.')[0]") 2>$null)
    if ($major -lt 22) { Warn "Node.js $major found; the z.ai vision tool needs Node.js 22 or newer" }
  } else {
    Warn 'Node.js not found; the z.ai vision tool (zai-mcp-server) needs Node.js 22 or newer'
  }
  Say "Quota: $(& (Join-Path $Dest 'zai-quota.ps1') -Mode Short)"
  Write-Host ''
  Say 'Installed. Open a new PowerShell window, then run: claude-z'
  Write-Host '    zai-usage          quota report, no Claude needed'
  Write-Host '    /zai-usage         same report inside claude-z, works even when the quota is used up'
}

if ($Uninstall) { Invoke-Uninstall } else { Invoke-Install }
