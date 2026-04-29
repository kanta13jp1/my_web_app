---
title: "Product Hunt ローンチ完全ガイド — インディー開発者が初日 TOP10 に入るための戦略"
tags: 個人開発,AI,indiedev,flutter
published: true
---

# Product Hunt ローンチ完全ガイド — インディー開発者が初日 TOP10 に入るための戦略

Product Hunt は新しいプロダクトを発見するコミュニティです。適切な準備とタイミングで、ローンチ当日に大量のトラフィックとユーザーを獲得できます。

## Product Hunt の仕組み

- **投票期間**: 太平洋時間 (PST) の 00:00〜23:59 (JST では 17:00〜翌16:59)
- **ランキング**: 当日の Upvote 数で決定
- **露出**: TOP5 はメールニュースレター (500万人) に掲載
- **フォロワー**: 事前にフォロワーを集めると投票依頼しやすい

## ローンチ前の準備 (1ヶ月前〜)

### プロフィールと Upcoming Page を整備

```
Product Hunt プロフィール必須事項:
✅ 顔写真 (信頼性 UP)
✅ Twitter/X 連携
✅ 過去のプロダクト実績
✅ Upcoming Page で事前登録を集める
```

### Maker コミュニティに参加

Product Hunt で成功している人たちと事前に繋がります:
- Twitter/X で `#buildinpublic` タグで発信
- Product Hunt のディスカッションに参加
- Indie Hackers フォーラムで顔を売る

### Hunter を探す

有名な Hunter (影響力のあるユーザー) にハンティングしてもらうと初速が変わります。候補探し:
- フォロワー 1,000+ の Hunter
- 自分のカテゴリを頻繁にハントしている人
- 1〜2ヶ月前に依頼

## 素材の準備

### ギャラリー画像 (最重要)

```
推奨構成 (5枚):
1枚目: プロダクトのコアバリュー (キャッチコピー + スクリーンショット)
2枚目: 主要機能の説明
3枚目: ユーザーのユースケース
4枚目: 機能リスト or 競合比較
5枚目: 料金プランまたは実績
```

**ツール**: Figma / Canva / Pika.style

### デモ動画 (60秒以内)

```
理想的な構成:
0:00-0:10: 課題提示 (共感を引く)
0:10-0:40: ソリューション実演 (ハンズオン)
0:40-1:00: CTA (今すぐ試せる / 無料)
```

**ツール**: Loom / Screen Studio / QuickTime

### ローンチテキスト

```
Tagline (60文字以内): "AIがあなたの毎日の判断をサポートするライフマネジメントアプリ"
Description (260文字以内): 
  - 誰のための製品か
  - どんな問題を解決するか
  - 競合との差別化
  - 特別なオファー (ローンチ限定 30% OFF 等)
```

## ローンチ当日の動き (PST 00:00 = JST 17:00)

### 時系列スケジュール

```
JST 17:00  ローンチ (ハント実行 or 自分でハント)
JST 17:05  Twitter/X にローンチ告知ツイート
JST 17:10  既存ユーザーにメール送信 (Resend等)
JST 17:30  Slack コミュニティ告知
JST 18:00  Indie Hackers / Reddit 投稿
JST 19:00〜 コメントに丁寧に返信 (アルゴリズム UP)
```

### 告知メールの例

```
件名: 🚀 [プロダクト名] が Product Hunt に登場しました！

こんにちは [名前] さん、

今日、[プロダクト名] を Product Hunt でローンチしました。

もし価値を感じていただけていたら、1クリックでサポートをお願いします:
👉 https://www.producthunt.com/posts/[product-slug]

[Upvote ボタン画像]

コメントもいただけると大変励みになります。
今後もご支援よろしくお願いいたします。

[名前]
```

## Flutter アプリのローンチバナー実装

```dart
// アプリ内バナーでローンチを告知
class ProductHuntBanner extends StatelessWidget {
  const ProductHuntBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(
        'https://www.producthunt.com/posts/jibun-ai',
      )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: const Color(0xFFDA552F), // Product Hunt オレンジ
        child: Row(
          children: [
            const Text('🚀', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Product Hunt でローンチ中！投票お願いします',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const Icon(Icons.open_in_new, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}
```

## Supabase でローンチトラフィックを計測

```sql
-- ローンチ日のトラフィック記録
CREATE TABLE launch_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  source TEXT,  -- 'producthunt', 'twitter', 'email', etc.
  event_type TEXT,  -- 'signup', 'visit', 'upgrade'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ローンチ日の時間別集計
SELECT
  DATE_TRUNC('hour', created_at) AT TIME ZONE 'Asia/Tokyo' AS hour_jst,
  source,
  COUNT(*) AS events
FROM launch_events
WHERE created_at >= '2029-03-03'::date
GROUP BY 1, 2
ORDER BY 1, 2;
```

## まとめ

Product Hunt ローンチは「当日だけ頑張る」より「1ヶ月前からの準備」が鍵です。コミュニティとの関係構築・高品質な素材・当日の丁寧なコメント返信で、初日 TOP10 を狙えます。

---

自分株式会社では Flutter × Supabase でAIライフマネジメントアプリを開発中。個人開発の知見を毎週発信しています。
