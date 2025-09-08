# DECISIONS_LOG

## 2025-09-09
- Decision: v0.5.2 を公開
- Reason: Phase 5 の集約（RFC-001 完遂・CI安定化・観測導線整備）を反映し、安定版を更新
- Reference: tag v0.5.2, docs/RELEASES/v0.5.2.md
- Approved by: 統括PM

## 2025-09-08
- Decision: v0.5.2 リリース準備完了（決裁待ち）
- Reason: RFC-001 完遂、CI安定・観測運用、ノート最終化。
- Reference: Issue #81, docs/RELEASES/v0.5.2.md
- Next: PM決裁後に tag v0.5.2 & GitHub Release。

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

## 2025-09-01 Phase 5 起動準備（#21）
- 一時的に Public 化し、Classic Branch Protection で Required status check を設定：
  - context = Link Check / linkcheck
- PR #28 で「壊れリンク→失敗」「修正→成功」を確認し、**強制が有効**を確認。
- **直後に Private へ復帰**。Free プラン制約により **強制は現在"無効"**（設定値は保持）。
- 次回 Public 化・Pro へのアップグレード・または Ruleset 導入時に**即有効化**できる状態を保持。

## 2025-09-01 (Phase 4.3 完了・Phase 5 準備)
- **2025-08-31**: Phase 4.3終了。SSOT統合(PR #9), Link Check安定(17360370776/17362273058)。CI=35%。#21/#22を次フェーズへ。
- **2025-09-01**: 後代ハンドオフ体制をドキュメント主導に固定（SSOTセット作成）。Link Check非破壊を前提とした SSOT hardening 実施。

## 2025-09-01 (macOS portability - Issue #22 是正)
- **Issue #22是正方針**: health.shをjqベースに変更、LC_ALL=C固定、yq失敗の非致命化
- **問題**: macOS smoke テストで `date +%s%3N` が "1234567890N" 返却→無効JSON生成 (`"latency_ms": ,`)  
- **解決策**: ポータブル millisecond timing (python3/node/gdate/秒フォールバック), 数値検証, 堅牢エラーハンドリング

## 2025-09-06
- Decision: Branch Protection の必須チェックを"実ジョブ名"に統一し、手動ステータスを撤廃。
- Reason: 手動コンテキスト依存を排除してCIの再現性・透明性を担保するため。
- Approved by: 統括PM
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

## 2025-09-06
- Decision: Release v0.5.1 Draft を破棄
- Reason: 安定性未確保（CI成功率55%）、branch protection未設定、リリース体系不整合リスク解消のため。
- Reference: v0.5.0-phase4.3-proof を安定版として維持。Phase 5で新しい安定版（例: v0.5.2）を再設計する。
- Approved by: 統括PM

- Decision: Phase 5 優先度を確定（#12 → #13 → #14 → #17）
- Reason: CLI基盤→MCP設計合意→運用適用→CI安定化の順で波及効果が最大
- Approved by: 統括PM

- Decision: Branch Protection適用とCLI bins PoC完了
- Date: 2025-09-06
- Actions:
  - **Branch Protection**: 必須チェック（linkcheck, smoke 3OS, label, eol-guard）を main に適用（[PR #56](https://github.com/Driedsandwich/ucomm/pull/56)）
  - **CLI bins PoC**: JSON検証機能追加し、クロスOS動作確認完了（[PR #55](https://github.com/Driedsandwich/ucomm/pull/55), Issue #12）
  - **セキュリティ強化**: CodeQL + Dependabot導入（[PR #57](https://github.com/Driedsandwich/ucomm/pull/57)）
- Evidence: 
  - Branch protection snapshot: docs/reports/data/2025-09-06/branch-protection.json
  - Health JSON schema: schemas/health.schema.json
  - 3OS全てでJSON検証通過確認
- Reason: public維持前提での安全性向上、人依存排除、機械判定可能な健康チェック実現
- Approved by: 統括PM







## 2025-09-07
- Decision: RFC-001 (MCP-in-CI) を採択。Stage A（静的検証）を有効化。
- Reason: MCPプロファイルの安全性・一貫性をCIで担保するため。
- Approved by: 統括PM

- Decision: Branch Protection の必須チェックに `ci-mcp-validate` を追加。
- Reason: MCPプロファイルの安全性を静的検証で担保するため。
- Approved by: 統括PM

- Decision: RFC-001 (MCP-in-CI) を **完遂**（Stage A/B/Cの全段適用）。
- Reason: 静的検証の本番運用、エフェメラル実測の監査証跡化、API境界の最小/拡張検証まで段階的に完了。
- Reference: PR #69（測定入庫）, #72（Stage C 拡張）, #73（Stage C 最小）ほか。
- Approved by: 統括PM

