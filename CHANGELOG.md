# Changelog

## v1.2.0 (2026-11-06)

- Fix auto mode blocking commands with "safety check is unavailable". Recent Claude Code versions ask Anthropic's servers to review auto mode actions, and z.ai doesn't answer that review. `claude-z` now sets `CLAUDE_CODE_AUTO_MODE_SERVER=0` so Claude Code runs the check itself, and `CLAUDE_CODE_AUTO_MODE_MODEL='glm-5.3[1m]'` to run it on GLM-5.3. Re-run the installer to update.
- Installers now download `v1.2.0`.

## v1.1.0 (2026-10-21)

- Guide site rebuilt as a page for people moving from a Claude subscription to the z.ai GLM Coding Plan: side-by-side comparison, how-to-switch steps, social preview image, favicon.
- README: "Switching from a Claude subscription" section and two new FAQ entries.
- The installers and `claude-z` point people without a plan to a GLM Coding Plan referral link (10% off the first subscription), clearly labelled, with a disclosure in the README and on the site.
- Installers now download `v1.1.0`.

## v1.0.0 (2026-10-21)

First release.

- `claude-z` command for bash, zsh and PowerShell: Claude Code on the z.ai GLM Coding Plan with `glm-5.3[1m]` and a 1M-token context.
- Installers for Linux/macOS (`install.sh`) and Windows (`install.ps1`): idempotent, back up changed files, `--uninstall` / `-Uninstall`.
- z.ai web search, web reader and vision MCP servers, with the key referenced as `${ZAI_API_KEY}`.
- Quota status line, `zai-usage` command, and a `/zai-usage` hook that works when the quota is exhausted.
- Setup prompt for AI coding agents.
