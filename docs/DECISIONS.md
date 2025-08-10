# DECISIONS.md — Phase 0 Baseline
Updated: 2025-08-10T04:48:22.474530

## Naming & Topology (Baseline, Windows priority)
- Sessions (Windows): `ucomm_Director`, `ucomm_multiagent`  # two-session model for stability
- Sessions (Mac/Linux): allowed to consolidate to a single session (to be confirmed in Phase 1)
- Window names: `director`, `team`
- Roles: `Director`, `Manager`, `Specialist1`, `Specialist2`, `Specialist3`
- Pane titles: "👑 Director", "🐙 Manager", "🧱 Specialist1", "🧱 Specialist2", "🧱 Specialist3"

## Operating Principles
- **Do not expose CLI names or pane numbers to the operator** (non-engineer friendly).
- **One-command launch** from PowerShell (Windows) or bash (Mac/Linux).
- Topology & role resolution **must be driven by `config/topology.yaml`**.
- `send.sh` resolves **role -> tmux target** via YAML; supports `--to`, `--broadcast`, and `--resend`.

## Mode Handling
- Modes: `HIERARCHY`, `COUNCIL`
- Priority of mode resolution: CLI arg `--mode` > env `MODE` > `config/topology.yaml:modes.active`.

## Windows vs. Mac/Linux
- Windows: **two tmux sessions** (Director / multiagent) in separate tabs to avoid focus/switch issues.
- Mac/Linux: `select-window` workflow acceptable; single session is allowed (subject to Phase 1 test).

## Prompts (instructions)
- Use role-based markdown prompts placed under `prompts/`.
- **Content is shared among CLIs**, while **injection/loading is CLI-specific** (adapters in later phases).
- Additional mode-specific prompts will be created in Phase 3 as `Specialist_hierarchy.md` and `Specialist_council.md`.

## File Layout
- Repository root: `/mnt/data/ucomm`
- Subdirs: `scripts/`, `config/`, `prompts/`, `windows/`, `logs/`, `docs/`

## Out-of-Scope (Phase 0)
- No dynamic mode switching; no GUI; no auto pane re-creation; no adapter-specific CLI loading yet.
