---
title: "Dart の const リストに潜む「重複エントリ」— Map なら CI が弾くのにリストは素通りする静かなバグと回帰ガード"
tags: Dart,Flutter,testing,webdev
published: false
---

Flutter/Dart で「マスターデータ」をコードに持つとき、`const List<T>` は最も手軽な選択肢です。プロバイダー一覧、機能フラグ、料金プラン、競合比較表 — こういった "手で書く辞書" はリテラルのリストとして書かれがちです。

ところがこのリスト、**同じ id を 2 回書いても誰も怒ってくれません**。今回、自分株式会社の「AI大学」プロバイダーレジストリ (223 エントリ) で `baseten` と `scale_ai` が重複していたのを見つけ、修正しました。その過程で改めて痛感した「リスト重複は静かなバグ」という一般則と、CI で二度と再発させないための回帰ガードを共有します。

## なぜ Map は安全でリストは危険なのか

Dart のコンパイラは **Map リテラルの重複キー** を検出します。

```dart
// これは analyzer が error: equal_keys_in_map で弾く
const providers = {
  'openai': '...',
  'openai': '...', // ← Error: Two keys in a constant map can't be equal.
};
```

一方、**リストの重複要素は完全に合法**です。

```dart
// これは 100% 通る。誰も気づかない
const registry = <Provider>[
  Provider(id: 'baseten', ...),
  // ...200 行後...
  Provider(id: 'baseten', ...), // ← 何のエラーも出ない
];
```

リストは「順序付きの値の集まり」であって「キーの集合」ではないので、重複は言語仕様上まったく問題ない。だからこそ、**id で一意性を期待している運用側の前提**と、**言語が保証してくれる範囲**の間にギャップが生まれます。

## 重複が引き起こす実害

`id` で一意性を暗黙に期待しているコードは、たいてい次のどれかで壊れます。

1. **`firstWhere((e) => e.id == x)` が常に先勝ち** — 後から追加した「新しくてリッチな方」のエントリが永遠に選ばれない。今回まさにこれで、URL や資金調達情報を足した新エントリが表示されない状態でした。
2. **`{for (final e in list) e.id: e}` で Map 化した瞬間、片方が黙って消える** — 件数が合わずに「なぜか 2 社足りない」系の調査に時間を溶かす。
3. **UI に同じカードが 2 枚出る** — レビューでは気づきにくく、ユーザーに指摘されて初めて発覚する。

## 検出は grep 一発

まず現状を把握します。id フィールドを抜き出して `sort | uniq -d` するだけ。

```bash
grep -oE "^\s*id: '[^']+'" lib/models/ai_provider_registry.dart \
  | grep -oE "'[^']+'" | sort | uniq -d
# => 'baseten'
#    'scale_ai'
```

「総数 223 / ユニーク 221」— 2 件の重複が即座に見えました。

## 修正方針: 消すのではなく「正典へマージ」する

重複を見つけたとき、安易に後の 1 件を消すと **情報が失われます**。今回は:

- 先に定義された正典エントリ (セクション分類が効いている / `tier` フィールド付き)
- 後から一括追加された重複エントリ (URL と資金調達メモがリッチだが `tier` 欠落)

という非対称な重複でした。そこで **リッチな note と URL を正典側にマージし、重複側を削除**。セクション構成も情報量も両方保つのが正解です。「どっちを残すか」ではなく「どちらの良いところも残すか」で考えます。

## 二度とやらないための回帰ガード

修正よりも大事なのが**再発防止**です。リストの一意性は言語が守ってくれない以上、テストで守ります。

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/ai_provider_registry.dart';

void main() {
  test('provider ids are unique', () {
    final ids = kAiProviderRegistry.map((e) => e.id).toList();
    final seen = <String>{};
    final duplicates = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) duplicates.add(id);
    }
    expect(duplicates, isEmpty,
        reason: '重複した provider id: $duplicates');
    expect(ids.toSet().length, ids.length);
  });
}
```

`Set.add` は「新規なら true / 既出なら false」を返すので、重複検出はこれだけで書けます。CI に載せておけば、次に誰か（人間でも AI エージェントでも）が id を重複させた瞬間に赤くなります。

## 一般化: 「言語が保証しない不変条件はテストで固定する」

今回の学びは AI プロバイダー registry に限りません。

- `const List` を id/キーで引くなら → 一意性テスト
- enum の全ケースに対応した `switch` を map で持つなら → 網羅性テスト
- 料金プランの順序に依存するなら → 順序テスト

**「コンパイラが守ってくれる範囲」と「運用上の前提」がズレる場所には、必ず薄い assertion を 1 枚挟む。** マスターデータをコードに持つチームには、この 1 テストが効きます。

## まとめ

- Map リテラルの重複キーは analyzer が弾くが、**リストの重複要素は完全に素通り**する
- id で一意性を期待するリストは `sort | uniq -d` で定期監査できる
- 重複修正は「削除」ではなく「正典へのマージ」で情報を守る
- 再発防止は `Set.add` を使った一意性テスト 1 枚で十分

小さな const リストほど「手で書いてるから大丈夫」と油断しがちですが、手で書いているからこそ重複が入ります。テストで固定して、安心して育てましょう。
