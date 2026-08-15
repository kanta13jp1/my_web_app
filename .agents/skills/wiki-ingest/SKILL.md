---
name: wiki-ingest
description: |
  Karpathy AI 外部脳 Layer 3-5 (Agent Skills) 自走 ingest スキル。
  ユーザー発話 (= 「raw/ に file 入れた」「記事を ingest して」「raw に追加した」「新しい URL 取り込んで」
  「Wiki に追加」等) を自動検知し、scripts/memory_ingest.py を呼んで Atomic Note を生成 → memory/vault/
  に保存する。Karpathy 4 サイクルの Ingest フェーズを完全自走化。
  Triggers on: "/wiki-ingest", "raw/ に file 入れた", "raw/ に記事追加", "ingest して",
  "Wiki に追加", "記事を取り込んで", "新しい URL 取り込んで", "Atomic Note 生成",
  "raw/articles に置いた", "raw/papers に置いた".
---

# Wiki Ingest Skill (Karpathy Layer 3-5 Agent Skills)

Karpathy AI 外部脳の **Ingest サイクル** を自走化する skill。
ユーザーが `raw/` に新しい素材を入れた発話を検知し、`scripts/memory_ingest.py`
を起動して Obsidian 互換の Atomic Note を生成 → `memory/vault/` に保存する。

## いつ実行するか

- ユーザーが「`raw/articles/` に新しい記事 (file) を入れた」と発言した直後
- ユーザーが「この URL を ingest して」「記事をナレッジベースに取り込んで」と依頼
- セッション冒頭で `raw/articles/` `raw/papers/` `raw/repos/` `raw/datasets/` に
  未処理 (= `memory/vault/` に対応 Atomic Note なし) の file を発見した時
- `/wiki-ingest` slash command 実行時

## 検知ルール (auto-trigger)

以下の発話を検知したら **ユーザー確認なしで実行**:

1. 「`raw/` に <file 名> 入れた」「raw に追加した」
2. 「この URL を ingest」「記事を取り込んで」
3. 「Wiki に追加」「ナレッジベースに追加」
4. 「Atomic Note 生成」「memory/vault に保存」

検知が **曖昧** な場合 (= 「memory に追加」のみ等) はユーザーに確認:

> 「`raw/articles/` の <file> を Atomic Note として `memory/vault/` に保存しますか?」

## 実行ステップ

### Step 1: 未処理 file 検出

```bash
# 既存 Atomic Note と raw/ file を突合
RAW_FILES=$(find raw/articles raw/papers raw/repos raw/datasets -type f -name "*.md" 2>/dev/null)
PROCESSED=$(ls memory/vault/*.md 2>/dev/null | xargs -I{} basename {} .md | sort -u)
for f in $RAW_FILES; do
  slug=$(basename "$f" .md)
  if ! echo "$PROCESSED" | grep -q "$slug"; then
    echo "UNPROCESSED: $f"
  fi
done
```

### Step 2: memory_ingest.py 呼び出し (mode=draft)

```bash
# Local file ingest
python scripts/memory_ingest.py \
  --input-file "raw/articles/<slug>.md" \
  --mode draft \
  --tag karpathy --tag ingest-auto \
  --print
```

draft mode = `memory/ingest_drafts/` に出力. CEO 確認後 `--mode save` で `memory/vault/` 確定.

URL ingest の場合:

```bash
python scripts/memory_ingest.py \
  --url "<URL>" \
  --mode draft \
  --tag karpathy --tag ingest-auto \
  --print
```

GitHub Issue ingest:

```bash
python scripts/memory_ingest.py \
  --gh-issue <N> \
  --mode draft \
  --print
```

### Step 3: Atomic Note 確認 + save 確定

draft の内容をユーザーに提示 (要約 / related notes / tags):

```bash
cat memory/ingest_drafts/<slug>.md
```

問題なければ確定:

```bash
python scripts/memory_ingest.py \
  --input-file "raw/articles/<slug>.md" \
  --mode save \
  --tag karpathy --tag ingest-auto
```

### Step 4: memory/log.md に追記

```bash
echo "- $(date +%Y-%m-%d) ingest: <slug> (= raw/<path> → memory/vault/<slug>.md)" >> memory/log.md
```

### Step 5: Compile サイクル trigger 提案

複数 file ingest 後は `wiki-compile` skill を提案:

> 「<N> 件 Atomic Note 追加. `wiki-compile` で `docs/concepts/` + `docs/INDEX.md`
> 再生成しますか?」

## 設計判断

- **dependency-free**: `memory_ingest.py` は標準ライブラリのみ. plugin 追加不要.
- **draft → save 2-step**: AI hallucination で誤 Atomic Note 保存防止. CEO 一段確認.
- **既存 infra 再利用**: part 111 で実装済 `memory_ingest.py` を Agent Skills 層から呼ぶ
  だけ. Karpathy 4 サイクル既存資産を破壊しない.
- **MEMORY-DECAY 互換**: tag に `ingest-auto` を必ず付与 (= 30+ 日 reference 0 で
  consolidate 対象識別).

## 関連 skill

- `wiki-compile`: Atomic Note → `docs/concepts/` + `docs/INDEX.md` 自動生成
- `wiki-query`: NotebookLM 経由ゼロトークンリサーチ
- `wiki-lint`: Health Score 算出 + orphan/broken/dup 検出

## 参考

- Karpathy 元記事: https://x.com/karpathy/status/...
- 実装 part 111 (memory_ingest.py 新規)
- 実装 part 138 (Layer 1 ingest + memory/log.md)
- 実装 part 139 (本 skill / Layer 3-5 Agent Skills 化)
- principle: `docs/SECOND_BRAIN_PRINCIPLES.md` 原則 #3
