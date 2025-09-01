#!/usr/bin/env python3
"""
2週移動平均のCI成功率計算スクリプト

Usage:
    python scripts/ci/compute_2w_mavg.py [--output artifacts/ci/summary.json]
    python scripts/ci/compute_2w_mavg.py --dry-run
    python scripts/ci/compute_2w_mavg.py --since-days 7

GitHub CLI ('gh') を使ってCI実行履歴を取得し、指定期間の移動平均を計算します。
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


def check_gh_auth():
    """GitHub CLI認証状況を確認"""
    auth_output = run_gh_command('gh auth status')
    if auth_output is None:
        print("Error: GitHub CLI authentication required. Run 'gh auth login' first.", file=sys.stderr)
        return False
    return True


def get_smoke_runs(since_days=14):
    """GitHub APIから指定期間のsmoke実行結果を取得"""
    # 期間を広げて取得し、後でフィルタ
    limit = max(200, since_days * 10)  # 期間に応じて調整
    cmd = f'gh run list --workflow smoke.yml --limit {limit} --json databaseId,headBranch,status,conclusion,createdAt,jobs_url'
    output = run_gh_command(cmd)
    if not output:
        return []
    
    try:
        runs = json.loads(output)
        # mainブランチのみを対象
        main_runs = [run for run in runs if run.get('headBranch') == 'main']
        
        # 期間フィルタ
        cutoff_date = datetime.now() - timedelta(days=since_days)
        filtered_runs = []
        
        for run in main_runs:
            try:
                created_at = datetime.fromisoformat(run['createdAt'].replace('Z', '+00:00'))
                if created_at >= cutoff_date:
                    filtered_runs.append(run)
            except Exception as e:
                print(f"Error parsing date for run {run.get('databaseId')}: {e}", file=sys.stderr)
                continue
        
        return filtered_runs
    except json.JSONDecodeError as e:
        print(f"JSON decode error: {e}", file=sys.stderr)
        return []


def get_run_jobs_by_os(run):
    """特定のrunのジョブ詳細をOS別に取得"""
    jobs_url = run.get('jobs_url')
    if not jobs_url:
        return {}
    
    # GitHub API直接呼び出しでジョブ詳細取得
    run_id = run.get('databaseId')
    if not run_id:
        return {}
        
    cmd = f'gh api repos/:owner/:repo/actions/runs/{run_id}/jobs --jq ".jobs[] | {{name: .name, conclusion: .conclusion}}"'
    output = run_gh_command(cmd)
    if not output:
        return {}
    
    os_results = {}
    try:
        lines = output.strip().split('\n')
        for line in lines:
            if line.strip():
                job = json.loads(line)
                job_name = job.get('name', '')
                conclusion = job.get('conclusion', '')
                
                # ジョブ名からOS判定
                if 'ubuntu' in job_name.lower():
                    os_results['ubuntu'] = conclusion
                elif 'macos' in job_name.lower():
                    os_results['macos'] = conclusion  
                elif 'windows' in job_name.lower():
                    os_results['windows'] = conclusion
    except Exception as e:
        print(f"Error parsing jobs for run {run_id}: {e}", file=sys.stderr)
    
    return os_results


def parse_runs_with_os_details(runs):
    """実行結果をOS別詳細と共に解析"""
    overall_stats = {'total': 0, 'success': 0, 'failure': 0, 'cancelled': 0}
    os_stats = {
        'ubuntu': {'total': 0, 'success': 0, 'failure': 0, 'cancelled': 0},
        'macos': {'total': 0, 'success': 0, 'failure': 0, 'cancelled': 0},
        'windows': {'total': 0, 'success': 0, 'failure': 0, 'cancelled': 0}
    }
    
    for run in runs:
        try:
            conclusion = run.get('conclusion', 'unknown')
            overall_stats['total'] += 1
            
            if conclusion == 'success':
                overall_stats['success'] += 1
            elif conclusion == 'failure':
                overall_stats['failure'] += 1
            elif conclusion == 'cancelled':
                overall_stats['cancelled'] += 1
            
            # OS別詳細取得（簡略化版：API負荷を考慮して一部のrunのみ）
            # 実際の運用では、GitHub matrix strategyを活用したより効率的な方法を検討
            if overall_stats['total'] <= 50:  # 最新50件のみ詳細解析
                os_results = get_run_jobs_by_os(run)
                
                for os_name in ['ubuntu', 'macos', 'windows']:
                    if os_name in os_results:
                        os_stats[os_name]['total'] += 1
                        os_conclusion = os_results[os_name]
                        if os_conclusion == 'success':
                            os_stats[os_name]['success'] += 1
                        elif os_conclusion == 'failure':
                            os_stats[os_name]['failure'] += 1
                        elif os_conclusion == 'cancelled':
                            os_stats[os_name]['cancelled'] += 1
                            
        except Exception as e:
            print(f"Error parsing run {run.get('databaseId')}: {e}", file=sys.stderr)
            continue
    
    return overall_stats, os_stats


def compute_success_rates(stats):
    """統計から成功率を計算"""
    total = stats['total']
    success = stats['success']
    
    success_rate = (success / total * 100) if total > 0 else 0.0
    
    return {
        'success_rate': round(success_rate, 1),
        'success': success,
        'total': total
    }


def generate_summary(runs, output_path, window_days=14):
    """サマリーJSONを生成"""
    # OS別詳細解析
    overall_stats, os_stats = parse_runs_with_os_details(runs)
    
    # 成功率計算
    overall_result = compute_success_rates(overall_stats)
    
    # OS別成功率（データが十分でない場合はnull）
    by_os = {}
    for os_name in ['ubuntu', 'macos', 'windows']:
        if os_stats[os_name]['total'] > 0:
            by_os[os_name] = compute_success_rates(os_stats[os_name])
        else:
            by_os[os_name] = None
    
    # 目標達成率
    target_rate = 70.0
    current_rate = overall_result['success_rate']
    gap = round(current_rate - target_rate, 1)
    
    # 要件準拠のJSONスキーマ
    summary = {
        'generated_at': datetime.now().replace(microsecond=0).isoformat() + '+09:00',
        'window_days': window_days,
        'overall': overall_result,
        'by_os': by_os,
        'goal': {
            'target_success_rate': target_rate,
            'gap': gap
        }
    }
    
    # artifacts/ci ディレクトリ作成
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    # JSON出力
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)
    
    print(f"Summary generated: {output_path}")
    print(f"{window_days}-day success rate: {current_rate}%")
    print(f"Goal (70%): {'✓ ACHIEVED' if current_rate >= target_rate else '✗ Gap: ' + str(gap) + '%'}")
    
    return summary


def main():
    parser = argparse.ArgumentParser(description='Compute moving average for CI success rate')
    parser.add_argument('--output', default='artifacts/ci/summary.json', 
                      help='Output file path (default: artifacts/ci/summary.json)')
    parser.add_argument('--dry-run', action='store_true',
                      help='Show results without writing file')
    parser.add_argument('--since-days', type=int, default=14,
                      help='Number of days to analyze (default: 14)')
    
    args = parser.parse_args()
    
    # GitHub CLI認証確認
    if not check_gh_auth():
        sys.exit(1)
    
    # CI実行履歴取得
    print(f"Fetching CI runs from GitHub (last {args.since_days} days)...")
    runs = get_smoke_runs(since_days=args.since_days)
    
    if not runs:
        print("No CI runs found or error fetching data", file=sys.stderr)
        sys.exit(1)
    
    print(f"Found {len(runs)} smoke runs on main branch")
    
    if args.dry_run:
        # ドライラン（ファイル出力なし）
        overall_stats, os_stats = parse_runs_with_os_details(runs)
        overall_result = compute_success_rates(overall_stats)
        
        dry_run_result = {
            'window_days': args.since_days,
            'overall': overall_result,
            'runs_analyzed': len(runs)
        }
        
        print("DRY RUN - Results:")
        print(json.dumps(dry_run_result, indent=2, ensure_ascii=False))
    else:
        # 通常実行
        summary = generate_summary(runs, args.output, window_days=args.since_days)


if __name__ == '__main__':
    main()