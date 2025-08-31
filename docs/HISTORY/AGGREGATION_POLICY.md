# 履歴集約ポリシー - GitHub統合運用方針

**バージョン**: v1.0  
**最終更新**: 2025-08-31  
**目的**: チャット履歴のGitHub集約における要約方式と秘匿分離の運用指針

## 基本方針

### 1. 要約原則
- **要点のみ記録**: 各チャットセッションの要点・結論・根拠URLのみを構造化して記録
- **冗長性排除**: 生のチャット履歴は含めず、意思決定と成果物に焦点
- **追跡可能性**: 詳細が必要な場合に参照できるリンクを必須で併記

### 2. 秘匿分離ガード
- **コミット禁止**: 生ログ、個人情報、認証トークン、環境固有情報
- **暗号化保管**: 必要時は暗号化ZIPを **Private Release** に添付
- **鍵管理**: 暗号化キーは環境変数（UCOMM_ARCHIVE_KEY）で管理、ENVドキュメント参照

### 3. 肥大化防止
- **構造化**: 時系列インデックス + 個別要約ファイルの2層構造
- **リンク中心**: 大容量データはGitHub Releases活用、リポジトリ内はリンクのみ
- **定期整理**: 古い要約の統合・アーカイブ化ルールを明文化

## ディレクトリ構成

```
docs/HISTORY/
├── INDEX.md                 # 時系列の要約リンク（メインエントリポイント）
├── 2025-08/
│   ├── summary_20250831.md  # 日別要約
│   └── summary_20250830.md
└── templates/
    └── summary_template.md  # 要約作成テンプレート
```

## 要約フォーマット

### INDEX.md 構造
```markdown
# HISTORY INDEX

## 2025-08-31: Phase 4.3 完了とSSO T v1
- **要点**: Phase 4.3 先行成果物確定、SSOT v1 ドキュメント体系整備完了
- **成果**: CI成功率35.0%達成、MCPレイテンシ84%改善、200+証跡ファイル収集
- **根拠**: [PR #8](link), [PR #9](link), [整合性レポート](docs/reports/...)
- **詳細**: [summary_20250831.md](./2025-08/summary_20250831.md)
```

### 個別要約構造
```markdown
# 2025-08-31 セッション要約

## Phase 4.3 完了作業
**時間**: 10:00-12:00  
**参加者**: Claude Code  
**目的**: Phase 4.3 整合性検証の最終確認と成果物整理

### 主要決定事項
1. CI成功率35.0%でPhase 4.3先行完了を承認
2. SSOT v1として統一ドキュメント体系を構築
3. PR #8をDraft維持、Phase 5計画策定後にReady化

### 成果物・根拠
- [整合性レポート](../reports/phase4.3_integrity_20250828_220919.md)
- [PR #8](https://github.com/Driedsandwich/ucomm/pull/8)
- [CI証跡](../artifacts/ci-remote/20250828_215253/)

### 次のアクション
1. Phase 5計画策定
2. CI成功率改善計画立案
3. MCP-in-CI RFC優先度決定
```

## GitHub Releases活用

### アーカイブ対象
- 大容量ログファイル（>10MB）
- デバッグ用生ログ
- 機密性のある設定ファイル
- 古い証跡ファイル（3ヶ月以上）

### Release命名規則
- `archive-YYYY-MM-DD`: 日別アーカイブ
- `phase-X.Y-archive`: フェーズ別大容量証跡
- `confidential-YYYY-MM-DD.enc`: 暗号化アーカイブ

### 暗号化手順
```bash
# 暗号化（7-Zip使用例）
7z a -p"$UCOMM_ARCHIVE_KEY" confidential-20250831.7z sensitive_logs/

# GitHub Release添付
gh release create archive-2025-08-31 confidential-20250831.7z \
  --title "Archive 2025-08-31" \
  --notes "Encrypted archive of confidential logs"
```

## 運用ガイドライン

### 日次作業
1. **要約作成**: チャットセッション終了時に要約を作成
2. **リンク確認**: 根拠URLの有効性確認
3. **秘匿チェック**: 機密情報が含まれていないか確認
4. **インデックス更新**: INDEX.mdに新規要約を追記

### 週次作業
1. **統合確認**: 週間の要約を横断的に確認
2. **リンク検査**: 自動リンクチェックの結果確認
3. **肥大化確認**: リポジトリサイズの監視

### 月次作業
1. **アーカイブ化**: 古い証跡をReleasesに移行
2. **統合要約**: 月間の主要トピックを統合要約として作成
3. **ポリシー見直し**: 運用状況に応じたポリシー改善

## セキュリティ考慮事項

### 禁止事項
- 個人を特定できる情報（実名、メールアドレス、IPアドレス等）
- 認証情報（トークン、パスワード、APIキー等）
- 環境固有情報（ファイルパス、内部URL等）
- 未公開の戦略情報・計画情報

### 許可事項
- 技術的決定事項とその根拠
- 公開済みのPR/Issue番号とURL
- 汎用的な技術情報・設定方法
- 成果物の要約と評価

### 秘匿レベル判定
- **Public**: そのまま公開リポジトリにコミット可能
- **Internal**: チーム内共有は可能だが外部公開は不可
- **Confidential**: 暗号化してPrivate Releaseに保管

## 関連ドキュメント

- [Environment Variables](../ENV.md) - UCOMM_ARCHIVE_KEY等の暗号化設定
- [Operations Manual](../OPERATIONS.md) - 運用手順とセキュリティ設定
- [CI Retention Policy](../CI/RETENTION.md) - 証跡保持ポリシー
- [Reports Index](../reports/README.md) - 公開レポートの索引