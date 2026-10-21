# Changelog

## v1.0.0 (2026-10-21)

First release.

- `claude-z` command for bash, zsh and PowerShell: Claude Code on the z.ai GLM Coding Plan with `glm-5.3[1m]` and a 1M-token context.
- Installers for Linux/macOS (`install.sh`) and Windows (`install.ps1`): idempotent, back up changed files, `--uninstall` / `-Uninstall`.
- z.ai web search, web reader and vision MCP servers, with the key referenced as `${ZAI_API_KEY}`.
- Quota status line, `zai-usage` command, and a `/zai-usage` hook that works when the quota is exhausted.
- Setup prompt for AI coding agents.
