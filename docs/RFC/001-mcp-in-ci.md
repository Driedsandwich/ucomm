# RFC-001: MCP-in-CI (Phase 5 / Issue #13)

## 背景と目的
- ucomm は Phase 4 で MCP を採用し、起動順を **MCP → CLI → 初期投入** に固定している（CIでも検証対象）。[spec/CI要件]  
- Phase 5 では CI に MCP を統合し、read-only最小権限のまま境界検証を自動化する。

## 非機能要件（既定方針の確認）
- Transport: **HTTP/localhost**（stdio/WebSocketは採用しない）。[spec]  
- Profiles: `profiles/mcp/<role>/mcp.json`（default/manager/director/scribe）※全てread-onlyから開始。[profiles]  
- Tools: Filesystem/Git/Fetch は allowlist・read-only。書込み系は将来のSECURE_MODE=1で別RFC。[policy]

## CI統合の段階的プラン
- Stage A（本RFCで実装）: **静的検証**のみ
  - JSON Schemaによるキー/型検証（transport/tools/policy/logging の必須キー）。
  - allowlistパターン検証（例: fetch.allow は `raw.githubusercontent.com/*` など）。
  - 破損/過剰権限は赤で落とす。
- Stage B（後続RFC/PR）: **ローカル参照実装をエフェメラル起動**（npx等）
  - /health相当の200応答確認、CI閾値（≤6000ms）判定。
  - deny系・フォールバックの境界ケースを自動化。
- Stage C（OPTIONAL）: GitHub API（GET系）のread-onlyツールをMCPから呼出し、匿名/トークンあり両系で振る舞い比較（SECURE_MODE=1でfail fast）。

## 失敗時の運用
- MCPが不調なら tmux送信方式にフォールバック継続（exit≠0にしないモードを既定、厳格運用は環境変数で切替）。

## セキュリティ
- logs/mcp 配下への保存時にAPIキー等のマスク（正規表現で遮蔽）。
- .envからのキー注入は最小限、CIシークレットのpermissionsは最小化。

## 受け入れ基準（DoD）
- Stage A: profiles 配下の mcp.json 全ファイルがスキーマ/allowlist検証で green。
- Stage A: 破壊的権限（write/POST等）は検証で赤になることをテストで証明。
- SSOT（HISTORY/INDEX.md）に本RFCの採択・PR・ワークフロー導線を追記。

## 参考
- MCP spec（ucomm採用版 v1.0.0）、Phase 4.3 CIスモーク、mcp.json雛形、フェーズ案(gen7) など。