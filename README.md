# Claude Code with z.ai GLM-5.3: setup for Linux, macOS and Windows

[![CI](https://github.com/yel-hadd/claude-code-zai/actions/workflows/ci.yml/badge.svg)](https://github.com/yel-hadd/claude-code-zai/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Run [Claude Code](https://code.claude.com/docs) on the [z.ai GLM Coding Plan](https://docs.z.ai/devpack/overview) with one command. You get a separate `claude-z` command that uses GLM-5.3 with its full 1M-token context, z.ai's web search, web reader and vision tools, and a status line showing your 5-hour and weekly quota. Your normal `claude` login stays untouched.

No GLM Coding Plan yet? [Get 10% off your first subscription](https://z.ai/subscribe?ic=BY27XR8RLD) (referral link, see the [disclosure](#referral-disclosure)).

Last updated October 21, 2026. The full guide is at [yel-hadd.github.io/claude-code-zai](https://yel-hadd.github.io/claude-code-zai/). This project isn't affiliated with Anthropic or Z.ai.

```
glm-5.3[1m] · ctx 12% · 5h 0% · wk 100% ↻Thu 20:47
```

## Quick start

You need a GLM Coding Plan API key ([subscribe here](https://z.ai/subscribe?ic=BY27XR8RLD), referral link), [Claude Code](https://code.claude.com/docs/en/setup), and `jq` on Linux/macOS. Node.js 22+ is only needed for the vision tool.

**Linux and macOS**

```bash
curl -fsSL https://raw.githubusercontent.com/yel-hadd/claude-code-zai/v1.1.0/install.sh | bash
```

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/yel-hadd/claude-code-zai/v1.1.0/install.ps1 | iex
```

The installer asks for your key without showing it on screen. When it finishes, open a new terminal and run `claude-z`. Prefer to let an AI agent do it? Paste [SETUP_PROMPT.md](SETUP_PROMPT.md) into Claude Code, Cursor or any coding agent.

Re-running the installer is safe: it updates files and never duplicates anything. To remove it, run `install.sh --uninstall` or `install.ps1 -Uninstall` (your key is kept unless you add `--purge` / `-Purge`).

## What you get

| Piece | What it does |
| --- | --- |
| `claude-z` command | Starts Claude Code against z.ai with GLM-5.3 and a separate config folder (`~/.claude-z`) |
| 1M context | Uses the `glm-5.3[1m]` model names, so Claude Code knows the real context size |
| Web search + reader | z.ai's MCP servers replace Claude Code's built-in web search, which can't run through z.ai |
| Vision | z.ai's image MCP server for screenshots and images |
| Quota status line | Model, context used, 5-hour and weekly quota, reset time in your local time zone |
| `zai-usage` | Full quota report in your terminal, without starting Claude Code |
| `/zai-usage` | Same report inside a session; works even when the quota is used up |

Your API key is stored in `~/.config/zai/api_key`, readable only by you. Config files reference it as `${ZAI_API_KEY}` and never contain the key itself.

## Switching from a Claude subscription

You don't have to choose: `claude` keeps your Claude Pro or Max subscription, and `claude-z` runs the same Claude Code on z.ai. Try both on the same project, then decide which subscription you need.

| | `claude` on a Claude subscription | `claude-z` on the GLM Coding Plan |
| --- | --- | --- |
| Models | Claude (Opus, Sonnet, Haiku) | GLM-5.3 and GLM-5.3-Flash |
| Context in Claude Code | Depends on model and plan | 1M tokens with `glm-5.3[1m]` |
| Usage limits | Session and weekly limits | 5-hour and weekly credit limits, shown in the status line |
| Web search | Built-in WebSearch | z.ai web search and web reader MCP (1.2 credits per call) |
| Images | Built-in | z.ai vision MCP |
| Other apps | Claude on web, desktop and mobile | Claude Code, Cline and [other supported coding tools](https://docs.z.ai/devpack/tool/others) |
| Who processes your code | Anthropic | Z.ai: read their terms and privacy policy first |

To switch:

1. [Subscribe to the GLM Coding Plan](https://z.ai/subscribe?ic=BY27XR8RLD) (referral link, 10% off your first subscription) and create an API key.
2. Run the one-line installer above and paste the key.
3. Open a new terminal and run `claude-z` in your project.

GLM-5.3 is a different model from Claude, so results will differ. Run your usual tasks through both before you cancel anything. z.ai's FAQ says Coding Plan subscriptions are non-refundable once purchased.

## The settings

These are the environment variables `claude-z` sets. They are the same on every OS.

| Variable | Value | Why |
| --- | --- | --- |
| `ANTHROPIC_BASE_URL` | `https://api.z.ai/api/anthropic` | z.ai's Anthropic-compatible endpoint |
| `ANTHROPIC_AUTH_TOKEN` | your z.ai API key | Read from the key file at launch |
| `ANTHROPIC_MODEL` | `glm-5.3[1m]` | Main model |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | `glm-5.3[1m]` | Used when you pick Opus in `/model` |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | `glm-5.3[1m]` | Used when you pick Sonnet in `/model` |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | `glm-5.3-flash[1m]` | Fast model for background jobs |
| `CLAUDE_CODE_SUBAGENT_MODEL` | `glm-5.3[1m]` | Model for subagents |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | `1000000` | Compact near 1M tokens, not 200k |
| `API_TIMEOUT_MS` | `3000000` | 50-minute timeout for long responses |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | `1` | No telemetry or update checks to Anthropic |
| `CLAUDE_CONFIG_DIR` | `~/.claude-z` | Separate settings, history and MCP list |

The base URL, timeout, model names and auto-compact window come from [z.ai's Claude Code guide](https://docs.z.ai/devpack/tool/claude).

## Manual setup

If you'd rather not run an installer, this is the core of what it installs. The full guide, with every script, is at [yel-hadd.github.io/claude-code-zai](https://yel-hadd.github.io/claude-code-zai/).

<details>
<summary><b>Linux and macOS:</b> <code>~/.claude-z/claude-z.sh</code>, sourced from <code>~/.bashrc</code> or <code>~/.zshrc</code></summary>

<!-- BEGIN:scripts/claude-z.sh -->
```bash
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
```
<!-- END:scripts/claude-z.sh -->
</details>

<details>
<summary><b>Windows:</b> <code>~/.claude-z/claude-z.ps1</code>, dot-sourced from your PowerShell profile</summary>

<!-- BEGIN:scripts/claude-z.ps1 -->
```powershell
# claude-z: Claude Code on the z.ai GLM Coding Plan (PowerShell 5.1 and 7).
# Dot-sourced from $PROFILE. Key lives in ~/.config/zai/api_key (owner-only ACL).
# https://github.com/yel-hadd/claude-code-zai
# No GLM Coding Plan yet? https://z.ai/subscribe?ic=BY27XR8RLD (referral link, 10% off your first subscription)

function claude-z {
  $keyFile = Join-Path $HOME '.config\zai\api_key'
  if (-not (Test-Path $keyFile) -or -not "$(Get-Content $keyFile -Raw)".Trim()) {
    Write-Host "No GLM Coding Plan yet? https://z.ai/subscribe?ic=BY27XR8RLD (referral link, 10% off your first subscription)"
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
```
<!-- END:scripts/claude-z.ps1 -->
</details>

<details>
<summary><b>Settings:</b> <code>~/.claude-z/settings.json</code> (Linux/macOS paths)</summary>

<!-- BEGIN:config/settings.json -->
```json
{
  "permissions": {
    "deny": ["WebSearch"]
  },
  "statusLine": {
    "type": "command",
    "command": "~/.claude-z/statusline.sh",
    "padding": 0
  },
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "~/.claude-z/hooks/zai-usage-hook.sh", "timeout": 15 }
        ]
      }
    ]
  }
}
```
<!-- END:config/settings.json -->
</details>

Then add the z.ai tools. Keep the single quotes: they keep `${ZAI_API_KEY}` as literal text, which Claude Code fills in at startup.

```bash
claude-z mcp add -s user -t http web-search-prime https://api.z.ai/api/mcp/web_search_prime/mcp --header 'Authorization: Bearer ${ZAI_API_KEY}'
claude-z mcp add -s user -t http web-reader https://api.z.ai/api/mcp/web_reader/mcp --header 'Authorization: Bearer ${ZAI_API_KEY}'
claude-z mcp add -s user zai-mcp-server -e 'Z_AI_API_KEY=${ZAI_API_KEY}' -e Z_AI_MODE=ZAI -- npx -y @z_ai/mcp-server@latest
```

In PowerShell, write the separator as `'--'` and use `cmd /c npx` for the last one. PowerShell silently drops a bare `--`.

## FAQ

### Should I switch from a Claude subscription to the z.ai GLM Coding Plan?
Try it before deciding. `claude-z` runs alongside your normal `claude`, so you can give both the same tasks and compare. The main differences are the model (GLM-5.3 instead of Claude), the usage limits, and who processes your code. Everything else in Claude Code works the same.

### How do I get a GLM Coding Plan?
Subscribe on z.ai, then create an API key in your account. If you sign up through an invite link such as [this referral link](https://z.ai/subscribe?ic=BY27XR8RLD), z.ai's campaign rules (October 2026) give new subscribers 10% off their first GLM Coding Plan order.

### Can I use Claude Code without a Claude subscription?
Yes. Claude Code can talk to any Anthropic-compatible endpoint, and z.ai runs one at `https://api.z.ai/api/anthropic`. With a GLM Coding Plan API key, `claude-z` runs Claude Code on GLM-5.3 instead of Claude. You still need Claude Code installed, but not an Anthropic account.

### How do I use Claude Code with z.ai?
Point Claude Code at z.ai's Anthropic-compatible endpoint, `https://api.z.ai/api/anthropic`, and pass your GLM Coding Plan key as `ANTHROPIC_AUTH_TOKEN`. This repo wraps those settings in a `claude-z` command so they only apply when you want them, and your normal Claude Code login keeps working.

### Why does Claude Code say "Model glm-5.3 isn't recognized · context assumed to be 200k tokens"?
Claude Code doesn't know GLM's context size. Use the model names with the `[1m]` suffix (`glm-5.3[1m]`, `glm-5.3-flash[1m]`) and set `CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000`. Claude Code then reports a 1,000,000-token context window. If it says the `[1m]` model doesn't exist, run `claude update`.

### Does GLM-5.3 get the full 1M context in Claude Code?
Yes, with the `[1m]` model names. Tested on Claude Code 2.1.301 and later, which report `contextWindow: 1000000` for `glm-5.3[1m]`. Without the suffix, Claude Code assumes 200k and compacts the conversation far too early.

### How do I check my z.ai GLM Coding Plan quota?
Three ways: the status line at the bottom of `claude-z`, the `zai-usage` command in any terminal, and `/zai-usage` inside a session. All three read z.ai's quota endpoint, `https://api.z.ai/api/monitor/usage/quota/limit`, and show the 5-hour and weekly credit limits with reset times in your local time zone. That endpoint isn't in z.ai's public docs. On my Pro plan in October 2026 it reported 12,000 credits per 5-hour window and 60,000 per week.

### How do I check quota when the limit is already used up?
Use `zai-usage` in a terminal, or `/zai-usage` inside `claude-z`. A normal slash command would fail, because it sends its output to the model, and the model is what's blocked. This repo's `/zai-usage` is answered by a local `UserPromptSubmit` hook instead, so it never calls the API.

### What does error 1310 "Weekly/Monthly Limit Exhausted" mean?
Your plan's weekly credit limit is used up, and z.ai returns HTTP 429 until it resets. Claude Code may retry for a while, which looks like a hang. The reset time in z.ai's message is China Standard Time (UTC+8). `zai-usage` shows the same reset time converted to your local time.

### Does web search work in Claude Code with z.ai?
Not the built-in one: Claude Code's WebSearch tool runs on Anthropic's servers. This setup blocks it and adds z.ai's `web-search-prime` and `web-reader` MCP servers instead. z.ai charges 1.2 credits per search or page read, according to its [plan overview](https://docs.z.ai/devpack/overview).

### Can I keep my Anthropic Claude subscription alongside z.ai?
Yes. `claude` keeps using your Anthropic login and `~/.claude`. `claude-z` uses z.ai and its own `~/.claude-z` folder, with separate settings, history and MCP servers. Nothing is shared between them.

### Where is my z.ai API key stored?
In `~/.config/zai/api_key`, with permissions limited to your user (`chmod 600` on Linux/macOS, an owner-only ACL on Windows). `claude-z` reads it at launch and passes it to Claude Code and the z.ai tools as environment variables. The MCP config only contains the `${ZAI_API_KEY}` placeholder.

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `Model "glm-5.3" isn't recognized` | Model names lack `[1m]` | Use the `[1m]` names; run `claude update` if they're rejected |
| zsh: `no matches found: glm-5.3[1m]` | Unquoted square brackets | Quote the model name |
| 401 or authentication error | Wrong key, or `ANTHROPIC_API_KEY` also set | Re-run the installer with the right key; unset `ANTHROPIC_API_KEY` |
| Seems to hang, or 429 `[1310]` | Plan limit used up | Run `zai-usage` to see when it resets |
| Web search fails | Built-in search can't run through z.ai | Use the z.ai MCP tools (the installer adds them) |
| MCP server *Failed to connect* | Started without `claude-z`, Node.js < 22, or missing `cmd /c` on Windows | Start with `claude-z`; upgrade Node.js |
| Status line says `quota unavailable` | Network, `jq` missing, or empty key file | Run `~/.claude-z/zai-quota.sh --json` to see the raw reply |
| PowerShell: "running scripts is disabled" | Execution policy | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |

## What has been tested

| | Linux | macOS | Windows |
| --- | --- | --- | --- |
| Installer: install, re-run, uninstall | ✅ by hand and in CI | ✅ in CI (built-in bash 3.2) | ✅ in CI (PowerShell 5.1 and 7, incl. `icacls`) |
| `claude-z`, `zai-usage`, `/zai-usage` hook, status line scripts | ✅ by hand and in CI | ✅ in CI | ✅ in CI |
| Live Claude Code session: status line, `/zai-usage`, MCP connected | ✅ Fedora, bash | Not run | ✅ PowerShell 7 (on Linux) |
| z.ai vision tool via `cmd /c npx` | | | Not run |

CI runs every installer on GitHub's Ubuntu, macOS and Windows machines with a dummy key and without Claude Code, so it covers the installers and scripts but not a live z.ai session. Live sessions were tested with Claude Code 2.1.301–2.1.305 and a GLM Coding Plan Pro account in October 2026. zsh hasn't been tested. Reports from real Macs and Windows machines are welcome in [issues](https://github.com/yel-hadd/claude-code-zai/issues).

## Sources

- [z.ai: Claude Code setup](https://docs.z.ai/devpack/tool/claude): base URL, timeout, `[1m]` model names, auto-compact window
- [z.ai: GLM Coding Plan overview](https://docs.z.ai/devpack/overview): models, MCP tools and credit costs
- [z.ai: Vision MCP server](https://docs.z.ai/devpack/mcp/vision-mcp-server), [Web Search MCP](https://docs.z.ai/devpack/mcp/search-mcp-server), [Web Reader MCP](https://docs.z.ai/devpack/mcp/reader-mcp-server)
- [Claude Code docs: settings, status line and hooks](https://code.claude.com/docs)

## Referral disclosure

The GLM Coding Plan links in this repo (https://z.ai/subscribe?ic=BY27XR8RLD) are the author's referral link. If you subscribe through it, z.ai gives you 10% off your first subscription and gives the author z.ai credits, according to [z.ai's campaign rules](https://docs.z.ai/devpack/credit-campaign-rules) as of October 2026. It costs you nothing extra. Plain link without referral: [z.ai/subscribe](https://z.ai/subscribe).

## License

[MIT](LICENSE). Claude and Claude Code are trademarks of Anthropic. GLM and the GLM Coding Plan are products of Z.ai (Zhipu AI). This project is independent and not endorsed by either.
