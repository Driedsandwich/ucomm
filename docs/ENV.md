# docs/ENV.md — 環境変数セットアップ（追補）

## CLI コマンドの確定値（Phase 4 現行）
- **Gemini CLI**: `gemini`
- **Codex CLI**: `codex`
- **Claude Code**: `claude`

> 旧表記（claudecode / codex-cli / cursor[-cli] 等）は **使用しません**。  
> `config/cli_adapters.yaml` と `config/topology.yaml` の `cli` は上記 3 種のいずれかに限定します。

## 導入確認
```bash
which gemini || echo "gemini not found"
which codex  || echo "codex not found"
which claude || echo "claude not found"
