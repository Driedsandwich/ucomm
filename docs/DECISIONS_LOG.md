# DECISIONS_LOG

## 2025-08-11
- **COUNCILモードの役職なし化**
  - 理由：討論形式で上下関係を排除するため
  - 実装時期：Phase4
  - 現状：役職ありのまま稼働、Phase4でrole==null対応予定

- **retry設定のYAML化（将来計画）**
  - 理由：Phase5以降の自動化を見据え、手動指定の負担を軽減
  - 追加先：config/topology.yaml
