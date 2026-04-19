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

enum AiProviderTier { free, budget, performance, premium }

extension AiProviderTierX on AiProviderTier {
  String get label {
    switch (this) {
      case AiProviderTier.free:
        return '無料';
      case AiProviderTier.budget:
        return '低コスト';
      case AiProviderTier.performance:
        return '標準';
      case AiProviderTier.premium:
        return 'プレミアム';
    }
  }

  int get colorValue {
    switch (this) {
      case AiProviderTier.free:
        return 0xFF94A3B8;
      case AiProviderTier.budget:
        return 0xFF4ADE80;
      case AiProviderTier.performance:
        return 0xFFFACC15;
      case AiProviderTier.premium:
        return 0xFFFF6B35;
    }
  }
}

class AiProviderEntry {
  final String id; // 例: 'openai', 'sambanova'
  final String displayName;
  final AiProviderStatus status;
  final AiProviderTier? tier;
  final String? envKeyName; // 必要な Supabase Secret 名 (null = なし)
  final String?
      entryPoint; // EF action 名 or 呼び出し経路 (例: 'ai-assistant', 'ai-hub:voice.tts')
  final String note; // 補足 (課金制限・cold-restart など)

  const AiProviderEntry({
    required this.id,
    required this.displayName,
    required this.status,
    this.tier,
    this.envKeyName,
    this.entryPoint,
    this.note = '',
  });
}

/// AI大学 登録プロバイダー全件のステータスカタログ (100社, 2026-04-19時点)
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
    tier: AiProviderTier.performance,
    envKeyName: 'OPENAI_API_KEY',
    entryPoint: 'ai-assistant (Melchior) / ai-hub / ai-search',
    note: 'gpt-4o-mini/gpt-4o 採用。gpt-5.4 系は未導入',
  ),
  AiProviderEntry(
    id: 'anthropic',
    displayName: 'Anthropic',
    status: AiProviderStatus.implemented,
    tier: AiProviderTier.premium,
    envKeyName: 'ANTHROPIC_API_KEY',
    entryPoint: 'ai-assistant (Balthasar/Synthesis)',
    note: 'claude-sonnet-4-6 + claude-opus-4-7 (extended_thinking)',
  ),
  AiProviderEntry(
    id: 'google',
    displayName: 'Google Gemini',
    status: AiProviderStatus.implemented,
    tier: AiProviderTier.performance,
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
    tier: AiProviderTier.performance,
    envKeyName: 'PERPLEXITY_API_KEY',
    entryPoint: '(未実装 — Sonar API)',
    note: 'リアルタイムWeb検索統合',
  ),
  AiProviderEntry(
    id: 'deepseek',
    displayName: 'DeepSeek',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.budget,
    envKeyName: 'DEEPSEEK_API_KEY',
    entryPoint: '(未実装 — OpenAI 互換)',
  ),
  AiProviderEntry(
    id: 'mistral',
    displayName: 'Mistral AI',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.performance,
    envKeyName: 'MISTRAL_API_KEY',
    entryPoint: '(未実装)',
  ),
  AiProviderEntry(
    id: 'groq',
    displayName: 'Groq',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.budget,
    envKeyName: 'GROQ_API_KEY',
    entryPoint: '(未実装 — OpenAI 互換・超高速)',
  ),
  AiProviderEntry(
    id: 'cohere',
    displayName: 'Cohere',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.performance,
    envKeyName: 'COHERE_API_KEY',
    entryPoint: '(未実装 — RAG特化)',
  ),
  AiProviderEntry(
    id: 'sambanova',
    displayName: 'SambaNova',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.budget,
    envKeyName: 'SAMBANOVA_API_KEY',
    entryPoint: '(未実装 — OpenAI 互換・SN50 RDU)',
    note: r'$5 Free Credit あり',
  ),
  AiProviderEntry(
    id: 'openrouter',
    displayName: 'OpenRouter',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.budget,
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
    tier: AiProviderTier.budget,
    envKeyName: 'REPLICATE_API_TOKEN',
    entryPoint: 'ai-hub',
  ),
  AiProviderEntry(
    id: 'deepinfra',
    displayName: 'DeepInfra',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.budget,
    envKeyName: 'DEEPINFRA_API_KEY',
    entryPoint: 'ai-hub',
  ),
  AiProviderEntry(
    id: 'fireworks_ai',
    displayName: 'Fireworks AI',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.budget,
    envKeyName: 'FIREWORKS_API_KEY',
    entryPoint: '(未実装)',
  ),
  AiProviderEntry(
    id: 'together_ai',
    displayName: 'Together AI',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.budget,
    envKeyName: 'TOGETHER_API_KEY',
    entryPoint: '(未実装)',
  ),
  AiProviderEntry(
    id: 'huggingface',
    displayName: 'Hugging Face',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.free,
    envKeyName: 'HUGGINGFACE_TOKEN',
    entryPoint: 'ai-hub:provider.chat (Inference API・PS版#110で追加)',
  ),

  // ===== 以下、未実装 (実装候補・優先度評価中) =====
  AiProviderEntry(
    id: 'microsoft',
    displayName: 'Microsoft Copilot',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
  ),
  AiProviderEntry(
    id: 'meta',
    displayName: 'Meta Llama',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'LLAMA_API_KEY',
    entryPoint: 'ai-hub (provider.chat)',
    note: 'api.llama.com — Llama-4-Scout-17B-16E-Instruct',
  ),
  AiProviderEntry(
    id: 'nebius',
    displayName: 'Nebius AI Studio',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'NEBIUS_API_KEY',
    entryPoint: 'ai-hub (provider.chat)',
    note: 'Yandex傘下・欧州GPU クラウド — api.studio.nebius.com',
  ),
  AiProviderEntry(
    id: 'amazon',
    displayName: 'Amazon Bedrock',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
  ),
  AiProviderEntry(
    id: 'nvidia',
    displayName: 'NVIDIA',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.performance,
  ),
  AiProviderEntry(
    id: 'ibm',
    displayName: 'IBM',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
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
    tier: AiProviderTier.performance,
  ),
  AiProviderEntry(
    id: 'oracle',
    displayName: 'Oracle',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'reka',
    displayName: 'Reka AI',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'REKA_API_KEY',
  ),
  AiProviderEntry(
    id: 'aleph_alpha',
    displayName: 'Aleph Alpha',
    status: AiProviderStatus.notImplemented,
  ),
  AiProviderEntry(
    id: 'writer',
    displayName: 'Writer',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.performance,
    envKeyName: 'WRITER_API_KEY',
  ),
  AiProviderEntry(
    id: 'ai21',
    displayName: 'AI21 Labs',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.performance,
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
    tier: AiProviderTier.free,
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
    tier: AiProviderTier.budget,
  ),
  AiProviderEntry(
    id: 'moonshot',
    displayName: 'Moonshot Kimi',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.performance,
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
    tier: AiProviderTier.budget,
  ),
  AiProviderEntry(
    id: 'coze',
    displayName: 'Coze (ByteDance)',
    status: AiProviderStatus.apiKeyRequired,
    envKeyName: 'COZE_API_KEY',
    entryPoint: 'ai-hub',
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
    tier: AiProviderTier.performance,
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
    tier: AiProviderTier.performance,
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
    tier: AiProviderTier.free,
  ),
  AiProviderEntry(
    id: 'naver',
    displayName: 'Naver HyperCLOVA',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
  ),
  AiProviderEntry(
    id: 'adept',
    displayName: 'Adept',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.premium,
  ),
  AiProviderEntry(
    id: 'cerebras',
    displayName: 'Cerebras',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.budget,
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
    tier: AiProviderTier.free,
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
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.performance,
    envKeyName: 'LIQUID_API_KEY',
    entryPoint: 'ai-hub',
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
    tier: AiProviderTier.premium,
  ),
  AiProviderEntry(
    id: 'scale_ai',
    displayName: 'Scale AI',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.premium,
  ),
  AiProviderEntry(
    id: 'poolside',
    displayName: 'Poolside',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.premium,
  ),
  AiProviderEntry(
    id: 'harvey',
    displayName: 'Harvey',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.premium,
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
    tier: AiProviderTier.budget,
    envKeyName: 'ARCEE_API_KEY',
    entryPoint: 'ai-hub:provider.chat (OpenAI 互換)',
    note: r'Mini $0.045/$0.15 per 1M · OpenRouter 無料枠あり',
  ),
  AiProviderEntry(
    id: 'minimax',
    displayName: 'MiniMax (Hailuo)',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.budget,
    envKeyName: 'MINIMAX_API_KEY',
    entryPoint: 'ai-hub:provider.chat (OpenAI 互換・PS版#110で追加)',
    note: 'M2.5-Lightning 月100万tok free・香港上場',
  ),
  AiProviderEntry(
    id: 'moondream',
    displayName: 'Moondream VLM',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — 軽量 VLM 9B MoE・Apache 2.0)',
    note: r'$0.30/$2.50 per 1M · 画像=729 tok',
  ),
  AiProviderEntry(
    id: 'rakuten_ai',
    displayName: 'Rakuten AI 3.0',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — 700B MoE 日本最大級・Apache 2.0)',
    note: 'HuggingFace無料・Rakuten AI Gateway商談ベース',
  ),
  AiProviderEntry(
    id: 'pfn',
    displayName: 'Preferred Networks (PLaMo)',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — 100% 日本製 foundation model)',
    note: 'エンタープライズ商談・研究者無料枠あり',
  ),
  AiProviderEntry(
    id: 'siliconflow',
    displayName: 'SiliconFlow (硅基流动)',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.budget,
    envKeyName: 'SILICONFLOW_API_KEY',
    entryPoint: 'ai-hub:provider.chat (OpenAI 互換)',
    note: 'Qwen2.5-72B・DeepSeek-V3 無料枠あり・中国最大推論プラットフォーム',
  ),
  AiProviderEntry(
    id: 'novita_ai',
    displayName: 'Novita AI',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.budget,
    envKeyName: 'NOVITA_API_KEY',
    entryPoint: 'ai-hub:provider.chat (OpenAI 互換)',
    note: r'Llama-3.1-70B $0.23/$0.23 per 1M・クレジット制・100+モデル対応',
  ),
  AiProviderEntry(
    id: 'fal_ai',
    displayName: 'fal.ai',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — 1000+モデル統合・画像/動画/音声/3D マルチモーダル)',
    note: r'FLUX/Seedance 2.0/Stable Audio・$0.025/img・低遅延 GPU クラウド',
  ),
  AiProviderEntry(
    id: 'fish_audio',
    displayName: 'Fish Audio',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — TTS 専業 70+言語・リアルタイムストリーミング)',
    note: r'Fish Speech S1 (OSS)・$15/100万文字・ボイスクローン即時',
  ),
  AiProviderEntry(
    id: 'atlas_cloud',
    displayName: 'Atlas Cloud',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.budget,
    envKeyName: 'ATLAS_CLOUD_API_KEY',
    entryPoint: 'ai-hub:provider.chat (OpenAI 互換)',
    note: r'300+モデル統合 (LLM/画像/音声/動画 フルモーダル)・無料クレジットあり',
  ),
  AiProviderEntry(
    id: 'mira_network',
    displayName: 'Mira Network',
    status: AiProviderStatus.notImplemented,
    entryPoint: r'(未実装 — blockchain 検証付き AI inference・$MIRA token必須)',
    note: r'GPT-4o/Llama 405B を分散検証・500K users・hallucination対策',
  ),
  AiProviderEntry(
    id: 'gmi_cloud',
    displayName: 'GMI Cloud',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.budget,
    envKeyName: 'GMI_CLOUD_API_KEY',
    entryPoint: 'ai-hub:provider.chat (OpenAI 互換)',
    note: 'TensorRT-LLM 最適化・100+モデル・H100 \$2.10/hr・無料枠あり',
  ),
  AiProviderEntry(
    id: 'inworld',
    displayName: 'Inworld AI',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.budget,
    envKeyName: 'INWORLD_API_KEY',
    entryPoint: 'ai-hub:provider.chat (OpenAI 互換)',
    note:
        r'Router で hundreds of models 統合・GPT 4o Mini $0.15/M入力・Realtime API 互換',
  ),
  AiProviderEntry(
    id: 'coreweave',
    displayName: 'CoreWeave',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.premium,
    entryPoint: '(未実装 — GPU クラウド・K8s デプロイ前提・Inworld Router 経由で chat 可能)',
    note: r'OpenAI/Meta/Perplexity の本番 GPU・H100 $2.39/hr・B300/Vera Rubin 最速展開',
  ),
  AiProviderEntry(
    id: 'lambda_labs',
    displayName: 'Lambda Labs',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.budget,
    entryPoint: '(未実装 — Inference API は wind-down 中・GPU 直接賃貸が今後の主軸)',
    note: r'業界最安GPU H100 $2.89/hr・Llama 3.3 70B $0.20/M (廃止予定)',
  ),
  AiProviderEntry(
    id: 'hyperbolic',
    displayName: 'Hyperbolic Labs',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.budget,
    envKeyName: 'HYPERBOLIC_API_KEY',
    entryPoint: 'ai-hub:provider.chat (OpenAI 互換)',
    note: r'分散GPU+検証可能AI・H100 $3.20/hr・RTX4090 $0.50/hr・zk-snarks 検証',
  ),
  AiProviderEntry(
    id: 'anyscale',
    displayName: 'Anyscale',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.performance,
    envKeyName: 'ANYSCALE_API_KEY',
    entryPoint: 'ai-hub:provider.chat (OpenAI 互換)',
    note: r'Ray.io 商用版・Llama 3.1 70B $1.00/M・LoRA fine-tuning 対応',
  ),
  AiProviderEntry(
    id: 'cerebrium',
    displayName: 'Cerebrium',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.budget,
    envKeyName: 'CEREBRIUM_API_KEY',
    entryPoint: 'ai-hub:provider.chat (OpenAI 互換)',
    note: r'serverless GPU・sub-second cold start・H100 $4.20/hr・voice/video 対応',
  ),
  AiProviderEntry(
    id: 'magic_ai',
    displayName: 'Magic AI',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.premium,
    entryPoint: '(未実装 — research preview のみ・production API 未公開)',
    note: r'100M token context (Llama比1000x効率)・コードAI特化・Google Cloud G4/G5提携',
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
