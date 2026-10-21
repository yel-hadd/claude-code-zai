# claude-z: Claude Code on the z.ai GLM Coding Plan (PowerShell 5.1 and 7).
# Dot-sourced from $PROFILE. Key lives in ~/.config/zai/api_key (owner-only ACL).
# https://github.com/yel-hadd/claude-code-zai

function claude-z {
  $keyFile = Join-Path $HOME '.config\zai\api_key'
  if (-not (Test-Path $keyFile) -or -not "$(Get-Content $keyFile -Raw)".Trim()) {
    Write-Error "claude-z: missing z.ai key in $keyFile"; return
  }
  $key = (Get-Content $keyFile -Raw).Trim()
  $vars = @{
    CLAUDE_CONFIG_DIR                        = Join-Path $HOME '.claude-z'
    ANTHROPIC_BASE_URL                       = 'https://api.z.ai/api/anthropic'
    ANTHROPIC_AUTH_TOKEN                     = $key
    ZAI_API_KEY                              = $key
    API_TIMEOUT_MS                           = '3000000'
    ANTHROPIC_MODEL                          = 'glm-5.3[1m]'
    ANTHROPIC_DEFAULT_OPUS_MODEL             = 'glm-5.3[1m]'
    ANTHROPIC_DEFAULT_SONNET_MODEL           = 'glm-5.3[1m]'
    ANTHROPIC_DEFAULT_HAIKU_MODEL            = 'glm-5.3-flash[1m]'
    CLAUDE_CODE_SUBAGENT_MODEL               = 'glm-5.3[1m]'
    CLAUDE_CODE_AUTO_COMPACT_WINDOW          = '1000000'
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '1'
  }
  $saved = @{}
  foreach ($name in $vars.Keys) {
    $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    [Environment]::SetEnvironmentVariable($name, $vars[$name], 'Process')
  }
  try { claude @args }
  finally {
    foreach ($name in $saved.Keys) {
      [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process')
    }
  }
}

# z.ai quota without starting Claude Code (works even when a limit is exhausted)
function zai-usage {
  & (Join-Path $HOME '.claude-z\zai-quota.ps1') -Mode Full
}
