#!/usr/bin/env python3
"""
2週移動平均のCI成功率計算スクリプト

Usage:
    python scripts/ci/compute_2w_mavg.py [--output artifacts/ci/summary.json]

GitHub CLI ('gh') を使ってCI実行履歴を取得し、14日間の移動平均を計算します。
"""

import json
import subprocess
import sys
from datetime import datetime, timedelta
from collections import defaultdict
import argparse
import os


def run_gh_command(cmd):
    """GitHub CLI コマンドを実行"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"Error running command: {cmd}", file=sys.stderr)
            print(f"stderr: {result.stderr}", file=sys.stderr)
            return None
        return result.stdout.strip()
    except Exception as e:
        print(f"Exception running command: {cmd}: {e}", file=sys.stderr)
        return None


def get_smoke_runs():
    """GitHub APIから直近100件のsmoke実行結果を取得"""
    cmd = 'gh run list --workflow smoke.yml --limit 100 --json databaseId,headBranch,status,conclusion,createdAt'
    output = run_gh_command(cmd)
    if not output:
        return []
    
    try:
        runs = json.loads(output)
        # mainブランチのみを対象
        main_runs = [run for run in runs if run.get('headBranch') == 'main']
        return main_runs
    except json.JSONDecodeError as e:
        print(f"JSON decode error: {e}", file=sys.stderr)
        return []


def parse_runs_by_date(runs):
    """実行結果を日付別に集計"""
    daily_stats = defaultdict(lambda: {'total': 0, 'success': 0, 'failure': 0, 'cancelled': 0})
    
    for run in runs:
        try:
            # ISO 8601 format: 2025-09-01T01:33:43Z
            created_at = datetime.fromisoformat(run['createdAt'].replace('Z', '+00:00'))
            date_key = created_at.date().isoformat()
            
            conclusion = run.get('conclusion', 'unknown')
            daily_stats[date_key]['total'] += 1
            
            if conclusion == 'success':
                daily_stats[date_key]['success'] += 1
            elif conclusion == 'failure':
                daily_stats[date_key]['failure'] += 1
            elif conclusion == 'cancelled':
                daily_stats[date_key]['cancelled'] += 1
                
        except Exception as e:
            print(f"Error parsing run {run.get('databaseId')}: {e}", file=sys.stderr)
            continue
    
    return daily_stats


def compute_14day_moving_average(daily_stats, target_date=None):
    """14日移動平均を計算"""
    if target_date is None:
        target_date = datetime.now().date()
    
    # 過去14日分の日付リスト
    date_range = [(target_date - timedelta(days=i)).isoformat() for i in range(14)]
    date_range.reverse()  # 古い順に
    
    total_runs = 0
    total_success = 0
    daily_details = []
    
    for date_str in date_range:
        stats = daily_stats.get(date_str, {'total': 0, 'success': 0, 'failure': 0, 'cancelled': 0})
        total_runs += stats['total']
        total_success += stats['success']
        
        success_rate = (stats['success'] / stats['total'] * 100) if stats['total'] > 0 else 0
        daily_details.append({
            'date': date_str,
            'total': stats['total'],
            'success': stats['success'],
            'failure': stats['failure'],
            'cancelled': stats['cancelled'],
            'success_rate': round(success_rate, 2)
        })
    
    moving_avg = (total_success / total_runs * 100) if total_runs > 0 else 0
    
    return {
        'target_date': target_date.isoformat(),
        'period_days': 14,
        'moving_average_success_rate': round(moving_avg, 2),
        'total_runs_in_period': total_runs,
        'successful_runs_in_period': total_success,
        'daily_breakdown': daily_details
    }


def generate_summary(runs, output_path):
    """サマリーJSONを生成"""
    # 日付別集計
    daily_stats = parse_runs_by_date(runs)
    
    # 14日移動平均計算
    moving_avg_result = compute_14day_moving_average(daily_stats)
    
    # 全体サマリー
    summary = {
        'generated_at': datetime.now().isoformat(),
        'total_runs_analyzed': len(runs),
        'main_branch_runs_only': True,
        'moving_average_14day': moving_avg_result,
        'recent_runs': runs[:10] if runs else [],  # 直近10件
        'goal': {
            'target_success_rate': 70.0,
            'current_achievement': moving_avg_result['moving_average_success_rate'],
            'gap': round(70.0 - moving_avg_result['moving_average_success_rate'], 2)
        }
    }
    
    # artifacts/ci ディレクトリ作成
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    # JSON出力
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)
    
    print(f"Summary generated: {output_path}")
    print(f"14-day moving average: {moving_avg_result['moving_average_success_rate']}%")
    print(f"Goal (70%): {'✓ ACHIEVED' if moving_avg_result['moving_average_success_rate'] >= 70 else '✗ Gap: ' + str(summary['goal']['gap']) + '%'}")
    
    return summary


def main():
    parser = argparse.ArgumentParser(description='Compute 2-week moving average for CI success rate')
    parser.add_argument('--output', default='artifacts/ci/summary.json', 
                      help='Output file path (default: artifacts/ci/summary.json)')
    parser.add_argument('--dry-run', action='store_true',
                      help='Show results without writing file')
    
    args = parser.parse_args()
    
    # GitHub CLI認証確認
    auth_check = run_gh_command('gh auth status')
    if auth_check is None:
        print("Error: GitHub CLI authentication required. Run 'gh auth login' first.", file=sys.stderr)
        sys.exit(1)
    
    # CI実行履歴取得
    print("Fetching CI runs from GitHub...")
    runs = get_smoke_runs()
    
    if not runs:
        print("No CI runs found or error fetching data", file=sys.stderr)
        sys.exit(1)
    
    print(f"Found {len(runs)} smoke runs on main branch")
    
    if args.dry_run:
        # ドライラン（ファイル出力なし）
        daily_stats = parse_runs_by_date(runs)
        result = compute_14day_moving_average(daily_stats)
        print("DRY RUN - Results:")
        print(json.dumps(result, indent=2))
    else:
        # 通常実行
        summary = generate_summary(runs, args.output)


if __name__ == '__main__':
    main()