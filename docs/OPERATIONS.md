\## 起動→ヘルス→キャプチャ（開発既定：SECURE\_MODE=0）

```bash

cd /mnt/c/Users/<あなた>/Documents/ucomm

export UCOMM\_SECURE\_MODE=0

tmux kill-server 2>/dev/null || true

chmod +x scripts/\*.sh

scripts/ucomm-launch.sh \& echo $! > /tmp/ucomm\_pid

scripts/health.sh --json | jq -r '.summary.status'   # => "ok"

scripts/capture.sh --once

\# 終了

kill -TERM "$(cat /tmp/ucomm\_pid)" 2>/dev/null || true



