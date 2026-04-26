-- PS#3 S63: AI大学 220→221社化 — Framer AI 追加
-- Framer AI: AI Webサイトビルダー / 自然言語でサイト生成 / React出力 / デザイナー特化

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'framer-ai',
  'overview',
  'Framer AI — AI Webサイトビルダー (自然言語でサイト生成 / React出力 / デザイナー特化)',
  $$## Framer AI — AI Webサイトビルダー

**カテゴリ**: AI Website Builder / No-Code / Design Tool
**設立**: 2013年 / 本社: Amsterdam, Netherlands / 資金調達: ~$47M
**特徴**: プロンプトを入力するだけで本格的な Web サイトを即時生成、React コードとして出力可能
**ユーザー**: デザイナー / スタートアップ創業者 / フリーランサー / マーケター
**評価**: 8/9

### 概要
Framer は元々プロトタイピングツールとして知られていたが、2023〜2024年に **AI Website Builder** へと大きく進化した。「コーヒーショップのサイトを作って」などのプロンプトを入力するだけで、数秒でデザイン・コピーライティング・レイアウトが完成したサイトを生成する。生成されたサイトは React ベースで、デザイナーが細部をカスタマイズでき、Framer のホスティングで即公開可能。Webflow より直感的・Squarespace より柔軟・Figma より直接公開できる点が差別化。

### 主な特長
- **AI サイト生成**: 自然言語プロンプト → サイト全体 (レイアウト/コピー/画像/カラー) を数秒生成
- **AI テキスト生成**: ページ内のテキストをプロンプトで書き換え・翻訳・言い換え
- **AI 画像生成**: ページ内の画像を AI で生成・置換 (Stable Diffusion 統合)
- **React コンポーネント**: デザインを React コードとして export / カスタムコードの埋め込み可
- **アニメーション**: スクロール連動・インタラクションアニメーションをノーコードで設定
- **CMS 統合**: Framer CMS でブログ・ポートフォリオ・製品ページのデータ管理
- **多言語対応**: 自動翻訳機能で多言語サイトを数クリックで生成
- **Framer Motion**: React アニメーションライブラリの開発元 (OSS / 週間DL 700万+)

### 競合との差別化
| 項目 | Framer AI | Webflow | Squarespace | WordPress |
|------|-----------|---------|-------------|-----------|
| AI 生成 | ✅ 業界最高 | △ (限定) | △ (限定) | ❌ |
| デザイン自由度 | ★★★★★ | ★★★★★ | ★★★ | ★★ |
| React export | ✅ | ❌ | ❌ | ❌ |
| 学習コスト | 低〜中 | 高 | 低 | 中 |
| 価格 | 中 | 高 | 中 | 低 |
| ホスティング | ✅ 組込 | ✅ 組込 | ✅ 組込 | 別途 |

### 導入コスト
- **Free**: カスタムドメイン不可 / framer.website サブドメイン / ページ無制限
- **Mini**: 月 $5 / カスタムドメイン1個 / ステージング環境
- **Basic**: 月 $15 / カスタムドメイン1個 / CMS 最大 1,000件
- **Pro**: 月 $30 / カスタムドメイン無制限 / CMS 最大 10,000件 / パスワード保護
- **Enterprise**: カスタム / SLA / SSO / 優先サポート$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'framer-ai',
  'api',
  'Framer API / Framer Motion — React アニメーション OSS ライブラリ + CMS API (Python/TypeScript)',
  $$## Framer エコシステム

### Framer Motion — React アニメーションライブラリ (OSS)
Framer が開発・OSS 公開している React アニメーションライブラリ。
週間 DL 700万+ / GitHub 23,000+ Stars / MIT ライセンス

```bash
npm install framer-motion
```

```tsx
// 基本アニメーション
import { motion } from "framer-motion"

export function AnimatedCard() {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, ease: "easeOut" }}
      whileHover={{ scale: 1.05, boxShadow: "0px 10px 30px rgba(0,0,0,0.2)" }}
      whileTap={{ scale: 0.95 }}
      style={{
        background: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
        borderRadius: 16,
        padding: 24,
        cursor: "pointer",
      }}
    >
      <h2 style={{ color: "white" }}>AI大学プロバイダーカード</h2>
    </motion.div>
  )
}
```

```tsx
// スクロール連動アニメーション (Framer Motion)
import { motion, useScroll, useTransform } from "framer-motion"

export function ParallaxSection() {
  const { scrollYProgress } = useScroll()
  const y = useTransform(scrollYProgress, [0, 1], ["0%", "50%"])
  const opacity = useTransform(scrollYProgress, [0, 0.5, 1], [1, 0.8, 0])

  return (
    <motion.section style={{ y, opacity }}>
      <h1>自分株式会社 — AIライフマネジメント</h1>
    </motion.section>
  )
}
```

```tsx
// リスト アニメーション (staggerChildren)
import { motion } from "framer-motion"

const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.1 },  // 子要素を0.1秒ずつずらして表示
  },
}
const item = {
  hidden: { opacity: 0, x: -20 },
  show: { opacity: 1, x: 0 },
}

export function AIProviderList({ providers }: { providers: string[] }) {
  return (
    <motion.ul variants={container} initial="hidden" animate="show">
      {providers.map((p) => (
        <motion.li key={p} variants={item}>
          {p}
        </motion.li>
      ))}
    </motion.ul>
  )
}
```

### Framer CMS API (REST)
```python
import requests

# Framer CMS API でコンテンツを取得 (公開 API)
# Site設定 → CMS → API タブでエンドポイント確認
CMS_URL = "https://your-site.framer.website/api/blog"

def get_cms_items(collection: str) -> list:
    resp = requests.get(f"https://your-site.framer.website/api/{collection}")
    resp.raise_for_status()
    return resp.json().get("items", [])

# ブログ記事一覧取得
posts = get_cms_items("blog")
for post in posts:
    print(f"{post['title']} — {post['publishedAt']}")
```

### Framer で Flutter Web との連携パターン
```
1. Framer AI でランディングページ生成 (マーケティングページ)
2. Framer の CTA ボタン → Flutter Web アプリ (my-web-app-b67f4.web.app) に誘導
3. Flutter のコンバージョンデータ → Framer Analytics で計測

活用例:
- LP (Framer AI 生成 → framer.website ホスティング)
- ブログ (Framer CMS → SEO 最適化)
- Flutter Web アプリ (機能提供 → ログイン後)
→ 2 システム分離で LP/ブログのデプロイを Flutter ビルドから独立
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'framer-ai',
  'models',
  'Framer AI 技術詳細 — AI生成エンジン + Framer Motion OSS + WebGPU レンダリング',
  $$## Framer AI 技術詳細

### AI サイト生成エンジン
```
入力: テキストプロンプト (例: "モダンなSaaS LP、ダークテーマ、AI系スタートアップ向け")
       ↓
Layout AI: ヘッダー/ヒーロー/フィーチャー/料金/フッターのセクション構成を決定
       ↓
Copy AI: 各セクションのコピーライティングを GPT-4 で生成
       ↓
Visual AI: カラーパレット・フォント・画像スタイルを選定
       ↓
Component AI: Framer 標準コンポーネントを組み合わせてレイアウト構築
       ↓
出力: 編集可能な Framer プロジェクト (React ベース)
```

### Framer Motion の技術的優位性
- **宣言的 API**: CSS アニメーションより表現力高 / JavaScript より簡潔
- **Layout Animations**: DOM 変更時のレイアウト移動を自動で滑らかにアニメーション
- **Gesture System**: hover/tap/drag/focus を統一 API で制御
- **Shared Element Transitions**: ページ遷移でコンポーネントが連続してアニメーション
- **3D Transforms**: WebGL なしで 3D 効果 / perspective 制御
- **SVG Path Animation**: SVG パスの描画アニメーションをコード1行で実現

### Flutter での Framer Motion 相当実装
```dart
// Flutter の AnimatedContainer (Framer の motion.div に相当)
AnimatedContainer(
  duration: const Duration(milliseconds: 500),
  curve: Curves.easeOut,
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: isHovered ? [Colors.indigo, Colors.purple] : [Colors.grey, Colors.blueGrey],
    ),
    borderRadius: BorderRadius.circular(16),
  ),
  child: const Text('AI大学プロバイダーカード'),
)

// より高度なアニメーションは flutter_animate パッケージで
// flutter_animate は Framer Motion の staggerChildren に相当
```

### 自分株式会社での活用可能性
- **LP 高速作成**: AI プロンプトで自分株式会社 LP を数分で生成 → Framer ホスティングで即公開
- **ブログ SEO**: Framer CMS で dev.to / Qiita 投稿の Web 版を独自ドメインでホスティング
- **Framer Motion 採用**: Flutter Web で実現困難なアニメーションは Framer Motion + Next.js で実装
- **A/B テスト**: Framer の複数バリアント機能でLP のコンバージョン最適化
- **採用ページ**: Framer AI で採用ページを高速作成 / 採用強化フェーズに最適

### Framer vs Webflow vs Squarespace (2026年比較)
- Framer: **AI 生成最強** / React export / デザイナー向け / コミュニティ急成長
- Webflow: CMS 最強 / 企業向け / 学習コスト高 / AI は追いかけ中
- Squarespace: 非エンジニア向け / テンプレート豊富 / AI は限定的
- **結論**: スタートアップ・デザイナーには 2026 年現在 Framer が最有力$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 220→221社化: Framer AI 追加',
  'PS#3 S63。Framer AI (AI Webサイトビルダー / 自然言語でサイト生成 / React出力 / Framer Motion OSS週間700万DL / CMS統合 / $47M / 8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
