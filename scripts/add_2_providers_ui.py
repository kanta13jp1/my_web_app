#!/usr/bin/env python3
"""AI大学 gemini_university_v2_page.dart に allenai + naver を追加する。"""

FILE = "lib/pages/gemini_university_v2_page.dart"

META_ENTRIES = """\
  'allenai': _ProviderMeta(
    name: 'Allen AI (OLMo)',
    emoji: '🔬',
    color: const Color(0xFF2196F3),
    officialUrl: 'https://allenai.org',
  ),
  'naver': _ProviderMeta(
    name: 'Naver (HyperCLOVA X)',
    emoji: '🟩',
    color: const Color(0xFF03C75A),
    officialUrl: 'https://clova.ai',
  ),
"""

QUIZ_ENTRIES = """\
  'allenai': _Quiz(
    question: 'Allen AI (AI2) の OLMo の特徴として正しいのは？',
    options: ['完全オープンソース (重み+コード+データ+評価)', 'クローズドAPIのみ', '画像生成特化', '音声認識特化'],
    correct: 0,
  ),
  'naver': _Quiz(
    question: 'Naver の HyperCLOVA X が得意とする言語は？',
    options: ['韓国語 (世界最高水準)', '英語のみ', '中国語', '日本語のみ'],
    correct: 0,
  ),
"""

FALLBACK_ENTRIES = """\
  'allenai': '''
## Allen AI (AI2 / OLMo)
Paul Allenが設立した非営利AI研究機関。OLMo-2はGPT-4クラスの完全オープンソースLLM。
重み・コード・学習データ・評価パイプラインをすべて公開。

## 主要モデル
- **OLMo-2-72B**: GPT-4クラス・完全オープンソース
- **OLMo-2-7B/13B**: 軽量版・商用利用可
- **Tulu 3**: 指示チューニング版 (RLVR採用)

## 特徴
- Dolma: 3兆トークンのオープン学習データセット
- 完全な研究再現性 (データ→モデル→評価)
- 非営利・研究コミュニティへの貢献重視

[公式サイト](https://allenai.org)
''',
  'naver': '''
## Naver (HyperCLOVA X)
韓国最大テック企業が開発する超大規模LLM。韓国語処理で世界最高水準。
LINE (日本展開) との統合でアジア市場をカバー。

## 主要モデル
- **HyperCLOVA X**: 82Bパラメータ・韓国語特化超大規模LLM
- **CLOVA X**: エンドユーザー向けAIアシスタント
- **HCX-005**: 最新エンタープライズAPI版

## 特徴
- 韓国語データ6,500億トークンで学習 (GPT-3の韓国語の6,500倍)
- 100言語対応・アジア言語に強み
- CLOVA Studio: ノーコードAIアプリ構築プラットフォーム

[公式サイト](https://clova.ai)
''',
"""

def main():
    with open(FILE, encoding="utf-8") as f:
        src = f.read()

    # Find last _ProviderMeta entry closing before meta map's };
    # We look for the "};\n\n// ── クイズ" pattern
    meta_end_pattern = "};\n\n// ─────────────────────────────────────────────────────────────────────────────\n// クイズ"
    meta_end_idx = src.find(meta_end_pattern)
    assert meta_end_idx >= 0, "meta closing not found"
    src = src[:meta_end_idx] + META_ENTRIES + src[meta_end_idx:]

    # Find quiz closing
    quiz_end_pattern = "};\n\n// ─────────────────────────────────────────────────────────────────────────────\n// フォールバック"
    quiz_end_idx = src.find(quiz_end_pattern)
    assert quiz_end_idx >= 0, "quiz closing not found"
    src = src[:quiz_end_idx] + QUIZ_ENTRIES + src[quiz_end_idx:]

    # Find fallback closing
    fb_end_pattern = "\n};\n\n// ─────────────────────────────────────────────────────────────────────────────\n// ページ本体"
    fb_end_idx = src.find(fb_end_pattern)
    assert fb_end_idx >= 0, "fallback closing not found"
    src = src[:fb_end_idx + 1] + FALLBACK_ENTRIES + src[fb_end_idx + 1:]

    with open(FILE, "w", encoding="utf-8") as f:
        f.write(src)

    print("Done: allenai + naver added")


if __name__ == "__main__":
    main()
