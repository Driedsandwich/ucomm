# Reports Index

このディレクトリは、ucomm プロジェクトの各フェーズおよび検証結果のレポートを格納します。

## 🔍 最新 CI Triage リンク (固定セクション)

**最新レポート**: [phase43_triage_20250831_104930.md](./triage/phase43_triage_20250831_104930.md)  
**実行方法**: `./scripts/ci_triage.sh [date]`  
**自動更新**: 三分診実行時に本セクションが自動更新されます

## Phase 4.3 整合性検証レポート

### [phase4.3_integrity_20250828_220919.md](./phase4.3_integrity_20250828_220919.md)
**Phase 4.3 整合性検証レポート（クロスOS） — 先行版**

- **対象**: Phase 4.3（クロスOS検証）まで
- **内容**: 新ワークスペースでのクロスプラットフォーム動作検証
- **主要結果**: CI成功率35.0%、MCPレイテンシ改善（783ms→125ms、84%向上）
- **証跡**: artifacts/ci-remote/20250828_215253/ 配下に200+ファイル
- **ステータス**: 完了（Draft PR #8として管理）

## Triage Reports (Phase 4.3)

### [phase43_triage_20250831_104930.md](./triage/phase43_triage_20250831_104930.md)
**CI失敗の三分診レポート - Phase 4.3**

- **生成日時**: 2025-08-31 10:49:30
- **対象期間**: 20250828_215253  
- **分析対象**: artifacts/ci-remote/20250828_215253/
- **分類**: 環境/依存/スクリプトエラーの自動分類と改善提案

## 今後のレポート予定

- **Phase 5 レポート**: 自動議事録生成PoC実装結果
- **CI改善レポート**: CI成功率70%達成への改善過程
- **MCP-in-CI RFC**: 実装フェーズ結果報告
- **役割マッピング運用レポート**: 実環境適用とテスト結果

## レポート作成ガイドライン

1. **命名規則**: `phase<X.Y>_<type>_<YYYYMMDD_HHMMSS>.md`
2. **必須セクション**: スコープ、方法、主要結果、参照リンク
3. **証跡管理**: artifacts/ 配下への関連ファイル配置
4. **更新管理**: このREADME.mdへの新規レポート追記

## Releases

* **Phase 4.3 Proof**: [v0.5.0-phase4.3-proof](https://github.com/Driedsandwich/ucomm/releases/tag/v0.5.0-phase4.3-proof)
  * 昇格元: artifacts/ci-remote/20250828_215253（ZIP添付）

## 関連リンク

- [PR #8 - Phase 4.3成果](https://github.com/Driedsandwich/ucomm/pull/8)
- [Phase 4.3 証跡ディレクトリ](../../artifacts/ci-remote/20250828_215253/)
- [Handoffドキュメント](../handoffs/)