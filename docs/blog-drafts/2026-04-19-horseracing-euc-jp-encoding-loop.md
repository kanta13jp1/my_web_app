---
title: "競馬データ取得バッチが毎時36分かかっていた本当の原因 — EUC-JP文字化けが生んだ無限ループ"
tags: Python,Supabase,GitHub Actions,個人開発,buildinpublic
published: true
---

# 競馬データ取得バッチが毎時36分かかっていた本当の原因 — EUC-JP文字化けが生んだ無限ループ

## TL;DR

- 地方競馬（NAR）のWebページは **EUC-JP** エンコーディング
- UTF-8でデコードすると U+FFFD（文字化け）が混入する
- バッチが文字化けレースを「異常データ」と判定して毎時削除 → EUC-JPで再登録 → 535頭分の prev_history_fetched フラグがリセット
- 3段階の根本原因を特定して修正 → **36分 → 3分（92%削減）**

---

## 背景：競馬AI予想バッチの構成

「自分株式会社」では GitHub Actions を使って毎時 JRA（中央競馬）と NAR（地方競馬）の出走データを取得し、AI予想を生成している。

```
horse-racing-update.yml (毎時)
  ↓
scripts/fetch_horse_racing.py
  ├── fetch_entries()       # 出走表取得・DB登録
  ├── fetch_horse_histories() # 馬の過去成績取得
  └── generate_predictions() # AI予想生成
```

ある時点から、このバッチが **毎時36分以上** かかるようになっていた。

---

## 3段階の根本原因チェーン

問題の根本は **3層の独立した欠陥** が重なっていた。

### 原因1: prev_history_fetched フラグ不足（Session 1-2 で修正済み）

馬の過去成績取得（`fetch_horse_histories()`）は netkeiba.com に馬ごとにHTTPリクエストを投げる。404エラー（引退・抹消馬）が返っても、フラグ管理がなければ毎時リトライしてしまう。

```python
# 修正前: 404でもフラグを立てない
response = requests.get(f"https://db.netkeiba.com/horse/{horse_id}/")
if response.status_code == 404:
    continue  # フラグなし → 次回また試みる

# 修正後: 404馬をバッチ PATCHで prev_history_fetched=true に
batch_404_ids.append(horse_id)
# 最後にまとめて更新
supabase.table("horse_entries").update({"prev_history_fetched": True}) \
    .in_("horse_id", batch_404_ids).execute()
```

### 原因2: time.sleep(1) の無条件発火（Session 4 で修正済み）

レート制限対策の `time.sleep(1)` が **404馬にも適用** されていた。

```python
# 修正前: 404でも sleep(1)
response = requests.get(url)
time.sleep(1)  # ← 404馬1060頭 × 1秒 = 17.7分
if response.status_code == 404:
    continue
```

404馬1060頭 × 1秒 = **17.7分**の無駄な待機。

```python
# 修正後: 成功時のみ sleep
response = requests.get(url)
if response.status_code == 404:
    batch_404_ids.append(horse_id)
    continue  # sleepなし
time.sleep(1)  # 成功時のみ
```

### 原因3: NAR EUC-JP 文字化けループ（Session 5 で根本修正）

**これが最も見つけにくかった問題。**

NAR（地方競馬）のWebサイトは EUC-JP エンコーディングを使っている。Python の `requests` はデフォルトで `response.text` を UTF-8 としてデコードする（`apparent_encoding` が `ISO-8859-1` になることも多い）。

```python
# 問題のあるコード
response = requests.get(nar_url)
html = response.text  # ← UTF-8として解釈 → 文字化け(U+FFFD)混入
```

これにより、レース名に `\ufffd\ufffd\ufffd` が混入した状態でDBに登録される。

```
登録されたレース名: "地\ufffd\ufffd\ufffd競馬\ufffd\ufffd\ufffd"
正しいレース名:   "地方競馬レース情報"
```

#### 文字化けループの連鎖

バッチには **`_clean_garbled_races()`** という「異常データ検出・削除」ロジックがある:

```python
def _clean_garbled_races():
    """U+FFFD を含むレースを削除して再取得を促す"""
    races_with_garbled = supabase.table("horse_races") \
        .select("*") \
        .like("race_name", "%\ufffd%") \
        .execute()
    
    for race in races_with_garbled.data:
        # レース削除 → 出走馬も削除
        supabase.table("horse_entries") \
            .delete().eq("race_id", race["id"]).execute()
        supabase.table("horse_races") \
            .delete().eq("id", race["id"]).execute()
```

EUC-JPページをUTF-8として読む → 文字化けレース登録 → 毎時削除 → 再登録 → **ループ**

結果として、NAR の 56 レース・**535頭** が毎時 `prev_history_fetched=false` にリセットされ、毎時17分の歴史取得が走り続けていた。

#### 修正: NAR URLを確実に EUC-JP デコード

```python
def http_get(url: str) -> str:
    response = requests.get(url, timeout=30)
    raw = response.content  # バイト列で取得
    
    # NAR は EUC-JP 確定（UTF-8 fallback を禁止）
    if "nar.netkeiba.com" in url:
        return raw.decode("euc-jp", errors="replace")
    
    # JRA / その他はUTF-8
    return raw.decode("utf-8", errors="replace")
```

`errors="replace"` は残しているが、EUC-JPを正しく指定すれば文字化けは発生しない。

---

## 効果の計測

修正を段階的にリリースして GitHub Actions の実行時間を計測した。

| 段階 | コミット | 実行時間 |
|------|---------|---------|
| ベースライン | — | **36分** |
| sleep fix（原因2修正） | `52f8b40b` | **12分** |
| EUC-JP fix（原因3修正）遷移 run | `1c8a6113` | 12分（535頭再登録中） |
| EUC-JP fix 安定後 | `1c8a6113` | **3分** |

**36分 → 3分（92%削減）**を達成した。

遷移 run（`24628893253`）では、文字化けレコードの削除と EUC-JP での再登録が実行された:

```
fetch_entries: JRA 36 SKIP + NAR 42件 CLEAN (文字化けレコード削除)
  → 56NAR レース / 535頭 EUC-JPで再登録
fetch_horse_histories: [DONE] 0頭更新, 535頭スキップ (404済み)
  → 535頭全員 batch PATCH で prev_history_fetched=true 済み
  → sleep なしで高速処理 (sleep fix が機能)
```

翌日の初回 run（新規レース登録）は13分かかるが、2回目以降は3分で完了する。

---

## 学んだこと

### 1. 日本のWebサイトはまだ EUC-JP を使っている

NAR（地方競馬）のような古いシステムは EUC-JP が現役。スクレイピング時は `response.content` (バイト列) を取得してから手動デコードするのが安全。

```python
# 安全なパターン
raw = requests.get(url).content
if is_eucjp_site(url):
    text = raw.decode("euc-jp", errors="replace")
else:
    text = raw.decode("utf-8", errors="replace")
```

### 2. 「異常データ検出・削除」ロジックは無限ループの温床

入力データが常に異常な状態 → 削除 → 再取得 → また異常 → ループ。
「削除して再取得」ではなく「正しくデコードして上書き」が根本解決。

### 3. 問題の複合化に注意

今回は3つの独立した問題が重なっていた。1つ修正しても残りの問題で遅い状態が続くため、「修正できていない」と誤認識しやすい。段階的に計測しながら修正するのが重要。

### 4. 移行 run（遷移期間）を想定する

EUC-JP fix の最初の run は12分かかった。これは「文字化けレコードの削除 + 再登録」という一時的な処理が走るため。2回目以降が3分になることで成功を確認した。

---

## まとめ

日本語エンコーディングの問題は地味だが影響が大きい。今回は:

1. EUC-JP → UTF-8 の誤デコードが毎時の無限ループを引き起こした
2. 「異常データ検出・削除」という防御的ロジックが逆に問題を悪化させた
3. 3段階の問題を順番に特定・修正することで 92% の性能改善を達成した

---

自分株式会社: <https://my-web-app-b67f4.web.app/>
#Python #GithubActions #Supabase #競馬 #buildinpublic #個人開発
