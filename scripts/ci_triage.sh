#!/bin/bash

# CI失敗の三分診スクリプト
# 機能: artifacts/ci-remote/*/配下のログから失敗理由を抽出し、分類してMarkdownで出力

set -euo pipefail

# デフォルト設定
DEFAULT_ARTIFACTS_DIR="artifacts/ci-remote"
OUTPUT_DIR="docs/reports/triage"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# ヘルプ関数
show_help() {
    cat << EOF
CI Triage Script - CI失敗原因の三分診

使用方法:
    $0 [OPTIONS] [ARTIFACTS_DATE]

引数:
    ARTIFACTS_DATE    分析対象のアーティファクトディレクトリ日付 (例: 20250828_215253)
                     省略時は最新のディレクトリを自動選択

オプション:
    -h, --help       このヘルプを表示
    -o, --output     出力ディレクトリ (デフォルト: $OUTPUT_DIR)
    -v, --verbose    詳細出力

例:
    $0                              # 最新のアーティファクトを分析
    $0 20250828_215253             # 指定日付のアーティファクトを分析
    $0 -o custom/path 20250828_215253  # カスタム出力先
EOF
}

# 引数解析
VERBOSE=false
CUSTOM_OUTPUT=""
TARGET_DATE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -o|--output)
            CUSTOM_OUTPUT="$2"
            shift 2
            ;;
        -*)
            echo "未知のオプション: $1" >&2
            exit 1
            ;;
        *)
            if [[ -z "$TARGET_DATE" ]]; then
                TARGET_DATE="$1"
            else
                echo "余分な引数: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# 出力ディレクトリの決定
if [[ -n "$CUSTOM_OUTPUT" ]]; then
    OUTPUT_DIR="$CUSTOM_OUTPUT"
fi

# アーティファクトディレクトリの決定
if [[ -z "$TARGET_DATE" ]]; then
    if [[ -d "$DEFAULT_ARTIFACTS_DIR" ]]; then
        # 最新のディレクトリを取得
        TARGET_DATE=$(ls -1 "$DEFAULT_ARTIFACTS_DIR" | grep -E '^[0-9]{8}_[0-9]{6}$' | sort -r | head -n1)
        if [[ -z "$TARGET_DATE" ]]; then
            echo "エラー: $DEFAULT_ARTIFACTS_DIR に有効な日付ディレクトリが見つかりません" >&2
            exit 1
        fi
        [[ "$VERBOSE" == "true" ]] && echo "自動選択されたディレクトリ: $TARGET_DATE"
    else
        echo "エラー: $DEFAULT_ARTIFACTS_DIR が存在しません" >&2
        exit 1
    fi
fi

ARTIFACTS_PATH="$DEFAULT_ARTIFACTS_DIR/$TARGET_DATE"

# 入力検証
if [[ ! -d "$ARTIFACTS_PATH" ]]; then
    echo "エラー: アーティファクトディレクトリが存在しません: $ARTIFACTS_PATH" >&2
    exit 1
fi

# 出力ディレクトリの作成
mkdir -p "$OUTPUT_DIR"

OUTPUT_FILE="$OUTPUT_DIR/phase43_triage_$TIMESTAMP.md"

[[ "$VERBOSE" == "true" ]] && echo "分析開始: $ARTIFACTS_PATH -> $OUTPUT_FILE"

# 失敗分析関数
analyze_failures() {
    local artifacts_path="$1"
    local env_failures=0
    local dep_failures=0
    local script_failures=0
    local total_runs=0
    
    # 各実行結果を分析
    while IFS= read -r -d '' log_file; do
        ((total_runs++))
        local failure_type="unknown"
        
        if grep -qi "environment\|env\|path not found\|command not found\|permission denied" "$log_file" 2>/dev/null; then
            ((env_failures++))
            failure_type="環境"
        elif grep -qi "dependency\|import error\|module not found\|package\|npm\|pip\|requirements" "$log_file" 2>/dev/null; then
            ((dep_failures++))
            failure_type="依存"
        elif grep -qi "script\|syntax error\|unexpected\|failed\|error:" "$log_file" 2>/dev/null; then
            ((script_failures++))
            failure_type="スクリプト"
        fi
        
        if [[ "$VERBOSE" == "true" && "$failure_type" != "unknown" ]]; then
            echo "検出: $failure_type - $(basename "$log_file")"
        fi
    done < <(find "$artifacts_path" -name "*.log" -o -name "*.txt" -o -name "*.json" -print0 2>/dev/null)
    
    echo "$env_failures $dep_failures $script_failures $total_runs"
}

# メイン分析処理
analysis_result=$(analyze_failures "$ARTIFACTS_PATH")
read -r env_count dep_count script_count total_count <<< "$analysis_result"

# Markdownレポート生成
cat > "$OUTPUT_FILE" << EOF
# CI Triage Report - Phase 4.3

**生成日時**: $(date '+%Y-%m-%d %H:%M:%S')  
**対象期間**: $TARGET_DATE  
**分析対象**: $ARTIFACTS_PATH  

## 概要

EOF

if [[ $total_count -eq 0 ]]; then
    cat >> "$OUTPUT_FILE" << EOF
**結果**: All green 🟢

分析対象のログファイルが見つからないか、すべてのテストが成功しています。

| 項目 | 件数 |
|------|------|
| 総実行数 | 0 |
| 失敗なし | ✅ |

EOF
else
    # 成功率計算
    success_count=$((total_count - env_count - dep_count - script_count))
    success_rate=$(( success_count * 100 / total_count ))
    
    cat >> "$OUTPUT_FILE" << EOF
**総実行数**: $total_count  
**成功率**: ${success_rate}%

## 失敗分類

| 分類 | 件数 | 割合 | 説明 |
|------|------|------|------|
| 環境 | $env_count | $(( env_count * 100 / total_count ))% | パス、コマンド、権限エラー |
| 依存 | $dep_count | $(( dep_count * 100 / total_count ))% | パッケージ、モジュール不足 |
| スクリプト | $script_count | $(( script_count * 100 / total_count ))% | 構文エラー、ロジック問題 |
| **成功** | $success_count | ${success_rate}% | 正常終了 |

## 改善提案

EOF

    if [[ $env_count -gt 0 ]]; then
        cat >> "$OUTPUT_FILE" << EOF
### 環境関連 ($env_count件)
- PATH設定の確認
- 必要コマンドのインストール状況確認
- 実行権限の設定確認

EOF
    fi

    if [[ $dep_count -gt 0 ]]; then
        cat >> "$OUTPUT_FILE" << EOF
### 依存関連 ($dep_count件)
- package.json/requirements.txt の更新
- 依存パッケージのバージョン互換性確認
- lockファイルの同期確認

EOF
    fi

    if [[ $script_count -gt 0 ]]; then
        cat >> "$OUTPUT_FILE" << EOF
### スクリプト関連 ($script_count件)
- コード構文チェックの実施
- テストケースの見直し
- エラーハンドリングの強化

EOF
    fi
fi

cat >> "$OUTPUT_FILE" << EOF

## 詳細ログ参照

分析対象ディレクトリ: \`$ARTIFACTS_PATH\`

\`\`\`bash
# 詳細ログ確認コマンド
find $ARTIFACTS_PATH -name "*.log" | head -5 | xargs tail -n 20
\`\`\`

## 関連リンク

- [Phase 4.3 整合性レポート](../phase4.3_integrity_20250828_220919.md)
- [PR #8 - Phase 4.3成果](https://github.com/Driedsandwich/ucomm/pull/8)
- [CI Artifacts]($ARTIFACTS_PATH)

---
*自動生成: \`scripts/ci_triage.sh\` by Phase 4.3 CI Triage System*
EOF

echo "✅ CI Triage完了: $OUTPUT_FILE"

if [[ "$VERBOSE" == "true" ]]; then
    echo "📊 分析結果:"
    echo "  - 総実行数: $total_count"
    echo "  - 環境エラー: $env_count"
    echo "  - 依存エラー: $dep_count"
    echo "  - スクリプトエラー: $script_count"
    if [[ $total_count -gt 0 ]]; then
        echo "  - 成功率: $(( (total_count - env_count - dep_count - script_count) * 100 / total_count ))%"
    fi
fi