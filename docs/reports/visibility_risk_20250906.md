# Visibility & Risk Report (2025-09-06)

## Repository
- Visibility: (see /tmp/repo.json)
- Branch protection (main): (see /tmp/protection.json)
- Pages: (see /tmp/pages.json)
- Actions permissions: (see /tmp/actions-permissions.json)
- Workflows: (see /tmp/workflows.json)

## Private化 影響要約と推奨
- Releases: 認証必須 → 公開ミラー化を推奨
- Pages: 公開範囲の制御に制約 → 公開用サブリポ/除外ビルド
- Actions: fork PR 権限厳格 → workflow_call設計へ移行
- Badges: 外部から不可視 → 代替可視化へ
- コラボ: 招待制 → 公開部分は分離

(注) 詳細データは /tmp/*.json を参照。必要なら次PRで要点抽出の自動整形を追加。