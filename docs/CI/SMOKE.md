# CI Design: Smoke Testing & Triage System

**ファイル**: docs/CI/SMOKE.md  
**最終更新**: 2025-08-31  
**対象**: smoke.yml ワークフローと三分診システム

## 概要

UCOMM プロジェクトの継続的インテグレーション (CI) は GitHub Actions の smoke.yml を中心とした軽量なスモークテスト体系です。クロスプラットフォーム検証と自動障害分析により、開発効率と品質保証を両立します。

## CI トリガー

### 1. Pull Request トリガー
```yaml
on:
  pull_request:
    branches: [ main ]
```
- **対象**: main ブランチへの PR
- **実行内容**: 基本的なスモークテスト
- **OS**: Ubuntu Latest, Windows Latest
- **実行時間**: 約 3-5 分

### 2. Manual Dispatch
```yaml
on:
  workflow_dispatch:
    inputs:
      os_matrix:
        description: 'OS to test on'
        required: false
        default: 'ubuntu-latest,windows-latest'
```
- **トリガー**: GitHub UI または API から手動実行
- **実行内容**: 全機能テスト + アーティファクト収集
- **OS**: 設定可能 (デフォルト: Ubuntu, Windows)
- **実行時間**: 約 8-12 分

## SLO (Service Level Objectives)

### パフォーマンス目標

| メトリック | 目標値 | Phase 4.3 実績 | Phase 5 目標 |
|-----------|--------|----------------|-------------|
| CI 成功率 | ≥ 35% | 35.0% ✅ | ≥ 50% |
| 実行時間 | ≤ 6 分 | 測定中 | ≤ 6 分 |
| MCP レイテンシ | ≤ 500ms | 125ms ✅ | ≤ 200ms |
| 証跡収集 | ≥ 200 ファイル | 200+ ✅ | ≥ 300 |

### 品質目標

| カテゴリ | 目標 | 測定方法 | 現状 |
|---------|------|----------|------|
| テスト網羅性 | 主要機能カバー | health.sh 実行 | ✅ 基本機能 |
| クロス OS 互換 | Ubuntu/Windows | 両環境での実行 | ✅ 確認済み |
| 障害検出率 | ≥ 90% | 三分診による分類 | ✅ 実装済み |
| 偽陽性率 | ≤ 5% | 手動確認との比較 | 🔄 測定中 |

## アーティファクト構成

### 収集される成果物

```
artifacts/ci-remote/<YYYYMMDD_HHMMSS>/
├── dispatch-run/
│   ├── smoke-<run-id>-ubuntu-latest/
│   │   ├── artifacts/
│   │   │   ├── health.json          # ヘルスチェック結果
│   │   │   ├── ucomm.log           # 実行ログ
│   │   │   └── environment.txt      # 環境情報
│   │   └── logs/                    # 詳細ログ
│   └── smoke-<run-id>-windows-latest/
│       └── [同様の構成]
└── pr-run/
    ├── smoke-<run-id>-ubuntu-latest/
    └── smoke-<run-id>-windows-latest/
```

### アーティファクト内容

#### health.json
```json
{
  "status": "ok|degraded|error",
  "timestamp": "2025-08-31T10:49:30Z",
  "latency_ms": 125,
  "components": {
    "mcp": {
      "status": "ok",
      "latency_ms": 125,
      "endpoint": "127.0.0.1:39200"
    },
    "tmux": {
      "status": "ok", 
      "sessions": 2
    },
    "adapters": {
      "status": "ok",
      "loaded": 5
    }
  },
  "platform": {
    "os": "ubuntu-20.04",
    "node": "18.17.0",
    "arch": "x64"
  }
}
```

#### environment.txt
```
OS=ubuntu-20.04
NODE_VERSION=18.17.0
ARCHITECTURE=x64
UCOMM_VERSION=0.5.0
WORKSPACE_PATH=/home/runner/work/ucomm/ucomm
ARTIFACTS_ENABLED=true
```

## 三分診システム

### scripts/ci_triage.sh の使用方法

#### 基本実行
```bash
# 最新のアーティファクトを自動分析
./scripts/ci_triage.sh

# 特定の日付を指定
./scripts/ci_triage.sh 20250828_215253

# カスタム出力先
./scripts/ci_triage.sh -o custom/reports 20250828_215253

# 詳細モード
./scripts/ci_triage.sh -v 20250828_215253
```

#### 出力例
```
✅ CI Triage完了: docs/reports/triage/phase43_triage_20250831_104930.md
📊 分析結果:
  - 総実行数: 4
  - 環境エラー: 0
  - 依存エラー: 0  
  - スクリプトエラー: 0
  - 成功率: 100%
```

### 障害分類システム

#### 1. 環境エラー (Environment)
- **検出パターン**: "environment", "env", "path not found", "command not found", "permission denied"
- **典型例**: 
  - PATH 設定不備
  - 必要コマンドの未インストール
  - 実行権限の問題
- **改善提案**: PATH確認、コマンドインストール、権限設定

#### 2. 依存エラー (Dependency)  
- **検出パターン**: "dependency", "import error", "module not found", "package", "npm", "pip"
- **典型例**:
  - package.json の依存関係不足
  - Node.js バージョン不適合
  - npm install の失敗
- **改善提案**: 依存関係更新、バージョン確認、lockファイル同期

#### 3. スクリプトエラー (Script)
- **検出パターン**: "script", "syntax error", "unexpected", "failed", "error:"
- **典型例**:
  - JavaScript/TypeScript 構文エラー
  - テストケースの失敗
  - ロジックバグ
- **改善提案**: 構文チェック、テスト見直し、エラーハンドリング

### 三分診レポート生成

#### レポート構造
```markdown
# CI Triage Report - Phase 4.3

## 概要
**結果**: All green 🟢 / 失敗分類表

## 失敗分類
| 分類 | 件数 | 割合 | 説明 |
|------|------|------|------|
| 環境 | X件 | Y% | パス、コマンド、権限エラー |
| 依存 | X件 | Y% | パッケージ、モジュール不足 |  
| スクリプト | X件 | Y% | 構文エラー、ロジック問題 |

## 改善提案
### [分類別の具体的改善案]

## 詳細ログ参照
### [関連コマンドとファイルパス]
```

### 索引更新手順

#### 自動更新 (推奨)
```bash
# triage 実行時に自動で docs/reports/README.md を更新
./scripts/ci_triage.sh
```

#### 手動更新
```bash
# 1. 最新の triage レポートを確認
ls -lt docs/reports/triage/

# 2. README.md に追記
echo "- [新しいレポート](./triage/filename.md)" >> docs/reports/README.md

# 3. git 操作
git add docs/reports/README.md docs/reports/triage/
git commit -m "docs: add triage report and update index"
```

## ワークフロー設計

### smoke.yml 構造

```yaml
name: Smoke Tests
on: [pull_request, workflow_dispatch]

jobs:
  smoke:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          
      - name: Install dependencies
        run: npm ci
        
      - name: Health Check
        run: ./scripts/health.sh --json > health.json
        
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: smoke-${{ github.run_id }}-${{ matrix.os }}
          path: |
            health.json
            logs/
            *.log
```

### 段階的改善計画

#### Phase 4.3 → 5.0
- **目標**: CI 成功率 35% → 50%
- **施策**: 
  - 依存関係の安定化
  - エラーハンドリングの強化
  - タイムアウト設定の最適化

#### Phase 5.0 → 6.0  
- **目標**: CI 成功率 50% → 70%
- **施策**:
  - API テストの追加
  - E2E テストの導入
  - パフォーマンステストの追加

#### Phase 6.0 → 7.0
- **目標**: CI 成功率 70% → 95%
- **施策**:
  - フル機能テスト
  - セキュリティテスト
  - 負荷テスト

## 監視・アラート

### 失敗通知
- **Slack 通知**: CI 失敗時の自動通知 (Phase 6 予定)
- **Email 通知**: 連続失敗時のエスカレーション
- **GitHub Issues**: 自動Issue作成 (Phase 5 予定)

### メトリクス収集
- **成功率トレンド**: 週次/月次の成功率変化
- **実行時間**: ビルド時間の監視
- **リソース使用量**: CPU/メモリの使用状況
- **エラー分類**: 三分診による分類統計

## 運用ガイドライン

### CI 失敗時の対応手順

1. **即座の対応** (5分以内)
   ```bash
   # 三分診実行
   ./scripts/ci_triage.sh
   
   # 結果確認
   cat docs/reports/triage/phase43_triage_*.md
   ```

2. **原因調査** (15分以内)
   - 三分診レポートの確認
   - ログファイルの詳細調査
   - 環境差分の確認

3. **修正対応** (1時間以内)
   - 分類に応じた修正作業
   - テストケースの追加
   - PR での修正提出

4. **再発防止** (24時間以内)
   - CI 改善の Issue 作成
   - ドキュメント更新
   - 監視強化

### 定期メンテナンス

#### 週次
- [ ] 三分診レポートのレビュー
- [ ] 成功率トレンドの確認
- [ ] アーティファクトの整理

#### 月次  
- [ ] CI 設定の見直し
- [ ] パフォーマンス分析
- [ ] セキュリティ監査

#### 四半期
- [ ] ワークフロー全体の見直し
- [ ] ツール・依存関係の更新
- [ ] 運用手順の改善

## 関連ドキュメント

- [Phase Map](../PHASE_MAP.txt) - プロジェクト全体計画
- [Requirements v0.5.x](../REQUIREMENTS_v0.5.x.md) - CI 要件とテスト方法
- [Reports Index](../reports/README.md) - CI結果とレポート
- [Operations Manual](../OPERATIONS.md) - 運用手順
- [三分診スクリプト](../../scripts/ci_triage.sh) - 障害分析ツール