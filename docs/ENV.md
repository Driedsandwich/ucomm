# ENV.md — Baseline environment record

> Fill actual values on your machine. These are placeholders to ensure reproducibility.

## Platforms
- Primary: Windows 11 + WSL2 (Ubuntu 24.04 LTS), Windows Terminal (wt.exe)
- Secondary: macOS / Linux (tested later in Phase 1)

## Dependencies (expected)
- tmux:    `tmux -V` -> e.g., tmux 3.3a+
- yq:      `yq --version` -> e.g., yq 4.x
- wt.exe:  Windows Terminal 1.20+ (Windows only)
- PowerShell: 7.x recommended

## Verification Commands (to run on your machine)
```powershell
# Windows PowerShell
wt -v
wsl --status
wsl -d Ubuntu-24.04 -- bash -lc "tmux -V && yq --version"
```

```bash
# Inside WSL/macOS/Linux
tmux -V
yq --version
```

## Paths (suggested)
- Repo root: `/mnt/data/ucomm` (this workspace)
- Prompts:   `/mnt/data/ucomm/prompts`
- Scripts:   `/mnt/data/ucomm/scripts`
- Config:    `/mnt/data/ucomm/config`

## CLI commands (to be confirmed in later phases)
- gemini: `gemini --chat`
- codex:  `codex-cli --interactive`
- claude: `ccc --session`
- cursor: `cursor-cli --repl`
