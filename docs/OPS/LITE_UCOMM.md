# ライト版 ucomm（CCC/tmux）

## 目的
- Boss/Manager/S1/S2/S3 を tmux 上に常設。
- 許可ルートのみ `lite/bin/tell` でメッセージ転送（Boss↔Manager、Manager↔S*）。

## セットアップ
```bash
sudo apt-get update && sudo apt-get install -y tmux
cp lite/.env.example lite/.env   # 必要なら CLI 名を調整
```

## 起動・接続
```bash
lite/bin/ucomm-lite start
lite/bin/ucomm-lite attach
```

- Window `boss`（1ペイン：人間↔Boss）
- Window `floor`（4ペイン：manager / s1 / s2 / s3）

## ACL送信例
```bash
lite/bin/tell boss manager "要件Aをタスク化して"
lite/bin/tell manager s1   "health.shを用意して"
lite/bin/tell s1 manager   "完了。PR #123"
```

## 状態・停止
```bash
lite/bin/ucomm-lite status
lite/bin/ucomm-lite stop
```