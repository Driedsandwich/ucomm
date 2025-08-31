# UCOMM System Specification v0.5.x

**バージョン**: 0.5.x  
**最終更新**: 2025-08-31  
**ステータス**: Phase 4.3 完了, Phase 5 計画中

## 概要

UCOMM (Unified Command) は MCP (Model Context Protocol) をベースとした統一コマンド実行基盤です。tmux ベースの組織化システムと CLI アダプターを通じて、セキュアで一貫性のあるコマンド実行環境を提供します。

## システムアーキテクチャ

### コア コンポーネント

#### 1. Tmux 組織システム
- **役割**: セッション管理とコマンド実行の組織化
- **設定ファイル**: `.tmux.conf` (プロジェクトルート)
- **セッション管理**: 自動セッション作成・復帰機能
- **ウィンドウ管理**: コンテキスト別ウィンドウ分離

#### 2. CLI Adapters
- **役割**: 既存 CLI ツールと MCP の橋渡し
- **実装場所**: `src/adapters/` ディレクトリ
- **対応ツール**: git, npm, python, docker 等
- **標準化**: 統一されたレスポンス形式 (JSON)

#### 3. MCP (Model Context Protocol)
- **エンドポイント**: `127.0.0.1:39200` (固定)
- **通信方式**: HTTP/JSON-RPC
- **設定ファイル**: `mcp.json` (プロジェクトルート)
- **モード**: Read-Only / Read-Write (環境変数制御)

## インターフェース仕様

### 1. Health Check API

**エンドポイント**: `/ready`, `/health`

```bash
# 基本実行
./scripts/health.sh

# JSON 出力
./scripts/health.sh --json
```

**レスポンス形式**:
```json
{
  "status": "ok|degraded|error",
  "timestamp": "2025-08-31T10:49:30Z",
  "latency_ms": 125,
  "components": {
    "mcp": {"status": "ok", "latency_ms": 125},
    "tmux": {"status": "ok", "sessions": 2},
    "adapters": {"status": "ok", "loaded": 5}
  }
}
```

### 2. Command Execution API

**基本形式**:
```bash
ucomm <adapter> <command> [args...]
```

**例**:
```bash
ucomm git status
ucomm npm install
ucomm docker ps
```

## SLO (Service Level Objectives)

### パフォーマンス要件

| メトリック | 目標値 | Phase 4.3 実績 |
|-----------|--------|----------------|
| 初回実行レイテンシ | ≤ 6s | 測定中 |
| CI 実行レイテンシ | ≤ 6s | 測定中 |
| MCP 通信レイテンシ | ≤ 500ms | 125ms ✅ |
| CI 成功率 | ≥ 35% | 35.0% ✅ |

### 可用性要件

- **サービス稼働率**: 99.9% (計画時)
- **復旧時間**: < 5分 (自動再起動)
- **データ整合性**: 100% (Read-Only モード時)

## MCP プロファイル

### HTTP 設定
```json
{
  "server": {
    "host": "127.0.0.1",
    "port": 39200,
    "timeout": 30000
  }
}
```

### Read-Only (RO) モード
- **設定**: `mcp.json` 内で `"readonly": true`
- **制限**: 書き込み操作の全面禁止
- **用途**: CI 環境、本番環境での安全実行

### Allow-Deny 制御
```json
{
  "security": {
    "allow_commands": ["git", "npm", "docker"],
    "deny_patterns": ["rm -rf", "sudo", "chmod +x"],
    "require_confirmation": ["git push", "npm publish"]
  }
}
```

### 再起動反映
- **設定変更**: `mcp.json` 更新時の自動リロード
- **プロセス管理**: SIGHUP による graceful restart
- **依存関係**: tmux セッション維持

## 依存関係とポート

### システム依存
| コンポーネント | 依存 | バージョン |
|---------------|------|-----------|
| Node.js | 必須 | ≥ 18.0.0 |
| tmux | 必須 | ≥ 3.2 |
| Git | 必須 | ≥ 2.30 |
| Python | オプション | ≥ 3.8 |

### ポート使用
| ポート | 用途 | プロトコル |
|-------|------|----------|
| 39200 | MCP サーバー | HTTP |
| 39201 | WebSocket (将来) | WS |

## 失敗時リトライ方針

### MCP 通信エラー
```typescript
const retryConfig = {
  maxRetries: 3,
  backoffMs: [1000, 2000, 4000],
  retryableErrors: ["ECONNREFUSED", "TIMEOUT", "503"]
};
```

### コマンド実行失敗
1. **一時的エラー**: 指数バックオフで 3回リトライ
2. **設定エラー**: 即座に失敗、ログ出力
3. **権限エラー**: リトライなし、セキュリティログ

### tmux セッション復旧
- **セッション切断**: 自動再接続 (30秒間隔)
- **プロセス停止**: systemd/supervisord による自動再起動
- **設定破損**: バックアップからの自動復元

## セキュリティ仕様

### 書き込みゲート
- **環境変数**: `UCOMM_ENABLE_WRITES=0/1`
- **確認プロンプト**: `UCOMM_CONFIRM_WRITE=1`
- **セキュアモード**: `UCOMM_SECURE_MODE=1` (書き込み全面禁止)

### 認証・認可 (Phase 6 予定)
- **認証方式**: OAuth2 + JWT
- **認可レベル**: Read-Only / Read-Write / Admin
- **セッション管理**: Redis ベースセッションストア

## 監視・ロギング

### ログ出力要件
- **レベル**: DEBUG / INFO / WARN / ERROR
- **フォーマット**: 構造化ログ (JSON)
- **ローテーション**: 日次、最大7日間保持
- **出力先**: `logs/ucomm.log`, syslog

### メトリクス収集
- **実行時間**: 全コマンドの実行時間測定
- **成功率**: 成功/失敗の統計情報
- **リソース**: CPU/メモリ使用量
- **エラー**: エラー種別とカウント

## プラットフォーム対応

### サポート OS
| OS | バージョン | Status |
|----|-----------|---------| 
| Ubuntu | 20.04+ | ✅ Supported |
| Windows | Server 2019+ | ✅ Supported |
| macOS | 12+ | 🔄 Planned |

### CI/CD 環境
- **GitHub Actions**: Ubuntu/Windows runner
- **テスト実行**: smoke.yml による自動テスト
- **アーティファクト**: テスト結果とログの収集

## バージョン管理

### セマンティックバージョニング
- **MAJOR**: 破壊的変更
- **MINOR**: 後方互換性のある機能追加  
- **PATCH**: バグフィックス

### リリース要件
- **CI 成功率**: フェーズ別目標値達成
- **テストカバレッジ**: ≥ 80%
- **ドキュメント更新**: 全仕様書の更新
- **証跡保存**: artifacts/ への実行証跡保存

## 関連ドキュメント

- [Phase Map](./PHASE_MAP.txt) - プロジェクト全体計画
- [Requirements v0.5.x](./REQUIREMENTS_v0.5.x.md) - 要件定義とトレーサビリティ
- [Operations Manual](./OPERATIONS.md) - 運用手順書
- [Environment Variables](./ENV.md) - 環境変数一覧
- [CI Design](./CI/SMOKE.md) - CI/CD 設計書