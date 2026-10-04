---
name: send_later 呼び出し中の classifier 一時エラー — リトライ上限の遵守
description: PR babysitチェックインのスケジューリングでsend_laterが3回連続"no verdict"エラーを返した際、ツールのガイダンスに従いリトライを止めてユーザーに透明に報告した判断。
type: feedback
---

PR #5523 のマージ確認チェックインを再スケジュールしようと `mcp__Claude_Code_Remote__send_later` を
呼んだ際、"server-side auto mode classifier gave no verdict (error)" が3回連続で返った。
エラーメッセージは明確に「1回だけ再試行可。繰り返すと遅延が増え、10回連続で止まる」と指示していたため、
3回目の失敗後にリトライを止め、ユーザーに「これはツールの一時故障であり拒否ではない」「PR自体の状態は
変化なし」と平易に報告した。

**Why:** エラーメッセージの指示 (リトライ回数の上限) を無視して無限リトライすると、
ツール呼び出しが止まるまで無駄にループしかねない。エラーの種類 (transient failure vs 拒否) を
区別してユーザーに伝えることが重要。
**How to apply:** ツールエラーに具体的なリトライ回数の上限や挙動が書かれている場合は、
その指示に正確に従う。拒否 (ユーザーの意図的な denial) と一時的な技術的失敗 (classifier error 等) は
明確に区別して報告する。
