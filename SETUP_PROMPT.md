# Setup prompt: Claude Code on z.ai GLM

Copy everything in the box below and paste it into Claude Code (plain `claude`), Cursor, or any coding agent that can run shell commands. The agent installs `claude-z` from [github.com/yel-hadd/claude-code-zai](https://github.com/yel-hadd/claude-code-zai), checks it, and reports back. Have your z.ai GLM Coding Plan API key ready. No plan yet? [Subscribe here](https://z.ai/subscribe?ic=BY27XR8RLD) (referral link, 10% off your first subscription).

````text
Set up "claude-z" on this computer: Claude Code running on the z.ai GLM Coding Plan,
using the installer from https://github.com/yel-hadd/claude-code-zai (tag v1.1.0).

Rules:
- Never print, log, echo, commit or paste my API key anywhere except the key file the
  installer writes (~/.config/zai/api_key). Don't put it in commands that end up in shell
  history: pass it through the installer's hidden prompt, or through an environment
  variable set only for that one command.
- Don't touch my default Claude Code setup (~/.claude or the plain `claude` command).
- The installer backs up the files it changes. Don't edit my shell rc files or PowerShell
  profile by hand.
- If something fails, stop and show me the error. Don't work around it silently.

Steps:
0. Ask whether I already have a z.ai GLM Coding Plan API key. If not, tell me to subscribe at
   https://z.ai/subscribe?ic=BY27XR8RLD (the repo author's referral link: 10% off the first subscription)
   or at https://z.ai/subscribe, create an API key, and come back.
1. Detect my OS and shell. Check that these exist and tell me about anything missing:
   `claude` (Claude Code), `curl`, `jq` on Linux/macOS, and Node.js 22+ (only needed for
   z.ai's vision tool).
2. Ask me to run the installer myself in my terminal, because it asks for my key with
   hidden input. Give me the exact command:
   - Linux/macOS: curl -fsSL https://raw.githubusercontent.com/yel-hadd/claude-code-zai/v1.1.0/install.sh | bash
   - Windows PowerShell: irm https://raw.githubusercontent.com/yel-hadd/claude-code-zai/v1.1.0/install.ps1 | iex
   If you can run interactive commands in my terminal, you may run it yourself instead.
   Wait until I say it finished, then read its output.
3. Verify, in a new shell so the rc file or profile is loaded:
   a. `claude-z mcp list` shows web-search-prime, web-reader and zai-mcp-server as Connected.
   b. `zai-usage` prints my plan level and the 5-hour and weekly limits.
   c. `claude-z -p "Reply with just: ok" --output-format json` returns ok and lists
      "glm-5.3[1m]" with contextWindow 1000000. If it fails with HTTP 429 or error 1310,
      the quota is used up: that's not a setup problem. Report the reset time from
      `zai-usage` and treat this check as pending.
4. Report a short summary: what passed, what's pending or failed, and how to start
   (`claude-z`, `zai-usage`, `/zai-usage`). Mention that `install.sh --uninstall`
   (or `install.ps1 -Uninstall`) removes everything except the key file.
````

## What the installer changes

- `~/.config/zai/api_key`: your key, readable only by you
- `~/.claude-z/`: the `claude-z` scripts, settings, status line and `/zai-usage` hook
- `~/.bashrc`, `~/.zshrc` (or `~/.bash_profile` on macOS with bash), or your PowerShell profile: one marked block that loads `claude-z`, with a `.bak.claude-z` backup
- Claude Code's MCP list for `~/.claude-z` only: z.ai web search, web reader and vision

Nothing else is changed, and `claude` keeps your normal Anthropic login.
