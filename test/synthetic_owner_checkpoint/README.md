# 支払日チェックポイントの隔離試験

このディレクトリは、所有者別の状態・履歴と再送を使い捨て PostgreSQL で検討する試験 fixture です。**マイグレーションではありません。実 DB や実データに実行しないでください。** workflow が新規に作成した service container にだけ入力します。DB 名と実行 role のチェックだけでは隔離の証拠になりません。

`lab.owner` は caller が設定できる架空 GUC であり、Supabase Auth・JWT の代用ではありません。実ユーザー／session の認証、既存データの移行、旧 writer の遮断、RLS の実環境設定、サービスロールや既存 RPC の権限は確認していません。`fixture.sql` 内の sleep は同一 snapshot を確かめる試験専用フックです。

- 状態 hash は owner・合成 generation・revision・値・削除印を束縛し、journal は request ID と内容・結果を連鎖させます。元の request を異なる内容で再利用することは拒否します。
- transaction rollback、journal 挿入直前の故意の失敗、2接続の競合、部分的な破損、仮の過去観測点との照合、同時 commit を挟む read の snapshot を検査します。入力値はすべて架空です。
- 同一 DB の state・checkpoint・journal が整合した過去状態へ一緒に戻ると検出できません。別の場所に保持された正しい過去観測点との不一致は検出できますが、その観測点が本物か最新かはこの試験では証明できません。別々の head で実施した実験では、同一 DB 全体の巻戻りは期待どおり検出できず失敗しています。
- 実際の移行・初回設定、owner と session の結び付け、複数端末、旧 reader／writer の切替、結果不明後の復旧、履歴保持上限・増大への対処は未実装です。ローカル端末のデータを読み込んだり送信したりしません。

定義する private SECURITY DEFINER 関数は owner を表す fake GUC を内部で読み、検索パスを固定しています。invoker wrapper に加えて private 関数にも SQL 上の直接到達が可能な権限構成であるため、実用化時は到達経路と実効権限を別途審査してください。
