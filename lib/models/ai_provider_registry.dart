/// AI大学 プロバイダーの実装ステータス管理レジストリ
///
/// 4ステータス:
/// - notImplemented: EF/UI で呼び出し未実装
/// - implemented: 呼び出し可能 (APIキー設定済み・無料枠で動作)
library;

/// - apiKeyRequired: 実装済みだが Supabase Secrets に APIキー追加が必要
/// - paidPlanRequired: 実装済みだがプロバイダー側の有料プラン契約が必要

enum AiProviderStatus {
  notImplemented,
  implemented,
  apiKeyRequired,
  paidPlanRequired,
}

extension AiProviderStatusX on AiProviderStatus {
  String get label {
    switch (this) {
      case AiProviderStatus.notImplemented:
        return '未実装';
      case AiProviderStatus.implemented:
        return '実装済み';
      case AiProviderStatus.apiKeyRequired:
        return '要APIキー';
      case AiProviderStatus.paidPlanRequired:
        return '要課金';
    }
  }

  /// ダークテーマ前提の状態バッジ色 (docs/DESIGN.md Orange+Indigo tokens)
  int get colorValue {
    switch (this) {
      case AiProviderStatus.implemented:
        return 0xFF4ADE80; // green 400
      case AiProviderStatus.apiKeyRequired:
        return 0xFFFACC15; // yellow 400
      case AiProviderStatus.paidPlanRequired:
        return 0xFFF97316; // orange 500
      case AiProviderStatus.notImplemented:
        return 0xFF94A3B8; // slate 400
    }
  }
}

class AiProviderEntry {
  final String id; // 例: 'openai', 'sambanova'
  final String displayName;
  final AiProviderStatus status;
  final String? envKeyName; // 必要な Supabase Secret 名 (null = なし)
  final String?
      entryPoint; // EF action 名 or 呼び出し経路 (例: 'ai-assistant', 'ai-hub:voice.tts')
  final String note; // 補足 (課金制限・cold-restart など)

  const AiProviderEntry({
    required this.id,
    required this.displayName,
    required this.status,
    this.envKeyName,
    this.entryPoint,
    this.note = '',
  });
}

/// AI大学 登録プロバイダー全件のステータスカタログ (82社, 2026-04-18時点)
///
/// 実装済み: ai-assistant / ai-hub / ai-search に統合済みのもの
/// 要APIキー: コード対応済みだが Supabase Secrets に追加が必要
/// 要課金: free tier で使えないもの (ElevenLabs library voice 等)
/// 未実装: 呼び出しロジック自体がない (78社の大半)
const List<AiProviderEntry> kAiProviderRegistry = [
  // ===== 実装済み (ai-assistant 3本柱) =====
  AiProviderEntry(
    id: 'openai',
    displayName: 'OpenAI',
    status: AiProviderStatus.implemented,
    envKeyName: 'OPENAI_API_KEY',
    entryPoint: 'ai-assistant (Melchior) / ai-hub / ai-search',
    note: 'gpt-4o-mini/gpt-4o 採用。gpt-5.4 系は未導入',
  ),
  AiProviderEntry(
    id: 'anthropic',
    displayName: 'Anthropic',
    status: AiProviderStatus.implemented,
    envKeyName: 'ANTHROPIC_API_KEY',
    entryPoint: 'ai-assistant (Balthasar/Synthesis)',
    note: 'claude-sonnet-4-6 + claude-opus-4-7 (extended_thinking)',
  ),
  AiProviderEntry(
    id: 'google',
    displayName: 'Google Gemini',
    status: AiProviderStatus.implemented,
    envKeyName: 'GEMINI_API_KEY',
    entryPoint: 'ai-assistant (Casper) / ai-hub',
    note: 'gemini-2.5-flash。3.1-pro-preview は未導入',
  ),

  // ===== 実装済みだが課金制限あり =====
  AiProviderEntry(
    id: 'elevenlabs',
    displayName: 'ElevenLabs',
    status: AiProviderStatus.paidPlanRequired,
    envKeyName: 'ELEVENLABS_API_KEY',
    entryPoint: 'ai-hub:voice.tts',
    note: 'Free tier は library voice 不可。現在 Web Speech API へ自動フォールバック',
  ),

  // ===== 要APIキー (実装候補・コード存在するが secret 未設定) =====
  AiProviderEntry(
    id: 'x',
    displayName: 'xAI Grok',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'XAI_API_KEY',
    entryPoint: '(未実装 — OpenAI 互換 API で追加可能)',
    note: 'api.x.ai は OpenAI SDK 互換',
  ),
  AiProviderEntry(
    id: 'perplexity',
    displayName: 'Perplexity',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'PERPLEXITY_API_KEY',
    entryPoint: '(未実装 — Sonar API)',
    note: 'リアルタイムWeb検索統合',
  ),
  AiProviderEntry(
    id: 'deepseek',
    displayName: 'DeepSeek',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'DEEPSEEK_API_KEY',
    entryPoint: '(未実装 — OpenAI 互換)',
  ),
  AiProviderEntry(
    id: 'mistral',
    displayName: 'Mistral AI',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'MISTRAL_API_KEY',
    entryPoint: '(未実装)',
  ),
  AiProviderEntry(
    id: 'groq',
    displayName: 'Groq',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'GROQ_API_KEY',
    entryPoint: '(未実装 — OpenAI 互換・超高速)',
  ),
  AiProviderEntry(
    id: 'cohere',
    displayName: 'Cohere',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'COHERE_API_KEY',
    entryPoint: '(未実装 — RAG特化)',
  ),
  AiProviderEntry(
    id: 'sambanova',
    displayName: 'SambaNova',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'SAMBANOVA_API_KEY',
    entryPoint: '(未実装 — OpenAI 互換・SN50 RDU)',
    note: r'$5 Free Credit あり',
  ),
  AiProviderEntry(
    id: 'openrouter',
    displayName: 'OpenRouter',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'OPENROUTER_API_KEY',
    entryPoint: '(未実装 — 400+ モデル統合)',
  ),

  // ===== 画像/動画/音声 生成系 (要APIキー) =====
  AiProviderEntry(
    id: 'stability',
    displayName: 'Stability AI',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'STABILITY_API_KEY',
    entryPoint: '(未実装 — Stable Diffusion)',
  ),
  AiProviderEntry(
    id: 'runware',
    displayName: 'Runware',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'RUNWARE_API_KEY',
    entryPoint: '(未実装 — 統一推論API・Sonic Engine)',
  ),
  AiProviderEntry(
    id: 'replicate',
    displayName: 'Replicate',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'REPLICATE_API_TOKEN',
    entryPoint: '(未実装)',
  ),
  AiProviderEntry(
    id: 'fireworks_ai',
    displayName: 'Fireworks AI',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'FIREWORKS_API_KEY',
    entryPoint: '(未実装)',
  ),
  AiProviderEntry(
    id: 'together_ai',
    displayName: 'Together AI',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'TOGETHER_API_KEY',
    entryPoint: '(未実装)',
  ),
  AiProviderEntry(
    id: 'huggingface',
    displayName: 'Hugging Face',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'HUGGINGFACE_TOKEN',
    entryPoint: '(未実装)',
  ),

  // ===== 以下、未実装 (実装候補・優先度評価中) =====
  AiProviderEntry(
    id: 'microsoft',
    displayName: 'Microsoft Copilot',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'meta',
    displayName: 'Meta Llama',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'amazon',
    displayName: 'Amazon Bedrock',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'nvidia',
    displayName: 'NVIDIA',
    status: AiProviderStatus.apiKeyRequired,
  ),
  AiProviderEntry(
    id: 'ibm',
    displayName: 'IBM',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'sakana',
    displayName: 'Sakana AI',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'baidu',
    displayName: 'Baidu ERNIE',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'oracle',
    displayName: 'Oracle',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'reka',
    displayName: 'Reka AI',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'aleph_alpha',
    displayName: 'Aleph Alpha',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'writer',
    displayName: 'Writer',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'ai21',
    displayName: 'AI21 Labs',
    status: AiProviderStatus.apiKeyRequired,
  ),
  AiProviderEntry(
    id: 'voyage',
    displayName: 'Voyage AI',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'ollama',
    displayName: 'Ollama',
    status: AiProviderStatus.notImplemented,
    note: 'ローカル実行・サーバー自前運用必要',
  ),
  AiProviderEntry(
    id: 'runway',
    displayName: 'Runway',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'suno',
    displayName: 'Suno',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'ideogram',
    displayName: 'Ideogram',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'udio',
    displayName: 'Udio',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'luma',
    displayName: 'Luma AI',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'kling',
    displayName: 'Kling AI',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'pika',
    displayName: 'Pika',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'assemblyai',
    displayName: 'AssemblyAI',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'twelve_labs',
    displayName: 'Twelve Labs',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'qwen',
    displayName: 'Alibaba Qwen',
    status: AiProviderStatus.apiKeyRequired,
  ),
  AiProviderEntry(
    id: 'moonshot',
    displayName: 'Moonshot Kimi',
    status: AiProviderStatus.apiKeyRequired,
  ),
  AiProviderEntry(
    id: 'midjourney',
    displayName: 'Midjourney',
    status: AiProviderStatus.notImplemented,
    note: '公式 API なし (Discord 経由のみ)',
  ),
  AiProviderEntry(
    id: 'hailuo',
    displayName: 'Hailuo AI',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'adobe_firefly',
    displayName: 'Adobe Firefly',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: '01ai',
    displayName: '01.AI',
    status: AiProviderStatus.apiKeyRequired,
  ),
  AiProviderEntry(
    id: 'coze',
    displayName: 'Coze',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'apple',
    displayName: 'Apple Intelligence',
    status: AiProviderStatus.notImplemented,
    note: '公式 API なし',
  ),
  AiProviderEntry(
    id: 'databricks',
    displayName: 'Databricks',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'samsung',
    displayName: 'Samsung Gauss',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'zhipu',
    displayName: 'Zhipu GLM',
    status: AiProviderStatus.apiKeyRequired,
  ),
  AiProviderEntry(
    id: 'character_ai',
    displayName: 'Character.AI',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'inflection',
    displayName: 'Inflection Pi',
    status: AiProviderStatus.apiKeyRequired,
  ),
  AiProviderEntry(
    id: 'allenai',
    displayName: 'Allen AI (OLMo)',
    status: AiProviderStatus.apiKeyRequired,
  ),
  AiProviderEntry(
    id: 'naver',
    displayName: 'Naver HyperCLOVA',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'adept',
    displayName: 'Adept',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'cerebras',
    displayName: 'Cerebras',
    status: AiProviderStatus.apiKeyRequired,
  ),
  AiProviderEntry(
    id: 'prover',
    displayName: 'Prover',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'lmsys',
    displayName: 'LMSYS',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'falcon_tii',
    displayName: 'Falcon (TII)',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'black_forest_labs',
    displayName: 'Black Forest Labs (FLUX)',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'liquid_ai',
    displayName: 'Liquid AI',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'snowflake',
    displayName: 'Snowflake',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'cognition',
    displayName: 'Cognition (Devin)',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'scale_ai',
    displayName: 'Scale AI',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'poolside',
    displayName: 'Poolside',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'harvey',
    displayName: 'Harvey',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'manus',
    displayName: 'Manus',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'hedra',
    displayName: 'Hedra',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'heygen',
    displayName: 'HeyGen',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'recraft',
    displayName: 'Recraft',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'krea',
    displayName: 'Krea',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'tencent',
    displayName: 'Tencent Hunyuan',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'bytedance',
    displayName: 'ByteDance Doubao',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'inception_labs',
    displayName: 'Inception Labs',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'world_labs',
    displayName: 'World Labs',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'core',
    displayName: 'Core',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'lightricks',
    displayName: 'Lightricks LTX-2',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — 4K 音声+映像 OSS・REST/Fal/Replicate)',
    note: 'Compute-second 課金。Free 800 クレジット',
  ),
  AiProviderEntry(
    id: 'arcee_ai',
    displayName: 'Arcee AI Trinity',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'ARCEE_API_KEY',
    entryPoint: 'ai-hub:provider.chat (OpenAI 互換)',
    note: r'Mini $0.045/$0.15 per 1M · OpenRouter 無料枠あり',
  ),
  AiProviderEntry(
    id: 'minimax',
    displayName: 'MiniMax (Hailuo)',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'MINIMAX_API_KEY',
    entryPoint: '(未実装 — OpenAI 互換・音声+動画+音楽統合)',
    note: 'M2.5-Lightning 月100万tok free・香港上場',
  ),
  AiProviderEntry(
    id: 'moondream',
    displayName: 'Moondream VLM',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — 軽量 VLM 9B MoE・Apache 2.0)',
    note: r'$0.30/$2.50 per 1M · 画像=729 tok',
  ),
];

/// ステータス別件数を集計
Map<AiProviderStatus, int> aiProviderStatusCounts() {
  final counts = <AiProviderStatus, int>{
    for (final s in AiProviderStatus.values) s: 0,
  };
  for (final entry in kAiProviderRegistry) {
    counts[entry.status] = (counts[entry.status] ?? 0) + 1;
  }
  return counts;
}
