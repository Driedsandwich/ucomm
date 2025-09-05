# DECISIONS_LOG

## 2025-08-31 (Phase 4.3 完了決定)
- **Phase 4.3 先行レポート形式での完了承認**
  - 理由：CI環境でのクロスプラットフォーム検証完了、200+証跡ファイル収集、引き継ぎ可能な状態到達
  - 完了基準：CI成功率35.0%達成、MCPレイテンシ改善（783ms→125ms、84%向上）、Ubuntu/Windows両環境でdegraded状態確認
  - 実装内容：新ワークスペース移行（C:\AI\workspaces\projects\ucomm）、整合性検証レポート、三分診システム
  - 証跡管理：artifacts/ci-remote/20250828_215253/、docs/reports/phase4.3_integrity_20250828_220919.md
  - 次段階：Phase 5計画策定とPhase 4.3成果の正式承認プロセス

- **新ワークスペース移行の承認**
  - 理由：Phase 4.3 クロスOS検証に適した環境構築のため
  - 移行先：C:\AI\workspaces\projects\ucomm（従来のフォルダ構成から変更）
  - 影響範囲：全CI実行証跡、MCP設定、書込みゲート機能検証
  - 継続性：handoffドキュメント体系の標準化により引き継ぎ確保

- **PR #8 Draft運用の承認**
  - 理由：Phase 5以降計画との整合性確認が必要なため、即座のmainマージを却下
  - 運用方針：Draft化、ラベル整備（phase4.3, evidence, docs）、コメント追加による進捗管理
  - レビュー体制：後続フェーズとの明確な分離、補助資料（レポート索引、三分診、PRテンプレート）完備
  - 最終判断：Phase 5計画策定後にDraft→Ready移行

## 2025-08-11
- **COUNCILモードの役職なし化**
  - 理由：討論形式で上下関係を排除するため
  - 実装時期：Phase4
  - 現状：役職ありのまま稼働、Phase4でrole==null対応予定

- **retry設定のYAML化（将来計画）**
  - 理由：Phase5以降の自動化を見据え、手動指定の負担を軽減
  - 追加先：config/topology.yaml

## 2025-09-01 (Phase 4.3 完了・Phase 5 準備)
- **2025-08-31**: Phase 4.3終了。SSOT統合(PR #9), Link Check安定(17360370776/17362273058)。CI=35%。#21/#22を次フェーズへ。
- **2025-09-01**: 後代ハンドオフ体制をドキュメント主導に固定（SSOTセット作成）。Link Check非破壊を前提とした SSOT hardening 実施。

## 2025-09-01 (macOS portability - Issue #22 是正)
- **Issue #22是正方針**: health.shをjqベースに変更、LC_ALL=C固定、yq失敗の非致命化
- **問題**: macOS smoke テストで `date +%s%3N` が "1234567890N" 返却→無効JSON生成 (`"latency_ms": ,`)  
- **解決策**: ポータブル millisecond timing (python3/node/gdate/秒フォールバック), 数値検証, 堅牢エラーハンドリング
- **状態**: PR #24作成（fix/macos-health-portability-v1）、ラベラー設定も同時修正
- **ベースライン**: main smoke Run: 17365167010 success
- **予定**: macOS成功率向上の継続監視（2週移動平均>90%）

## 2025-09-01 Phase 5 起動：CI状況確認とRun登録
- **Action**: mainのsmoke最新成功Runの確認とベースライン更新
- **Evidence**: Actions Run ID=`17365202195` (URL: https://github.com/Driedsandwich/ucomm/actions/runs/17365202195)
- **Notes**: 2週移動平均70%目標の初期ベースライン採用。macOS flakinessはIssue #22で継続追跡。
- **Author**: 9th dev room (ChatGPT) / executed by ClaudeCode
## Decision: Protect main branch with required checks (Admins included)
Date: 2025-09-03 10:40:53 +09:00

Summary:
- Enable branch protection on main
- Required status checks (strict=true):
  - smoke
  - linkcheck
  - label
- Enforce for administrators: true
- Reviews: required_approving_review_count = 1, dismiss_stale_reviews = true

Evidence (gh api):
- strict=true, contexts=[""smoke"",""linkcheck"",""label""], admins.enabled=true

Rationale:
- Prevent direct pushes and risky merges; ensure CI gates are respected for all roles.





