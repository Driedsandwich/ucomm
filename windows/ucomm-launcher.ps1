param(
  [string]$Mode = "HIERARCHY",
  [string]$Distro = "Ubuntu-24.04"
)

$ErrorActionPreference = "Stop"
$repo = "/mnt/data/ucomm"
$bash = "bash -lc"

# 1) Build sessions inside WSL
wsl.exe -d $Distro --% $bash "cd $repo && MODE=$Mode ./scripts/ucomm-launch.sh"

# 2) Try to open two tabs attached to sessions (best-effort)
try {
  wt -w 0 new-tab --title "ucomm_Director" wsl.exe -d $Distro -- bash -lc "tmux attach -t ucomm_Director" `;
     new-tab --title "ucomm_multiagent" wsl.exe -d $Distro -- bash -lc "tmux attach -t ucomm_multiagent" | Out-Null
} catch {
  Write-Host "[ucomm] wt.exe not available or failed to open tabs. Sessions are running; you can attach manually:"
  Write-Host "  wsl -d $Distro -- bash -lc 'tmux attach -t ucomm_Director'"
  Write-Host "  wsl -d $Distro -- bash -lc 'tmux attach -t ucomm_multiagent'"
}
