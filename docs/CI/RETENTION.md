# CI証跡保持ポリシー

**バージョン**: v1.0  
**最終更新**: 2025-08-31  
**目的**: CI証跡の肥大化対策とGitHub Releases活用による効率的な保持管理

## 基本方針

### Option A（推奨）: GitHub Releases移管方式

#### 保持対象の分類
| 分類 | 保持場所 | 保持期間 | 説明 |
|------|----------|----------|------|
| **要約データ** | リポジトリ内 | 永続 | TSV、要約JSON、インデックスファイル |
| **最新証跡** | リポジトリ内 | 最新2セット | 直近のCI実行結果（artifacts/ci-remote/） |
| **アーカイブ証跡** | GitHub Releases | 1年間 | ZIP化された過去の実行結果 |
| **機密ログ** | Private Releases | 6ヶ月 | 暗号化された詳細ログ |

#### 移管ルール
```bash
# 実行例：3ヶ月以上古い証跡をReleasesに移管
find artifacts/ci-remote -name "*20250[1-5]*" -type d | while read dir; do
  date=$(basename "$dir")
  echo "Archiving $date..."
  
  # ZIP化
  7z a "ci-archive-$date.zip" "$dir/"
  
  # Release作成・添付
  gh release create "archive-$date" "ci-archive-$date.zip" \
    --title "CI Archive $date" \
    --notes "Automated archive of CI artifacts from $date"
  
  # リポジトリから削除
  rm -rf "$dir"
done
```

### リポジトリ内保持構造

```
artifacts/
├── ci-remote/
│   ├── latest -> 20250831_104500/    # シンボリックリンクで最新を指定
│   ├── 20250831_104500/              # 最新セット
│   └── 20250830_091200/              # 前回セット
├── summaries/
│   ├── phase43_summary.tsv          # 要約データ（永続保持）
│   ├── ci_metrics_2025-08.json      # 月次メトリクス
│   └── retention_log.md             # 移管履歴
└── README.md                        # 証跡ディレクトリの説明
```

## 自動化スクリプト

### artifacts/ci-remote/README.md
```markdown
# CI Artifacts Directory

## 現在の保持状況
- **最新**: [20250831_104500](./20250831_104500/) - Phase 4.3 完了時点
- **前回**: [20250830_091200](./20250830_091200/) - Phase 4.3 検証中

## アーカイブ履歴
| 日付 | Release | 内容 |
|------|---------|------|
| 2025-08-29 | [archive-20250829_143000](https://github.com/Driedsandwich/ucomm/releases/tag/archive-20250829_143000) | Phase 4.3 初期検証 |
| 2025-08-28 | [archive-20250828_215253](https://github.com/Driedsandwich/ucomm/releases/tag/archive-20250828_215253) | 新ワークスペース移行 |

## 要約データ
- [phase43_summary.tsv](../summaries/phase43_summary.tsv) - Phase 4.3 全実行結果
- [ci_metrics_2025-08.json](../summaries/ci_metrics_2025-08.json) - 8月度メトリクス

詳細は [CI保持ポリシー](../../docs/CI/RETENTION.md) を参照。
```

### 自動移管スクリプト
```bash
#!/bin/bash
# scripts/archive_old_artifacts.sh

set -euo pipefail

RETENTION_DAYS=7  # リポジトリ内保持日数
ARTIFACTS_DIR="artifacts/ci-remote"
CURRENT_DATE=$(date +%s)

echo "Starting artifact archival process..."

# 古いディレクトリを特定
find "$ARTIFACTS_DIR" -maxdepth 1 -type d -name "????????_??????" | while read dir; do
  dir_name=$(basename "$dir")
  dir_date=$(echo "$dir_name" | cut -d_ -f1)
  dir_timestamp=$(date -d "$dir_date" +%s 2>/dev/null || continue)
  
  days_old=$(( (CURRENT_DATE - dir_timestamp) / 86400 ))
  
  if [ $days_old -gt $RETENTION_DAYS ]; then
    echo "Archiving $dir_name (${days_old} days old)..."
    
    # ZIP化
    archive_name="ci-archive-$dir_name.zip"
    7z a "$archive_name" "$dir/"
    
    # GitHub Release作成
    gh release create "archive-$dir_name" "$archive_name" \
      --title "CI Archive $dir_name" \
      --notes "Automated archive of CI artifacts from $dir_name. Contains $(find "$dir" -type f | wc -l) files."
    
    # 成功時のみ削除
    if gh release view "archive-$dir_name" >/dev/null 2>&1; then
      rm -rf "$dir"
      rm -f "$archive_name"
      echo "✅ Archived and cleaned up $dir_name"
      
      # 移管ログ更新
      echo "$(date): Archived $dir_name to archive-$dir_name release" >> artifacts/summaries/retention_log.md
    else
      echo "❌ Failed to create release for $dir_name"
      rm -f "$archive_name"
    fi
  fi
done

echo "Artifact archival process completed."
```

## 週次メンテナンス

### GitHub Actions Workflow
```yaml
# .github/workflows/artifact-maintenance.yml
name: Artifact Maintenance
on:
  schedule:
    - cron: '0 2 * * 0'  # 毎週日曜 2:00 AM
  workflow_dispatch:

jobs:
  cleanup:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Archive old artifacts
        run: |
          chmod +x scripts/archive_old_artifacts.sh
          ./scripts/archive_old_artifacts.sh
      
      - name: Update retention log
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          git add artifacts/summaries/retention_log.md
          git commit -m "chore: update artifact retention log" || exit 0
          git push
```

## Option B: Git LFS（参考）

### .gitattributes設定
```
# 大容量ファイルをLFS管理
*.log filter=lfs diff=lfs merge=lfs -text
*.zip filter=lfs diff=lfs merge=lfs -text
artifacts/**/*.json filter=lfs diff=lfs merge=lfs -text
artifacts/ci-remote/** filter=lfs diff=lfs merge=lfs -text
```

### 注意事項
- **コスト**: LFS使用量に応じた課金
- **クローン**: 初回クローン時間の増加
- **CI**: Actions実行時のLFS帯域消費

## 運用手順

### 日次作業
1. **サイズ確認**: `du -sh artifacts/` でディレクトリサイズをチェック
2. **最新リンク**: `artifacts/ci-remote/latest` の更新確認

### 週次作業（自動化推奨）
1. **古い証跡の移管**: 7日以上古いディレクトリをReleasesに移行
2. **要約データ更新**: 月次メトリクスの更新
3. **リンク確認**: アーカイブされた証跡へのリンク確認

### 月次作業
1. **Releases整理**: 6ヶ月以上古いReleaseの削除検討
2. **ポリシー見直し**: 保持期間とサイズ制限の見直し
3. **コスト確認**: ストレージ使用量とコストの確認

## 緊急時の対応

### 証跡紛失時
```bash
# Releaseから証跡を復元
gh release download archive-20250828_215253
unzip ci-archive-20250828_215253.zip -d artifacts/ci-remote/
```

### ストレージ枯渇時
```bash
# 緊急時の古い証跡削除
find artifacts/ci-remote -name "202508[12]*" -type d -exec rm -rf {} \;
```

## 関連ドキュメント

- [履歴集約ポリシー](../HISTORY/AGGREGATION_POLICY.md) - 履歴データの管理方針
- [CI設計書](./SMOKE.md) - CI実行とアーティファクト生成
- [運用マニュアル](../OPERATIONS.md) - 全体的な運用手順