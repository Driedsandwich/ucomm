# Changelog

All notable changes to the UCOMM project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- docs SSOT v1 追加（非コード）
  - PHASE_MAP.txt: 7th generation project roadmap with Phase 4.3 completion status
  - SPEC_ucomm_v0.5.x.md: System architecture and component specifications
  - REQUIREMENTS_v0.5.x.md: Traceability matrix with DOD and test methods
  - CI/SMOKE.md: CI design documentation with triage system integration
  - OPERATIONS.md: Security operations manual with write gates and approval flows
  - ENV.md: Environment variables with priority cascade and security settings
  - DECISIONS_LOG.md: Phase 4.3 completion decisions and workspace migration approval
  - PR_TEMPLATES/phase43.md: Phase 4.3 specific PR template with review checklist
  - Reports index with latest triage links section for automated CI failure analysis

## [0.4.3] - 2025-08-31

### Added
- Phase 4.3 整合性検証レポート完成
  - クロスプラットフォーム（Ubuntu/Windows）動作検証完了
  - CI成功率35.0%達成、MCPレイテンシ改善（783ms→125ms、84%向上）
  - 新ワークスペース移行完了（C:\AI\workspaces\projects\ucomm）
  - 証跡収集システム（artifacts/ci-remote/20250828_215253/、200+ファイル）

### Added
- CI失敗の三分診システム
  - scripts/ci_triage.sh: 自動障害分類スクリプト（環境/依存/スクリプト）
  - docs/reports/triage/: 三分診レポート出力先
  - 自動索引更新機能付き

### Added
- レポート管理体系
  - docs/reports/README.md: レポート索引の常設
  - 各レポートへの相対リンクと簡易説明
  - レポート作成ガイドライン統一

### Changed
- PR #8 を Draft 化して段階的レビュー体制を整備
- handoffドキュメント体系の標準化

## [0.4.2] - 2025-08-28

### Added
- 新ワークスペース環境構築
- GitHub Actions CI実行基盤
- smoke.yml による基本的なクロスプラットフォームテスト

### Added  
- MCP (Model Context Protocol) 基盤実装
- 基本的なヘルスチェック機能（health.sh）
- tmux ベースの組織化システム

### Security
- 書込みゲート基本機能（UCOMM_ENABLE_WRITES環境変数）
- セキュアモード設定（UCOMM_SECURE_MODE）
- CI環境での安全な実行確認

## [0.4.1] - 2025-08-11

### Added
- COUNCILモードの基本設計
- retry設定のYAML化計画
- 基本的なプロジェクト構造

### Changed
- 役職なし化の方針決定（Phase 4実装予定）

## [0.4.0] - 2025-08-01

### Added
- 初期プロジェクト設定
- 基本的なディレクトリ構造
- README.md とライセンス設定

---

## Version Naming Convention

- **Major (X.0.0)**: 破壊的変更、アーキテクチャ変更
- **Minor (0.X.0)**: 新機能追加、フェーズ完了
- **Patch (0.0.X)**: バグフィックス、ドキュメント更新

## Phase Mapping

- **0.4.x**: Phase 4 シリーズ（クロスプラットフォーム整合性検証）
- **0.5.x**: Phase 5 シリーズ（自動議事録生成PoC）（計画）
- **0.6.x**: Phase 6 シリーズ（API統合とウェブダッシュボード）（計画）
- **0.7.x**: Phase 7 シリーズ（プロダクション準備）（計画）