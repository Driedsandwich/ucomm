# Security Policy
- 本リポジトリには秘匿情報（鍵・トークン・個人情報）を含めないでください。
- 機密情報の誤コミットを検知した場合：
  1) 直ちに Issue を作成（ラベル: security, documentation）。テンプレ「Handoff」を用い、該当コミット/ファイルと経緯を要約。
  2) 履歴除去と再発防止策を docs/HISTORY に要約し、秘匿分離方針（AGGREGATION_POLICY）に従って公開範囲を再評価。
- センシティブで公開不可の場合は、Issue を作成せず、メンテナ（@Driedsandwich）に直接通知してください。
- `docs/HISTORY/AGGREGATION_POLICY.md` の秘匿分離に従い、公開・非公開の線引きを守ってください。