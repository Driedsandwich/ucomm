# Visibility & Risk Report (2025-09-06)

## Repository
- Visibility: (see [repo.json](data/2025-09-06/repo.json))
- Branch protection (main): (see [protection.json](data/2025-09-06/protection.json))
- Pages: (see [pages.json](data/2025-09-06/pages.json))
- Actions permissions: (see [actions-permissions.json](data/2025-09-06/actions-permissions.json))
- Workflows: (see [workflows.json](data/2025-09-06/workflows.json))

## Public維持 + セキュリティ強化決定（2025-09-06最終確定）
- **決定**: Public維持でのセキュリティ強化を採用
- **実装済み強化策**:
  - Branch Protection: 必須ステータスチェック（linkcheck, smoke, label, eol-guard）適用
  - CodeQL: 静的解析による脆弱性検出
  - Dependabot: GitHub Actions自動アップデート
  - JSON Schema: /health エンドポイント機械検証
- **継続的対応**: 週次Dependabotレビュー、月次セキュリティ監査

## Private化 影響要約（参考情報として保持）
- Releases: 認証必須 → 公開ミラー化を推奨
- Pages: 公開範囲の制御に制約 → 公開用サブリポ/除外ビルド
- Actions: fork PR 権限厳格 → workflow_call設計へ移行
- Badges: 外部から不可視 → 代替可視化へ
- コラボ: 招待制 → 公開部分は分離

(注) 詳細データは上記JSONファイルを参照。必要なら次PRで要点抽出の自動整形を追加。
