## 2025-09-01 Phase 5 起動準備（#21）
- 一時的に Public 化し、Classic Branch Protection で Required status check を設定：
  - context = Link Check / linkcheck
- PR #28 で「壊れリンク→失敗」「修正→成功」を確認し、**強制が有効**を確認。
- **直後に Private へ復帰**。Free プラン制約により **強制は現在“無効”**（設定値は保持）。
- 次回 Public 化・Pro へのアップグレード・または Ruleset 導入時に**即有効化**できる状態を保持。