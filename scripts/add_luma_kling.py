import sys
sys.stdout.reconfigure(encoding='utf-8')

FILE = "lib/pages/gemini_university_v2_page.dart"
content = open(FILE, encoding="utf-8").read()

# 1. _providerMeta
OLD_META = """  'writer': _ProviderMeta(
    name: 'Writer',
    emoji: '✍️',
    color: const Color(0xFF7C3AED),
    officialUrl: 'https://dev.writer.com/docs',
  ),
};"""
NEW_META = """  'writer': _ProviderMeta(
    name: 'Writer',
    emoji: '✍️',
    color: const Color(0xFF7C3AED),
    officialUrl: 'https://dev.writer.com/docs',
  ),
  'luma': _ProviderMeta(
    name: 'Luma AI',
    emoji: '🎬',
    color: const Color(0xFF00D4FF),
    officialUrl: 'https://api.lumalabs.ai',
  ),
  'kling': _ProviderMeta(
    name: 'Kling AI',
    emoji: '🎥',
    color: const Color(0xFFFF6B35),
    officialUrl: 'https://klingai.com',
  ),
};"""

if OLD_META not in content:
    print("ERROR: writer meta marker not found")
    sys.exit(1)
content = content.replace(OLD_META, NEW_META, 1)

# 2. _quizzes
OLD_QUIZ = """  'writer': _Quiz(
    question: 'Writer の Palmyra Med / Palmyra Fin はどのような特化モデルですか？',
    options: ['医療・金融ドメインに特化したビジネス文書生成モデル', '音声認識専用', '画像生成専用', 'コード生成専用'],
    correct: 0,
  ),
};"""
NEW_QUIZ = """  'writer': _Quiz(
    question: 'Writer の Palmyra Med / Palmyra Fin はどのような特化モデルですか？',
    options: ['医療・金融ドメインに特化したビジネス文書生成モデル', '音声認識専用', '画像生成専用', 'コード生成専用'],
    correct: 0,
  ),
  'luma': _Quiz(
    question: 'Luma AI Dream Machine の最大の特徴は？',
    options: ['3D空間を理解した動画生成 (物体の奥行き・動きを正確にレンダリング)', '音声から動画を生成', '静止画の解像度向上', 'テキスト文書の要約'],
    correct: 0,
  ),
  'kling': _Quiz(
    question: 'Kling AI が生成できる動画の最大長は？',
    options: ['最大3分 (180秒)', '最大10秒', '最大60秒', '最大30秒'],
    correct: 0,
  ),
};"""

if OLD_QUIZ not in content:
    print("ERROR: writer quiz marker not found")
    sys.exit(1)
content = content.replace(OLD_QUIZ, NEW_QUIZ, 1)

# 3. _fallback
OLD_FALL = """  'writer': '''
# Writer — エンタープライズビジネスAI

Writer はビジネス文書生成・コンプライアンス管理に特化したエンタープライズAI企業です。

## モデルラインナップ
- Palmyra X 004 (128K, 最高精度・長文書処理)
- Palmyra Med (医療特化)
- Palmyra Fin (金融特化)

## 特徴
- ブランドボイス学習: 企業の表現スタイルをAIに記憶させ一貫性を担保
- Knowledge Graph: 社内文書をRAGに自動統合

[Writer Docs](https://dev.writer.com/docs)
''',
};"""
NEW_FALL = """  'writer': '''
# Writer — エンタープライズビジネスAI

Writer はビジネス文書生成・コンプライアンス管理に特化したエンタープライズAI企業です。

## モデルラインナップ
- Palmyra X 004 (128K, 最高精度・長文書処理)
- Palmyra Med (医療特化)
- Palmyra Fin (金融特化)

## 特徴
- ブランドボイス学習: 企業の表現スタイルをAIに記憶させ一貫性を担保
- Knowledge Graph: 社内文書をRAGに自動統合

[Writer Docs](https://dev.writer.com/docs)
''',
  'luma': '''
# Luma AI — 3D-aware 動画生成AIのパイオニア

Luma AI はシリコンバレー発の動画生成AI企業。Dream Machine は
3D空間の奥行きを理解した上で物体を動かせる能力で業界をリードしています。

## 主要機能
- Dream Machine: テキスト/画像から高品質動画を生成
- 3D-aware生成: 物体の奥行き・物理的な動きを正確にレンダリング
- Genie: テキスト/画像から3Dオブジェクト生成
- Ray2: 最新フラッグシップ動画生成モデル

## Runway / Kling との違い
Lumaの最大の強みは「3D空間理解」。カメラが動いても
シーンの奥行きが崩れない自然な映像が生成できます。

[Luma API](https://api.lumalabs.ai)
''',
  'kling': '''
# Kling AI — 映画品質の動画生成 (最大3分)

Kling AI は中国の動画プラットフォーム大手・快手 (Kuaishou) が開発した
動画生成AIです。最大3分・1080p という業界最長クラスの動画を生成できます。

## 主要スペック
- 最大3分 (180秒) の動画生成 — 業界トップクラス
- 1080p 解像度 / 24fps
- 物理ベースのモーション (慣性・重力を考慮した動き)
- Image-to-Video: 静止画を映画的な動画に変換

## Runway / Luma との比較
- Runway: 10秒・4K — ハリウッドVFX品質
- Luma: 3D-aware — カメラ動作の自然さ
- Kling: 3分長尺・ストーリー動画に最適

[Kling Open Platform](https://klingai.com)
''',
};"""

if OLD_FALL not in content:
    print("ERROR: writer fallback marker not found")
    sys.exit(1)
content = content.replace(OLD_FALL, NEW_FALL, 1)

open(FILE, "w", encoding="utf-8").write(content)
print("SUCCESS luma+kling added")
