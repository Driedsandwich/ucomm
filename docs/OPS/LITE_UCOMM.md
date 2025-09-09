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

## エコーモードと実CLIの切替

デフォルトでは全ロールがエコーモード（入力をそのまま表示）で動作します。
実際のAI CLIを使用したい場合は以下の手順で設定してください。

### CLI検出と設定
```bash
# 利用可能なAI CLIを自動検出
lite/bin/detect-clis

# 検出結果に基づいて .env を設定
cp lite/.env.example lite/.env
# エディタで lite/.env を編集し、使用したいCLIを有効化
```

### 設定例
```bash
# エコーモードのまま（デフォルト）
BOSS_CMD=""
MANAGER_CMD=""

# 実CLIを使用
BOSS_CMD="gemini generate"
MANAGER_CMD="claude"
S1_CMD="claude"
S2_CMD="openai chat completions create --model gpt-3.5-turbo --messages"
S3_CMD=""  # エコーモードを維持
```

### 動作確認
- エコーモード: 入力内容がそのまま表示される
- 実CLIモード: AI CLIが実際に実行され、応答が表示される

## 起動確認（手動スモーク）
```bash
sudo apt-get update && sudo apt-get install -y tmux   # 未導入なら
lite/bin/detect-clis                                   # 利用可能CLI確認
cp lite/.env.example lite/.env                         # .env作成
# lite/.env を編集して必要に応じてCLI設定
lite/bin/smoke-local                                   # 起動→tell送信まで自動
lite/bin/ucomm-lite attach                              # 画面に入る（boss/floor）
```
- 各ペインにメッセージが表示されればOK。CLI未導入でもエコーモードで動作します。