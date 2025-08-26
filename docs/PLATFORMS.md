```md

\# docs/PLATFORMS.md — OS差分リファレンス（常設）



この文書は ucomm の日常運用で遭遇しやすい \*\*OS/端末差分\*\* と \*\*回避策\*\* を恒常公開します。



---



\## 対象

\- \*\*WSL2 (Ubuntu 22.04/24.04)\*\* on Windows

\- \*\*macOS\*\*（Terminal / iTerm2）

\- \*\*Linux (Ubuntu 22.04/24.04)\*\*



---



\## 一覧（要点）



| 項目 | WSL2 | macOS | Linux |

|---|---|---|---|

| tmux pane 分割 | \*\*端末幅/文字幅で失敗あり\*\* | 安定（iTerm2 推奨） | 概ね安定 |

| 改行コード（CRLF） | Windows 側編集で発生しやすい | まれ | まれ |

| `yq`/`jq` | `apt` で導入必要 | `brew` で導入 | `apt` で導入 |

| PATH / コマンド検出 | Windows PATH と混在注意 | 安定 | 安定 |



---



\## 既知の事象と対処



\### 1) tmux pane 分割が失敗する（WSL2）

\- \*\*症状\*\*: `no space for new pane`、意図しない 1-pane 起動。

\- \*\*対処\*\*:

&nbsp; - 端末サイズを \*\*120x30 以上\*\* に広げる（フォント等幅推奨）。

&nbsp; - `tmux list-windows` で実レイアウト確認（`ucomm-launch.sh` は起動時に自動ダンプ）。

&nbsp; - 失敗時は `tmux kill-server` → 再起動。



\### 2) 改行コード（CRLF）警告

\- \*\*症状\*\*: `CRLF will be replaced by LF` が Git で出る。

\- \*\*対処\*\*: エディタ側で LF 固定。Git は自動置換されるため機能的影響はなし。



\### 3) `yq` / `jq` 未インストール

\- \*\*対処\*\*:

&nbsp; - WSL/Linux: `sudo apt update \&\& sudo apt install -y jq yq`

&nbsp; - macOS: `brew install jq yq`



\### 4) PATH による CLI 検出

\- \*\*症状\*\*: `missing\_bins` による degraded。

\- \*\*対処\*\*: `config/cli\_adapters.yaml` の `cmd` 名が PATH で解決できるか確認（未導入は placeholder で運転自体は継続）。



---



\## 推奨端末

\- \*\*macOS\*\*: iTerm2 推奨（Terminal も可）。

\- \*\*Windows\*\*: Windows Terminal + WSL2（Ubuntu）。VS Code 経由のシェルでも可。



---



\## 参考

\- 運用手順: `docs/OPERATIONS.md`（「WSL の既知差分はこちら」へのリンク元）



```



