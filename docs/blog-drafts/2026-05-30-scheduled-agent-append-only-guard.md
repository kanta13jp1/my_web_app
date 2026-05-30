---
title: "スケジュール AI エージェントが 31,000 行のファイルを 5 行に消した日 — append-only 規律と verify-first 検知"
tags: AI,ClaudeCode,automation,devops
published: false
---

自動化された AI エージェントは便利だが、「ファイルを更新する」という単純なタスクが破壊的操作に化けることがある。本記事は、自分株式会社の運用で実際に起きた **ROADMAP truncation incident** を題材に、スケジュール実行エージェントが大きな共有ファイルを安全に更新するための **append-only 規律** と、被害を最小化した **verify-first** 検知パターンを解説する。

## 何が起きたか

成長戦略を記録する `GROWTH_STRATEGY_ROADMAP.md` は **31,323 行** まで育った単一ファイルだった。ここに、PR を main へ merge した **52 秒後**、スケジュール実行の「ロードマップ更新」エージェントの自動 commit が走った。

その commit の中身はこうだった。

```
1 insertion(+), 31,318 deletions(-)
```

ファイルはヘッダー数行だけを残して**全消し**された。原因はシンプルで、エージェントが既存の全文を読まずに「更新版」を **full Write（全文上書き）** で書き戻したこと。merge 直後で手元のチェックアウトが追従しておらず、エージェントは古い／空に近い内容を「正」として上書きしてしまった。

## なぜ気づけたか — verify-first

救いになったのは、運用ルールとして **prompt の前提を仮説として扱い、date / KPI / git / PR / issue で必ず cross-check する** verify-first を徹底していたこと。次セッション冒頭の状態確認で「ROADMAP が異常に短い」ことが即座に検知され、incident として扱われた。

復旧自体は git のおかげで一瞬だった。

```bash
# 直前の正常 commit からファイル単位で復元
git show <last-good-commit>:docs/GROWTH_STRATEGY_ROADMAP.md > docs/GROWTH_STRATEGY_ROADMAP.md
```

手で 31,000 行を再構築するのは不可能。git の immutability が「資本＝時間」を守った典型例である。

## 教訓 1: スケジュールエージェントは append-only に縛る

大きな append-only な記録ファイル（ロードマップ、変更履歴、運用ログ）に対して、自動エージェントに **full Write を許してはいけない**。許可するのは末尾追記だけ。

| 操作 | 大きな共有ファイルでの可否 |
|------|--------------------------|
| 末尾に追記（anchored append） | ✅ 安全 |
| 既存行の局所編集（unique anchor） | ⚠️ anchor が一意なら可 |
| 全文上書き（full Write） | ❌ 禁止（truncation 事故源） |

実装としては、エージェントの編集ツールを「末尾の一意な文字列を anchor にした追記」に限定する。本記事の元になったセッションでも、ROADMAP への記録は **31,364 行を 1 行も読み込み直さず**、末尾の一意行を anchor に追記する形で行った（full read も full Write もしない）。

## 教訓 2: push-to-main regression guard を置く

人間の目視に頼らず、CI/pre-receive 側で **大量削除を機械的に reject** する。

```bash
# 例: 追跡対象ファイルが N 行以上縮んだら fail
THRESHOLD=500
before=$(git show "$BASE:docs/GROWTH_STRATEGY_ROADMAP.md" | wc -l)
after=$(wc -l < docs/GROWTH_STRATEGY_ROADMAP.md)
if [ $((before - after)) -gt $THRESHOLD ]; then
  echo "::error::ROADMAP shrank by $((before - after)) lines — block destructive overwrite"
  exit 1
fi
```

既存の regression guard パターンを踏襲すれば、同種の「育ったファイルが事故で縮む」事象を横断的に止められる。

## 教訓 3: 育ちすぎたファイルは archive/split する

そもそも 31,000 行の単一 markdown は、編集・diff・事故時の被害いずれの面でもリスクが高い。期間で分割（`ROADMAP_2026H1.md` など）し、現役ファイルを小さく保つことで、1 回の事故の blast radius を縮小できる。

## まとめ

- **検知**: verify-first（前提を仮説扱い → git/状態で cross-check）が data-loss を即検知
- **復旧**: git last-good commit からのファイル単位 restore で ~5 分
- **再発防止**: ①append-only 規律（full Write 禁止）②大量削除 regression guard ③巨大ファイルの archive/split

自動化は「速さ」と引き換えに「破壊的操作の自走」というリスクを抱える。安全弁は、エージェントの権限を**追記だけに縛る**設計と、**機械的に異常を弾く**ガードの二段構えで作るのが堅い。
