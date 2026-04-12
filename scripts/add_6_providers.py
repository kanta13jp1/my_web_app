#!/usr/bin/env python3
"""Add luma, kling, pika, assemblyai, twelve_labs, cohere to AI大学 provider maps."""
import re

path = 'lib/pages/gemini_university_v2_page.dart'
with open(path, encoding='utf-8') as f:
    content = f.read()

# ── 1. _providerMeta: insert before closing '};' of _providerMeta ──────────
meta_insert = """  'luma': _ProviderMeta(
    name: 'Luma AI',
    emoji: '🎬',
    color: const Color(0xFF00D4FF),
    officialUrl: 'https://api.lumalabs.ai',
  ),
  'kling': _ProviderMeta(
    name: 'Kling AI',
    emoji: '🎥',
    color: const Color(0xFFFF6B35),
    officialUrl: 'https://api.kling.kuaishou.com',
  ),
  'pika': _ProviderMeta(
    name: 'Pika Labs',
    emoji: '⚡',
    color: const Color(0xFF6C63FF),
    officialUrl: 'https://api.pika.art',
  ),
  'assemblyai': _ProviderMeta(
    name: 'AssemblyAI',
    emoji: '🎙️',
    color: const Color(0xFF00BFA5),
    officialUrl: 'https://www.assemblyai.com/docs',
  ),
  'twelve_labs': _ProviderMeta(
    name: 'Twelve Labs',
    emoji: '🎞️',
    color: const Color(0xFF4A90D9),
    officialUrl: 'https://docs.twelvelabs.io',
  ),
"""

# Insert before the closing of _providerMeta (line with just '};' after 'writer')
old_meta_close = "  'writer': _ProviderMeta(\n    name: 'Writer',\n    emoji: '✍️',\n    color: const Color(0xFF7C3AED),\n    officialUrl: 'https://dev.writer.com/docs',\n  ),\n};"
new_meta_close = ("  'writer': _ProviderMeta(\n    name: 'Writer',\n    emoji: '✍️',\n"
                  "    color: const Color(0xFF7C3AED),\n    officialUrl: 'https://dev.writer.com/docs',\n  ),\n"
                  + meta_insert + "};")
assert old_meta_close in content, "writer _ProviderMeta block not found"
content = content.replace(old_meta_close, new_meta_close, 1)

# ── 2. _quizzes: insert before closing '};' of _quizzes ──────────────────
quiz_insert = """  'luma': _Quiz(
    question: 'Luma AI の Dream Machine が他の動画生成AIと差別化される最大の特徴は？',
    options: ['3D空間を理解した物理ベースの動画生成', 'テキストのみ対応', '音声生成特化', 'コード生成に特化'],
    correct: 0,
  ),
  'kling': _Quiz(
    question: 'Kling AI が生成できる動画の最大長さは？',
    options: ['最大3分 (180秒)', '最大30秒', '最大10秒', '最大1分'],
    correct: 0,
  ),
  'pika': _Quiz(
    question: 'Pika Labs の主な競争優位は何ですか？',
    options: ['$0.03/生成の低コスト高速動画生成', '最長動画生成', '音声認識精度', 'コード生成速度'],
    correct: 0,
  ),
  'assemblyai': _Quiz(
    question: 'AssemblyAI の LeMUR は何のための機能ですか？',
    options: ['音声コンテンツにLLMを適用して理解・分析する', '画像生成を行う', 'テキスト翻訳を行う', 'コードを生成する'],
    correct: 0,
  ),
  'twelve_labs': _Quiz(
    question: 'Twelve Labs の Marengo と Pegasus はそれぞれ何のモデルですか？',
    options: ['Marengo=動画埋め込み・Pegasus=動画生成', 'どちらも音声認識', 'どちらも画像生成', 'Marengo=テキスト・Pegasus=音声'],
    correct: 0,
  ),
"""

old_quiz_close = "  'writer': _Quiz(\n    question: 'Writer の Palmyra Med / Palmyra Fin はどのような特化モデルですか？',\n    options: ['医療・金融ドメインに特化したビジネス文書生成モデル', '音声認識専用', '画像生成専用', 'コード生成専用'],\n    correct: 0,\n  ),\n};"
new_quiz_close = ("  'writer': _Quiz(\n    question: 'Writer の Palmyra Med / Palmyra Fin はどのような特化モデルですか？',\n"
                  "    options: ['医療・金融ドメインに特化したビジネス文書生成モデル', '音声認識専用', '画像生成専用', 'コード生成専用'],\n"
                  "    correct: 0,\n  ),\n" + quiz_insert + "};")
assert old_quiz_close in content, "writer _Quiz block not found"
content = content.replace(old_quiz_close, new_quiz_close, 1)

# ── 3. _fallback: insert before closing '};' of _fallback ─────────────────
fallback_insert = """  'luma': '''
## Luma AI (Dream Machine)
3D空間を理解した動画生成AIのパイオニア。
テキスト・画像から映画品質の動画を生成。
公式API: api.lumalabs.ai
''',
  'kling': '''
## Kling AI
快手 (Kuaishou) 開発のシネマティック動画生成AI。
最大3分・1080p・物理ベースモーション。
Kling Open Platform APIで統合可能。
''',
  'pika': '''
## Pika Labs
消費者向け動画生成AI。\$0.03/生成の低コストが強み。
Pika 2.2で1080p・最大10秒の動画生成が可能。
公式API: api.pika.art
''',
  'assemblyai': '''
## AssemblyAI
音声認識・転写・音声理解のリーディングAPI。
Universal-2モデル・99言語対応・LeMURでLLM連携。
Claude (Anthropic) をデフォルトで採用している。
''',
  'twelve_labs': '''
## Twelve Labs
動画理解・検索に特化したAI。Marengo埋め込み+Pegasus生成の2モデル構成。
動画Q&A・セマンティック検索・要約・ハイライト抽出が可能。
''',
"""

old_fallback_close = "[Writer Docs](https://dev.writer.com/docs)\n''',\n};"
new_fallback_close = "[Writer Docs](https://dev.writer.com/docs)\n''',\n" + fallback_insert + "};"
assert old_fallback_close in content, "writer _fallback block not found"
content = content.replace(old_fallback_close, new_fallback_close, 1)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

# Verify
count = content.count("': _ProviderMeta(")
print(f"_providerMeta entries: {count}")
print("Done.")
