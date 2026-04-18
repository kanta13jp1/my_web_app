---
title: "Supabase Edge Function 150秒タイムアウトを batch ループで回避した"
tags: Supabase,Deno,Flutter,個人開発,buildinpublic
published: false
---

# Supabase Edge Function 150秒タイムアウトを batch ループで回避した

## 問題

「自分株式会社」の競馬AI予想機能で、定期バッチ実行時に次のエラーが頻発していた:

```
TimeoutError: The read operation timed out
```

GitHub Actions 側の Python スクリプト (`scripts/fetch_horse_racing.py`) が
Supabase Edge Function の `horseracing.predict_all` を呼び出すのだが、
4プロバイダー（Anthropic/OpenAI/Google/DeepSeek）× 100件以上のレースを直列処理すると
**Supabase EF の 150秒タイムアウト上限**を超えてしまっていた。

## 原因の特定

```
4プロバイダー × 100件レース × ~0.5秒/件 ≈ 200秒 > 150秒(EF上限)
```

EF 側は `supabase.functions.invoke()` を 150秒で強制打ち切る。
Python 側はその後 `urllib` の 120秒読み取りタイムアウトで先に落ちる。

## 解決策: limit パラメータ + batch ループ

### EF 側 (Deno)

```typescript
// tools-hub: horseracing.predict_all
case 'horseracing.predict_all': {
  const limit = Math.min(body.limit ?? 20, 50); // default=20, max=50
  const rows = await supabase
    .from('horse_races')
    .select('...')
    .is('ai_prediction', null)
    .limit(limit);

  // 1バッチ分だけ処理して返す
  const results = await processBatch(rows.data);
  return new Response(JSON.stringify({
    processed: results.length,
    remaining: totalUnpredicted - results.length,
    total_unpredicted: totalUnpredicted,
  }));
}
```

### Python 側 (GitHub Actions)

```python
MAX_BATCHES = 10
BATCH_SIZE = 20

for batch_num in range(MAX_BATCHES):
    result = invoke_ef('horseracing.predict_all', {'limit': BATCH_SIZE})
    processed = result.get('processed', 0)
    remaining = result.get('remaining', 0)

    if processed == 0:
        break  # 処理対象なし or 2 batch 連続 0 で停止

    if remaining == 0:
        break  # 全件処理完了
```

## ポイント

1. **EF は「1回の呼び出しで全件処理」を諦める** — 150秒制限は Supabase の根本仕様
2. **limit を EF 側で制御** — クライアント側からの不正な大量リクエストを防ぐために `max=50` で上限設定
3. **2 batch 連続 0 で停止** — 予期しない無限ループを防ぐセーフガード
4. **残件数を返す** — Python 側がいつ終わるか判断できるように `remaining` を返す

## 結果

horse-racing-update.yml: 以前は 26分以上かかって失敗していたバッチが、
batch ループ化後は複数回に分けて正常完了するようになった。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Supabase #Deno #FlutterWeb #buildinpublic #個人開発
