#!/usr/bin/env python3
"""
2週移動平均のCI成功率計算スクリプト（gh CLIの仕様変更に追随）

- gh run list の JSON フィールド集合に合わせて修正（jobs_url を要求しない）
- ジョブ詳細は run_id から runs/{id}/jobs API で取得

Usage:
    python scripts/ci/compute_2w_mavg.py [--output artifacts/ci/summary.json]
    python scripts/ci/compute_2w_mavg.py --dry-run
    python scripts/ci/compute_2w_mavg.py --since-days 14
"""

import json
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from collections import defaultdict
import argparse
import os

def run_gh_command(cmd):
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
    out = run_gh_command('gh auth status')
    if out is None:
        print("Error: GitHub CLI authentication required. Run 'gh auth login' first.", file=sys.stderr)
        return False
    return True

def get_smoke_runs(since_days=14):
    """
    指定期間の smoke ワークフロー（mainブランチ）の実行を取得
    ※ gh run list の --json は、現行 CLI が返すフィールドのみに限定
    """
    limit = max(200, since_days * 10)
    # jobs_url は要求しない（存在しないため）
    fields = "databaseId,headBranch,status,conclusion,createdAt,workflowName,headSha"
    cmd = f'gh run list --workflow smoke.yml --limit {limit} --json {fields}'
    output = run_gh_command(cmd)
    if not output:
        return []

    try:
        runs = json.loads(output)
    except json.JSONDecodeError as e:
        print(f"JSON decode error: {e}", file=sys.stderr)
        return []

    # main のみ
    runs = [r for r in runs if r.get("headBranch") == "main"]

    # 期間フィルタ（UTC基準）
    cutoff = datetime.now(timezone.utc) - timedelta(days=since_days)
    filtered = []
    for r in runs:
        try:
            # createdAt は ISO8601（Z 終端）。UTC で扱う
            created_at = r.get("createdAt")
            if not created_at:
                continue
            dt = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
            if dt >= cutoff:
                filtered.append(r)
        except Exception as e:
            print(f"Error parsing date for run {r.get('databaseId')}: {e}", file=sys.stderr)
            continue
    return filtered

def get_run_jobs_by_os(run_id):
    """
    特定 run_id の jobs を取得して OS 別に結論を要約
    """
    if not run_id:
        return {}

    # gh api で jobs 配列を 1 行 1 JSON にして取り出す
    cmd = (
        f'gh api repos/:owner/:repo/actions/runs/{run_id}/jobs '
        f'--jq ".jobs[] | {{name: .name, conclusion: .conclusion}}"'
    )
    output = run_gh_command(cmd)
    if not output:
        return {}

    os_results = {}
    try:
        for line in output.strip().splitlines():
            if not line.strip():
                continue
            job = json.loads(line)
            name = (job.get("name") or "").lower()
            concl = job.get("conclusion", "")
            if "ubuntu" in name:
                os_results["ubuntu"] = concl
            elif "macos" in name:
                os_results["macos"] = concl
            elif "windows" in name:
                os_results["windows"] = concl
    except Exception as e:
        print(f"Error parsing jobs for run {run_id}: {e}", file=sys.stderr)
    return os_results

def parse_runs_with_os_details(runs):
    overall = {'total': 0, 'success': 0, 'failure': 0, 'cancelled': 0}
    os_stats = {
        'ubuntu':  {'total': 0, 'success': 0, 'failure': 0, 'cancelled': 0},
        'macos':   {'total': 0, 'success': 0, 'failure': 0, 'cancelled': 0},
        'windows': {'total': 0, 'success': 0, 'failure': 0, 'cancelled': 0},
    }

    for idx, run in enumerate(runs, start=1):
        try:
            conclusion = run.get('conclusion') or 'unknown'
            overall['total'] += 1
            if conclusion == 'success':
                overall['success'] += 1
            elif conclusion == 'failure':
                overall['failure'] += 1
            elif conclusion == 'cancelled':
                overall['cancelled'] += 1

            # 最新50件だけ OS 詳細を見る
            if idx <= 50:
                run_id = run.get('databaseId')
                os_results = get_run_jobs_by_os(run_id)
                for os_name, res in os_results.items():
                    if os_name in os_stats:
                        os_stats[os_name]['total'] += 1
                        if res == 'success':
                            os_stats[os_name]['success'] += 1
                        elif res == 'failure':
                            os_stats[os_name]['failure'] += 1
                        elif res == 'cancelled':
                            os_stats[os_name]['cancelled'] += 1
        except Exception as e:
            print(f"Error parsing run {run.get('databaseId')}: {e}", file=sys.stderr)
            continue
    return overall, os_stats

def compute_success_rates(stats):
    total = stats['total']
    success = stats['success']
    rate = (success / total * 100.0) if total > 0 else 0.0
    return {'success_rate': round(rate, 1), 'success': success, 'total': total}

def generate_summary(runs, output_path, window_days=14):
    overall_stats, os_stats = parse_runs_with_os_details(runs)
    overall_result = compute_success_rates(overall_stats)

    by_os = {}
    for os_name in ['ubuntu', 'macos', 'windows']:
        if os_stats[os_name]['total'] > 0:
            by_os[os_name] = compute_success_rates(os_stats[os_name])
        else:
            by_os[os_name] = None

    target_rate = 70.0
    current_rate = overall_result['success_rate']
    gap = round(current_rate - target_rate, 1)

    # 生成時刻は JST 表示（±不要なら UTC にしても可）
    jst = timezone(timedelta(hours=9))
    summary = {
        'generated_at': datetime.now(jst).replace(microsecond=0).isoformat(),
        'window_days': window_days,
        'overall': overall_result,
        'by_os': by_os,
        'goal': {'target_success_rate': target_rate, 'gap': gap}
    }

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)

    print(f"Summary generated: {output_path}")
    print(f"{window_days}-day success rate: {current_rate}%")
    print(f"Goal (70%): {'✓ ACHIEVED' if current_rate >= target_rate else '✗ Gap: ' + str(gap) + '%'}")
    return summary

def main():
    parser = argparse.ArgumentParser(description='Compute moving average for CI success rate')
    parser.add_argument('--output', default='artifacts/ci/summary.json', help='Output file path')
    parser.add_argument('--dry-run', action='store_true', help='Show results without writing file')
    parser.add_argument('--since-days', type=int, default=14, help='Number of days to analyze')

    args = parser.parse_args()
    if not check_gh_auth():
        sys.exit(1)

    print(f"Fetching CI runs from GitHub (last {args.since_days} days)...")
    runs = get_smoke_runs(since_days=args.since_days)
    if not runs:
        print("No CI runs found or error fetching data", file=sys.stderr)
        sys.exit(1)

    print(f"Found {len(runs)} smoke runs on main branch")
    if args.dry_run:
        overall_stats, _ = parse_runs_with_os_details(runs)
        overall_result = compute_success_rates(overall_stats)
        print("DRY RUN - Results:")
        print(json.dumps({
            'window_days': args.since_days,
            'overall': overall_result,
            'runs_analyzed': len(runs)
        }, indent=2, ensure_ascii=False))
    else:
        generate_summary(runs, args.output, window_days=args.since_days)

if __name__ == '__main__':
    main()
