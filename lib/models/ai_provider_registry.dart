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

/// AI大学 登録プロバイダー全件のステータスカタログ (182社, 2026-04-24時点)
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
    status: AiProviderStatus.implemented,
    tier: AiProviderTier.budget,
    envKeyName: 'GROQ_API_KEY',
    entryPoint: 'ai-hub (provider.chat) — OpenAI 互換・超高速',
    note: 'Llama 3.x / Mixtral 系を低コスト・超高速で提供。ai-tag-suggester 経路にも接続',
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
    entryPoint: 'https://scale.com/',
    note: r'Data labeling to enterprise AI — RLHF supply / Scale Donovan (DoD)',
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
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.premium,
    envKeyName: 'HARVEY_API_KEY',
    entryPoint: 'tools-hub:legal.harvey.complete',
    note: '法務・コンプライアンス画面の Harvey タブから法律AIレビューを実行',
  ),
  AiProviderEntry(
    id: 'manus',
    displayName: 'Manus',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.premium,
    envKeyName: 'MANUS_API_KEY',
    entryPoint:
        'ai-hub:my_agent.chat(provider=manus) / /agent-org: Manus-like autopilot',
    note: 'AI組織OSで目的を要件整理/KGI設計/主担当案/専門レビュー/CEO確認へ自動分解し、部門タスクとして委任する。',
  ),
  AiProviderEntry(
    id: 'hedra',
    displayName: 'Hedra',
    status: AiProviderStatus.apiKeyRequired,
    tier: AiProviderTier.premium,
    envKeyName: 'HEDRA_API_KEY',
    entryPoint:
        'ai-assistant:assistant_video_reply / ai-hub:my_agent.chat(video)',
    note: '会話テキストをアバター動画へ昇格。画像添付時は avatarImage として利用。',
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

  // ===== AI 動画 / アバター =====
  AiProviderEntry(
    id: 'synthesia',
    displayName: 'Synthesia',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.premium,
    entryPoint: '(未実装 — エンタープライズ AI 動画 API)',
    note: '230+ アバター × 140言語のエンタープライズ AI 動画プラットフォーム',
  ),
  AiProviderEntry(
    id: 'did',
    displayName: 'D-ID',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
    entryPoint: '(未実装 — リアルタイムアバター動画 API)',
    note: 'リアルタイム AI アバター動画生成プラットフォーム',
  ),
  AiProviderEntry(
    id: 'tavus',
    displayName: 'Tavus',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
    entryPoint: '(未実装 — 会話型ビデオ AI API)',
    note: 'パーソナライズ AI 動画生成 & 会話型ビデオ AI',
  ),
  AiProviderEntry(
    id: 'descript',
    displayName: 'Descript',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
    entryPoint: '(未実装 — テキスト編集型 AV エディタ API)',
    note: 'テキスト編集で動画・音声を操る AI クリエイティブツール',
  ),

  // ===== 音声 AI =====
  AiProviderEntry(
    id: 'deepgram',
    displayName: 'Deepgram',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.budget,
    entryPoint: '(未実装 — STT/TTS/Voice Agent API)',
    note: '音声 AI 特化プロバイダー (Nova-2 STT 最速級・MediaRecorder→base64 統合可)',
  ),
  AiProviderEntry(
    id: 'cartesia',
    displayName: 'Cartesia AI',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
    entryPoint: '(未実装 — Sonic 超低遅延 TTS)',
    note: '状態空間モデル (SSM) で実現する超低遅延リアルタイム TTS',
  ),
  AiProviderEntry(
    id: 'play_ht',
    displayName: 'PlayHT',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
    entryPoint: '(未実装 — Voice cloning + TTS API)',
    note: '音声クローニング × 超低遅延 TTS の老舗プラットフォーム',
  ),

  // ===== 中国系 LLM =====
  AiProviderEntry(
    id: 'baichuan',
    displayName: 'Baichuan AI',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.budget,
    entryPoint: '(未実装 — 医療 AI 特化)',
    note: '百川智能・医療 AI 特化の中国 LLM (Baichuan2-Med)',
  ),
  AiProviderEntry(
    id: 'stepfun',
    displayName: 'StepFun',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
    entryPoint: '(未実装 — Step-2 MoE API)',
    note: '阶跃星辰・MoE 196B/11B activated・256K context・中国フロンティア',
  ),

  // ===== インド AI =====
  AiProviderEntry(
    id: 'krutrim',
    displayName: 'Krutrim AI',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
    entryPoint: '(未実装 — Krutrim Cloud API)',
    note: 'インド発・22言語対応の AI ユニコーン (Ola 創業者 Bhavish Aggarwal)',
  ),

  // ===== 推論基盤 / モデルデプロイ =====
  AiProviderEntry(
    id: 'baseten',
    displayName: 'Baseten',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
    entryPoint: 'https://www.baseten.co/',
    note: '本番向け AI モデルデプロイメント基盤 (Truss + GPU autoscale)',
  ),
  AiProviderEntry(
    id: 'lepton',
    displayName: 'Lepton AI',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
    entryPoint: '(未実装 — NVIDIA DGX Cloud Lepton)',
    note: 'NVIDIA 傘下の超高速推論プラットフォーム (DGX Cloud 統合)',
  ),
  AiProviderEntry(
    id: 'radixark',
    displayName: 'RadixArk (SGLang)',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.budget,
    entryPoint: '(未実装 — SGLang ベース高効率推論)',
    note: 'SGLang ベース・RadixAttention 最大 5x スループット改善',
  ),

  // ===== ベクター / 検索基盤 =====
  AiProviderEntry(
    id: 'pinecone',
    displayName: 'Pinecone',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
    entryPoint: '(未実装 — RAG 用ベクター DB)',
    note: 'RAG・セマンティック検索に特化したクラウドネイティブベクター DB',
  ),
  AiProviderEntry(
    id: 'jina_ai',
    displayName: 'Jina AI',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.budget,
    entryPoint: '(未実装 — Embeddings v3 / Reader API)',
    note: r'検索基盤 (jina-embeddings-v3 多言語 / $0.02/1M tokens)',
  ),

  // ===== LLM Ops / フレームワーク =====
  AiProviderEntry(
    id: 'langchain',
    displayName: 'LangChain',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(参考 — LLM アプリ構築フレームワーク・provider ではない)',
    note: 'LLM アプリ構築の事実上の標準フレームワーク (LangSmith / LangGraph)',
  ),
  AiProviderEntry(
    id: 'modular',
    displayName: 'Modular MAX',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
    entryPoint: '(未実装 — Mojo / MAX Engine)',
    note: 'Mojo 言語 + MAX Engine による高効率推論 (Llama 3 / Mistral 対応)',
  ),
  AiProviderEntry(
    id: 'wandb',
    displayName: 'Weights & Biases',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(参考 — ML 実験管理・LLMOps 業界標準)',
    note: 'ML 実験管理・モデル監視・LLMOps の業界標準 (W&B Weave LLM 評価)',
  ),

  // ===== PS版#3 Session 8-13 で seed 追加した 12 プロバイダー (Win版#131 part 8 で registry 同期) =====

  // Decart — リアルタイム動画生成 ($3.1B)
  AiProviderEntry(
    id: 'decart',
    displayName: 'Decart',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.premium,
    entryPoint: '(未実装 — Oasis / MirageLSD API)',
    note: r'世界初のリアルタイム動画生成 AI ($3.1B 評価額)',
  ),
  // Goodfire — Interpretability ($1.25B)
  AiProviderEntry(
    id: 'goodfire',
    displayName: 'Goodfire',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
    entryPoint: '(未実装 — Ember API / interpretability platform)',
    note: r'AI Interpretability の最前線 ($1.25B 評価額・Anthropic 投資)',
  ),
  // Nous Research — 分散学習 + Hermes
  AiProviderEntry(
    id: 'nous_research',
    displayName: 'Nous Research',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
    entryPoint: '(未実装 — Hermes 4 / Psyche 分散学習)',
    note: r'分散学習 Psyche × オープン Hermes モデル ($65M Paradigm)',
  ),

  // ===== ベクター / RAG / データインフラ =====
  AiProviderEntry(
    id: 'qdrant',
    displayName: 'Qdrant',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.budget,
    entryPoint: '(未実装 — Rust 製 OSS ベクター DB)',
    note: 'ハイパフォーマンス・ベクター DB・セルフホスト可・ゼロコスト',
  ),
  AiProviderEntry(
    id: 'llamaindex',
    displayName: 'LlamaIndex',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(参考 — LLM アプリ向けデータフレームワーク)',
    note: 'LLM アプリ向けデータフレームワーク (RAG の標準ツール・LangChain と双璧)',
  ),
  AiProviderEntry(
    id: 'oxen_ai',
    displayName: 'Oxen AI',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(参考 — ML データ Git ライクバージョン管理)',
    note: '機械学習データのための Git ライクなバージョン管理',
  ),

  // ===== LLM Ops / 開発プラットフォーム =====
  AiProviderEntry(
    id: 'predibase',
    displayName: 'Predibase',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
    entryPoint: '(未実装 — LoRAX / 1 GPU で 1000+ アダプター)',
    note: 'LoRA ファインチューニングを民主化する LLM 開発プラットフォーム',
  ),
  AiProviderEntry(
    id: 'argilla',
    displayName: 'Argilla',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(参考 — LLM アノテーション OSS)',
    note: 'LLM 学習データのアノテーション・品質管理 OSS (RLHF/SFT・HF 統合)',
  ),
  AiProviderEntry(
    id: 'dify',
    displayName: 'Dify',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(参考 — ノーコード LLM ワークフロービルダー)',
    note: 'ノーコードで LLM アプリを構築する OSS (GitHub ★80,000+)',
  ),
  AiProviderEntry(
    id: 'lightning_ai',
    displayName: 'Lightning AI',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
    entryPoint: '(未実装 — Lightning Cloud / PyTorch Lightning)',
    note: 'PyTorch Lightning 開発チームのクラウド AI 開発環境',
  ),
  AiProviderEntry(
    id: 'roboflow',
    displayName: 'Roboflow',
    status: AiProviderStatus.notImplemented,
    tier: AiProviderTier.performance,
    entryPoint: '(未実装 — CV プラットフォーム / YOLO/SAM 統合)',
    note: 'コンピュータビジョン AI の開発・デプロイ統合プラットフォーム (Universe 100,000+ データセット)',
  ),
  AiProviderEntry(
    id: 'weave',
    displayName: 'W&B Weave',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(参考 — LLM デバッグ・評価・改善プラットフォーム)',
    note: 'Weights & Biases 系 LLM アプリのデバッグ・評価・改善 (Weave Trace)',
  ),

  // ===== AI 研究・インフラ (2026-04-20 追加) =====
  AiProviderEntry(
    id: 'prime_intellect',
    displayName: 'Prime Intellect',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — INTELLECT-1 分散学習 / P2P AI)',
    note: '分散学習プロトコル INTELLECT-1 で 10B 規模モデルを P2P ネットワーク訓練',
  ),
  AiProviderEntry(
    id: 'exa',
    displayName: 'Exa',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — Neural Web Search API)',
    note: 'ニューラル検索特化 API (LLM 向け Web 検索・意味的類似検索)',
  ),
  AiProviderEntry(
    id: 'pleias',
    displayName: 'Pleias',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — Common Corpus / EU AI Act 準拠 OSS)',
    note: 'Common Corpus 2T トークン / Apache 2.0 / EU AI Act 対応・引用ネイティブ LLM',
  ),
  AiProviderEntry(
    id: 'imbue',
    displayName: 'Imbue',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — 推論特化 LLM / CARBS OSS)',
    note: '推論特化 70B 自社訓練 + CARBS コスト認識 HPO OSS 公開',
  ),
  AiProviderEntry(
    id: 'thinking_machines',
    displayName: 'Thinking Machines Lab',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — Tinker fine-tune API / Mira Murati 創業)',
    note:
        'Mira Murati (ex-OpenAI CTO) + John Schulman 創業 / \$2B seed / Tinker API',
  ),
  AiProviderEntry(
    id: 'kyutai',
    displayName: 'Kyutai',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — Moshi full-duplex voice / CC-BY 4.0)',
    note: 'フランス AI 研究所 / Moshi リアルタイム音声対話 + Helium-1 / 完全 OSS',
  ),
  AiProviderEntry(
    id: 'contextual_ai',
    displayName: 'Contextual AI',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — RAG 2.0 / Agent Composer)',
    note: 'RAG 発明者 Douwe Kiela 創業 / RAG 2.0 end-to-end + GLM FACTS SOTA',
  ),
  AiProviderEntry(
    id: 'snorkel_ai',
    displayName: 'Snorkel AI',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — Weak Supervision / Data-Centric AI)',
    note: 'Alex Ratner / Stanford DAWN lab 発 / 弱教師あり学習で LLM 学習データ効率化',
  ),
  AiProviderEntry(
    id: 'haize_labs',
    displayName: 'Haize Labs',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — AI 安全性評価 / Red-Teaming)',
    note: '"Moody\'s for AI" / AI リスク自動評価 (ACG・Cascade・Sphynx) / Harvard trio',
  ),
  AiProviderEntry(
    id: 'physical_intelligence',
    displayName: 'Physical Intelligence',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — π-0 / π-0.5 VLA ロボット基盤モデル)',
    note: 'Sergey Levine 共同創業 / π-0 OSS VLA / \$400M + \$600M / \$11B 交渉中',
  ),
  AiProviderEntry(
    id: 'isomorphic_labs',
    displayName: 'Isomorphic Labs',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — AlphaFold 3 / IsoDDE 創薬 AI)',
    note:
        'Demis Hassabis Nobel 2024 / DeepMind spinout / Eli Lilly + Novartis \$3B 契約',
  ),

  // ===== AI 企業・vibe-coding (2026-04-21 追加) =====
  AiProviderEntry(
    id: 'sierra_ai',
    displayName: 'Sierra',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — Agentic CX SaaS / Fortune 50 顧客)',
    note:
        'Bret Taylor (OpenAI 会長) + Clay Bavor 創業 / ARR \$150M / \$10B valuation',
  ),
  AiProviderEntry(
    id: 'figure_ai',
    displayName: 'Figure AI',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — Figure 03 人型ロボット / Helix VLA)',
    note:
        'Brett Adcock 創業 / Helix VLA 自社化 + BMW 工場 / \$1.9B 累計 / \$39B valuation',
  ),
  AiProviderEntry(
    id: 'replit',
    displayName: 'Replit',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — Agent 4 cloud IDE + 即本番 deploy)',
    note:
        'Agent 4 canvas / FY2025 \$240M (24×) / \$400M Series D Georgian / \$9B val',
  ),
  AiProviderEntry(
    id: 'cursor',
    displayName: 'Cursor',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.cursor.com/',
    note:
        r'Anysphere 製 AI ネイティブコードエディタ (VS Code fork) / $9.9B valuation / Tab+Composer+Agent / Claude Sonnet 4.6 標準',
  ),
  AiProviderEntry(
    id: 'lovable',
    displayName: 'Lovable',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://lovable.dev/',
    note:
        r'Anton Osika 創業 (GPT Engineer 後継) / $50M Series A Balderton / Claude + Supabase / vibe-coding 旗手',
  ),
  AiProviderEntry(
    id: 'bolt_new',
    displayName: 'Bolt.new',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://bolt.new/',
    note:
        r'StackBlitz 製 WebContainers (ブラウザ内 Node.js) / 初月 450 万 PJ / Claude Sonnet デフォルト',
  ),
  AiProviderEntry(
    id: 'v0',
    displayName: 'v0 by Vercel',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — AI UI generator + Vercel 直結 deploy)',
    note:
        'Vercel 公式 AI UI 生成 / React + Next.js + shadcn/ui / 1 click Vercel deploy',
  ),
  AiProviderEntry(
    id: 'windsurf',
    displayName: 'Windsurf',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — Cascade agent + Supercomplete IDE)',
    note:
        '旧 Codeium / Cascade 自律 multi-file agent + Supercomplete / SOC 2 + SAML SSO',
  ),
  AiProviderEntry(
    id: 'hume_ai',
    displayName: 'Hume AI',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — EVI WebSocket / Expression Measurement API・非OpenAI互換)',
    note:
        r'感情知能 Voice AI (EVI 3 / EVI 4-mini) — $219M valuation / 2026-01 Google DeepMind acqui-hire',
  ),
  AiProviderEntry(
    id: 'glean',
    displayName: 'Glean',
    status: AiProviderStatus.notImplemented,
    entryPoint: '(未実装 — Enterprise SaaS / Agents API・MCP Server・法人契約必須)',
    note:
        r'企業 Work AI 検索 (100+ コネクタ / Work Knowledge Graph) — $7.2B valuation / $100M+ ARR',
  ),
  AiProviderEntry(
    id: 'vapi',
    displayName: 'Vapi',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://vapi.ai/',
    note: r'リアルタイム音声 AI エージェントインフラ — $0.05/分・500-800ms レイテンシ・1M 同時通話対応',
  ),
  AiProviderEntry(
    id: 'e2b',
    displayName: 'E2B',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://e2b.dev/',
    note:
        r'AI エージェント向けコード実行サンドボックス — 200ms 起動・Fortune 100 の 88% 採用・$21M Series A',
  ),
  AiProviderEntry(
    id: 'firecrawl',
    displayName: 'Firecrawl',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://firecrawl.dev/',
    note:
        r'LLM 向け Web スクレイピング API — HTML → クリーン Markdown/JSON 変換・OSS 29k stars・RAG 必須ツール',
  ),
  AiProviderEntry(
    id: 'weaviate',
    displayName: 'Weaviate',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://weaviate.io/',
    note:
        r'AI-native マルチモーダルベクターDB — 組み込み Embeddings/RAG・OSS 14k stars・$50M 調達・2,000+ 本番企業',
  ),
  AiProviderEntry(
    id: 'livekit',
    displayName: 'LiveKit',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://livekit.io/',
    note:
        r'リアルタイム音声・映像 AI エージェントインフラ — OpenAI Voice Mode バックエンド・$100M Series C・$1B valuation',
  ),
  AiProviderEntry(
    id: 'higgsfield',
    displayName: 'Higgsfield AI',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://higgsfield.ai/',
    note:
        r'マルチモデル AI 動画生成プラットフォーム — Sora 2/Veo 3.1/Kling 3.0 統合・$1.3B valuation・$300M ARR',
  ),
  AiProviderEntry(
    id: 'browserbase',
    displayName: 'Browserbase',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.browserbase.com/',
    note:
        r'AI エージェント向けヘッドレスブラウザインフラ — Stagehand OSS / Perplexity+Vercel 採用 / $40M Series B @$300M',
  ),
  AiProviderEntry(
    id: 'tavily',
    displayName: 'Tavily',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://tavily.com/',
    note:
        r'AI エージェント・RAG 向けリアルタイム Web 検索 API — LangChain/LlamaIndex 公式統合・Free 1,000 クレジット/月',
  ),
  AiProviderEntry(
    id: 'nomic_ai',
    displayName: 'Nomic AI',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.nomic.ai/',
    note:
        r'OSS 特化 embedding インフラ — nomic-embed-text (8192ctx / OpenAI 超え) / Apache 2.0 / Ollama 対応 / $17M Series A',
  ),
  AiProviderEntry(
    id: 'chroma',
    displayName: 'Chroma',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.trychroma.com/',
    note:
        r'Developer-first OSS ベクターDB — pip install 3行起動 / Rust 4× / Chroma Cloud GA / $18M seed / GitHub 20k+ stars',
  ),
  AiProviderEntry(
    id: 'upstage',
    displayName: 'Upstage',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.upstage.ai/',
    note:
        r'韓国初ジェネラティブ AI ユニコーン — Solar Pro 2 (GPT-4.1 超え) / Document Parse / $279.7M 累計 / KOSPI IPO 2026',
  ),
  AiProviderEntry(
    id: 'modal',
    displayName: 'Modal',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://modal.com/',
    note:
        r'Python-native サーバーレス GPU クラウド — @modal.function 1行デプロイ / H100/B200対応 / $1.1B 評価 / 無料 $30/月',
  ),
  AiProviderEntry(
    id: 'runpod',
    displayName: 'RunPod',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.runpod.io/',
    note:
        r'格安 GPU マーケットプレイス — RTX3090 $0.19/h / Serverless 200ms CS / 30+ GPU SKU / 秒課金',
  ),
  AiProviderEntry(
    id: 'arize_ai',
    displayName: 'Arize AI',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://arize.com/',
    note:
        r'LLM観測・評価 — Phoenix OSS (完全無料 / Claude Code CLI統合) / LLM-as-judge / $131M / 多フレームワーク',
  ),
  AiProviderEntry(
    id: 'langsmith',
    displayName: 'LangSmith',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.langchain.com/langsmith',
    note:
        r'LangChain公式 LLM観測 — ユニコーン$1.25B / 9,000万DL / Fortune500 35% / 12×トレース成長 / BYOC self-host / $260M累計',
  ),
  AiProviderEntry(
    id: 'comet_ml',
    displayName: 'Comet ML',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.comet.com/',
    note:
        r'ML実験追跡 & LLMトレーシング — Opik OSS (Apache 2.0 / self-host) / 2013年老舗 / $70M累計 / $17M ARR / W&B補完',
  ),
  AiProviderEntry(
    id: 'braintrust',
    displayName: 'Braintrust',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.braintrust.dev',
    note:
        r'AI観測・評価インフラ — $800M評価 (2026-02 Series B $80M / ICONIQ+a16z) / Loop AI agent / Notion Stripe Vercel採用 / 1M spans無料',
  ),
  AiProviderEntry(
    id: 'galileo',
    displayName: 'Galileo AI',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://galileo.ai/',
    note:
        r'LLM評価・ガードレール・本番監視 — Google AI創業 / $68M / Luna-2評価モデル / Cisco提携 / Evaluate+Observe+Protect 3層',
  ),
  AiProviderEntry(
    id: 'prefect',
    displayName: 'Prefect',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.prefect.io',
    note:
        r'Python-firstワークフローオーケストレーション — Data+ML+AIエージェント統合 / Horizon AI infra / $46M (Tiger Global) / 使用量課金なし',
  ),
  AiProviderEntry(
    id: 'confident_ai',
    displayName: 'Confident AI',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.confident-ai.com/',
    note:
        r'LLM評価OSS DeepEval — Apache 2.0 / Pytest互換 / 50+メトリクス / G-Eval / RAG+Agent+安全性評価 / CI/CD統合',
  ),
  AiProviderEntry(
    id: 'crewai',
    displayName: 'CrewAI',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://crewai.com/',
    note:
        r'マルチエージェントオーケストレーション — Fortune500 60%採用 / 月4.5億workflow / 10万+認定dev / $24.5M Insight Partners / DocuSign PwC',
  ),
  AiProviderEntry(
    id: 'patronus_ai',
    displayName: 'Patronus AI',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.patronus.ai/',
    note:
        r'LLM自動評価・安全 — Meta AI創業 / $40.1M Lightspeed / FinanceBench (業界初) / CopyrightCatcher / 50+失敗カテゴリ',
  ),
  AiProviderEntry(
    id: 'autogen',
    displayName: 'AutoGen',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://microsoft.github.io/autogen/',
    note:
        r'Microsoft Research OSS マルチエージェント — 40k+ Stars / AgentChat+Core+Studio 3層 / Actor Model / Claude対応',
  ),
  AiProviderEntry(
    id: 'agno',
    displayName: 'Agno (旧 phidata)',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.agno.com/',
    note:
        r'Python-native エージェント — Memory (SQLite/PG) + Knowledge (RAG) + Tools 100+ + Agent Teams / Agno Cloud',
  ),
  AiProviderEntry(
    id: 'haystack',
    displayName: 'Haystack (deepset)',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://haystack.deepset.ai/',
    note:
        r'OSS RAG・LLM アプリフレームワーク — 17k+ Stars / Component DAG / 50+DocumentStore / deepset Cloud / Claude対応',
  ),
  AiProviderEntry(
    id: 'zenml',
    displayName: 'ZenML',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://zenml.io/',
    note:
        r'OSS MLOps パイプライン — @step/@pipeline デコレータ / Stack抽象化 (Vertex/SageMaker) / 50+ integrations / ZenML Pro',
  ),
  AiProviderEntry(
    id: 'vllm',
    displayName: 'vLLM',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://docs.vllm.ai/',
    note:
        r'UC Berkeley 高スループット LLM 推論 — PagedAttention / 35k+ Stars / Continuous Batching / OpenAI互換 / 量子化AWQ/GPTQ',
  ),
  AiProviderEntry(
    id: 'ragas',
    displayName: 'Ragas',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://docs.ragas.io/',
    note:
        r'RAG評価OSS — Faithfulness/Answer Relevance/Context 4メトリクス / TestsetGenerator / LangChain・LlamaIndex統合 / pytest CI',
  ),
  AiProviderEntry(
    id: 'continue_dev',
    displayName: 'Continue.dev',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://docs.continue.dev/',
    note:
        r'OSS AIコーディングアシスタント — VS Code/JetBrains / 任意LLM接続 (Claude/Ollama) / YAML設定 / 12k+ Stars / Apache 2.0',
  ),
  AiProviderEntry(
    id: 'aider',
    displayName: 'Aider',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://aider.chat/',
    note:
        r'AI ペアプログラマー CLI — Git自動コミット / 複数ファイル横断編集 / Claude/DeepSeek対応 / 22k+ Stars / SWE-bench高スコア',
  ),
  AiProviderEntry(
    id: 'dspy',
    displayName: 'DSPy',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://dspy.ai/',
    note:
        r'Stanford発 LLM "プログラミング" FW — Signature/Module/Optimizer / BootstrapFewShot自動最適化 / 18k+ Stars / Apache 2.0',
  ),
  AiProviderEntry(
    id: 'pydantic_ai',
    displayName: 'Pydantic AI',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://ai.pydantic.dev/',
    note:
        r'型安全 Python エージェントFW — Pydantic V2 基盤 / 依存性注入 / TestModel / FastAPI 親和性 / 6k+ Stars / MIT',
  ),
  AiProviderEntry(
    id: 'litellm',
    displayName: 'LiteLLM',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://docs.litellm.ai/',
    note:
        r'100+ LLM 統合プロキシ — OpenAI 互換 API / フォールバック / ロードバランシング / Redis キャッシュ / 15k+ Stars / Apache 2.0',
  ),
  AiProviderEntry(
    id: 'langgraph',
    displayName: 'LangGraph',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://langchain-ai.github.io/langgraph/',
    note:
        r'ステートフル LLM グラフFW — ループ/条件分岐/Human-in-Loop / 永続化 / マルチエージェント / 11k+ Stars / MIT',
  ),
  AiProviderEntry(
    id: 'composio',
    displayName: 'Composio',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://composio.dev/',
    note:
        r'AI エージェント向けツール統合プラットフォーム — 250+ アプリ (GitHub/Slack/Gmail等) / OAuth 管理 / LangGraph・CrewAI・OpenAI Agents SDK 対応 / $53M Series A (Kleiner Perkins)',
  ),
  AiProviderEntry(
    id: 'instructor',
    displayName: 'Instructor',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://python.useinstructor.com/',
    note:
        r'LLM 構造化出力ライブラリ — Pydantic モデルで型安全な LLM レスポンス / OpenAI・Anthropic・Gemini 対応 / 自動バリデーション&リトライ / 10k+ Stars / MIT / Jason Liu 作',
  ),
  AiProviderEntry(
    id: 'flowise',
    displayName: 'Flowise',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://flowiseai.com/',
    note:
        r'ノーコード LLM アプリビルダー — ドラッグ&ドロップ UI / LangChain・LlamaIndex ベース / セルフホスト可 / 28k+ Stars / MIT / Chatflow & Agentflow',
  ),
  AiProviderEntry(
    id: 'amazon_bedrock',
    displayName: 'Amazon Bedrock',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://aws.amazon.com/bedrock/',
    note:
        r'AWS マネージド LLM サービス — Claude・Titan・Llama・Mistral を API 1 本で提供 / Guardrails / Agents / Knowledge Bases / エンタープライズ RAG / VPC 統合',
  ),
  AiProviderEntry(
    id: 'codeium',
    displayName: 'Codeium',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://codeium.com/',
    note:
        r'無料 AI コード補完 — VS Code/JetBrains/Vim 70+ エディタ対応 / Windsurf IDE 同社製 / 企業向け Codeium Enterprise / 70k+ 開発者 / $150M Series C',
  ),
  AiProviderEntry(
    id: 'n8n',
    displayName: 'n8n',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://n8n.io/',
    note:
        r'オープンソースワークフロー自動化 — 400+ 統合 / AI Agent ノード内蔵 / セルフホスト可 / 40k+ Stars / Apache 2.0 / LLM+ツール組合せ自由',
  ),
  AiProviderEntry(
    id: 'azure_openai',
    displayName: 'Azure OpenAI',
    status: AiProviderStatus.notImplemented,
    entryPoint:
        'https://azure.microsoft.com/ja-jp/products/ai-services/openai-service',
    note:
        r'Microsoft Azure上のマネージドOpenAI — GPT-4o/o1/DALL-E/Whisper / プライベートエンドポイント / RBAC / HIPAA・SOC2対応 / Fortune 100の90%+ 採用 / コンテンツフィルタ',
  ),
  AiProviderEntry(
    id: 'semantic_kernel',
    displayName: 'Semantic Kernel',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://learn.microsoft.com/ja-jp/semantic-kernel/',
    note:
        r'Microsoft 製 AI エージェント SDK — .NET / Python / Java 対応 / Planner (自動タスク分解) / Memory / Plugin / GitHub Copilot・Azure OpenAI 統合 / MIT / 21k+ Stars',
  ),
  AiProviderEntry(
    id: 'tabnine',
    displayName: 'Tabnine',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.tabnine.com/',
    note:
        r'エンタープライズ AI コード補完 — オンプレミス/VPC デプロイ / SOC2・GDPR / 学習データ非使用保証 / 1M+ 開発者 / $53M 調達 / VS Code・JetBrains 対応',
  ),
  AiProviderEntry(
    id: 'gamma_app',
    displayName: 'Gamma',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://gamma.app/',
    note:
        r'AI プレゼンテーション・ドキュメントビルダー — テキスト→スライド瞬時生成 / Notion+Canva 融合型 / Web公開可 / $12M 調達 / 月間4M+ ユーザー',
  ),
  AiProviderEntry(
    id: 'tome_app',
    displayName: 'Tome',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://tome.app/',
    note:
        r'AI プレゼンテーション・ドキュメント生成 — テキスト→ページ/スライド自動生成 / AI narration / GPT-4 統合 / $75M 調達 / 5M+ ユーザー / Coatue 主導 Series B',
  ),
  AiProviderEntry(
    id: 'krisp',
    displayName: 'Krisp',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://krisp.ai/',
    note:
        r'AI ノイズキャンセリング & ミーティングアシスタント — 背景雑音/エコー/残響除去 / Zoom・Teams・Meet 対応 / 文字起こし・サマリー / $9.5M 調達 / 20M+ ユーザー',
  ),
  AiProviderEntry(
    id: 'otter_ai',
    displayName: 'Otter.ai',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://otter.ai/',
    note:
        r'AI ミーティングアシスタント — リアルタイム文字起こし / 要約・アクションアイテム自動抽出 / Zoom・Teams・Meet 統合 / $50M 調達 / 月間 1M+ ユーザー / SpeechX モデル',
  ),
  AiProviderEntry(
    id: 'murf_ai',
    displayName: 'Murf',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://murf.ai/',
    note:
        r'AI 音声生成 (Text-to-Speech) — 120+ 言語・声 / スタジオ品質 / ビデオ同期 / Canva 統合 / API 提供 / $10M 調達 / エンタープライズ対応',
  ),
  AiProviderEntry(
    id: 'coqui_ai',
    displayName: 'Coqui',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://coqui.ai/',
    note:
        r'OSS 音声クローン TTS — XTTS-v2 (多言語 / 3秒サンプルで声クローン) / Apache 2.0 / Hugging Face 統合 / 6ヶ国語対応 / コミュニティ主導継続開発',
  ),
  AiProviderEntry(
    id: 'resemble_ai',
    displayName: 'Resemble AI',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.resemble.ai/',
    note:
        r'リアルタイム音声クローン & 合成 — <50ms レイテンシ / ゲーム・会話 AI 向け / Deepfake Detection / $8M 調達 / 感情・スタイル制御',
  ),
  AiProviderEntry(
    id: 'speechify',
    displayName: 'Speechify',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://speechify.com/',
    note:
        r'AI 読み上げ & 音声クローン SaaS — 20M+ ユーザー / 30+ 言語 / 著名人音声 / API 提供 / Chrome 拡張 / iOS/Android / $76M 調達 / ★8/9',
  ),
  AiProviderEntry(
    id: 'wellsaid_labs',
    displayName: 'WellSaid Labs',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://wellsaidlabs.com/',
    note:
        r'エンタープライズ向け AI 音声クローン — スタジオ品質 / API + Studio UI / 同意ベース声クローン / コンテンツ制作特化 / $10M+ 調達 / ★8/9',
  ),
  AiProviderEntry(
    id: 'lovo_ai',
    displayName: 'LOVO (Genny)',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://lovo.ai/',
    note:
        r'AI 音声 + 動画エディタ統合 — 500+ AI 音声 / 100+ 言語 / Genny AI 動画ツール / 感情制御 / Canva 対抗 / $7M 調達 / ★8/9',
  ),
  AiProviderEntry(
    id: 'aiva',
    displayName: 'AIVA',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.aiva.ai/',
    note:
        r'AI 作曲 (Artificial Intelligence Virtual Artist) — SACEM 登録 / クラシック/ゲーム/映画音楽生成 / 著作権フリー / API 提供 / ★8/9',
  ),
  AiProviderEntry(
    id: 'mubert',
    displayName: 'Mubert',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://mubert.com/',
    note:
        r'AI BGM ストリーミング生成 — リアルタイム無限ループ / ムード・BPM・ジャンル指定 / React Native SDK / API 提供 / 著作権フリー / ★8/9',
  ),
  AiProviderEntry(
    id: 'beatoven_ai',
    displayName: 'Beatoven.ai',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.beatoven.ai/',
    note:
        r'動画・Podcast 向け AI BGM 生成 — シーン別感情 BGM / 自動楽曲カスタム / 著作権フリー / MP3/WAV / $3M 調達 / ★7/9',
  ),
  AiProviderEntry(
    id: 'lalal_ai',
    displayName: 'Lalal.ai',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.lalal.ai/',
    note:
        r'AI 音声・ステム分離 — ボーカル / 楽器 / ドラム / ベースを個別抽出 / Phoenix Neural Net / 10音源分離 / API 提供 / ★8/9',
  ),
  AiProviderEntry(
    id: 'soundraw',
    displayName: 'Soundraw',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://soundraw.io/',
    note:
        r'AI 音楽生成 (クリエイター向け) — ムード/テンポ/楽器を GUI で指定 / 無制限生成 / 著作権フリー / Premiere Pro 統合 / ★8/9',
  ),
  AiProviderEntry(
    id: 'sora',
    displayName: 'Sora',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://openai.com/sora',
    note:
        r'OpenAI 動画生成 AI — Sora 2 / DiT / 最大 60 秒長尺 / 物理シミュレーション / Multi-shot / 2026 GA / API ($0.10-0.50/秒) / ★9/9',
  ),
  AiProviderEntry(
    id: 'meshy',
    displayName: 'Meshy',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.meshy.ai/',
    note:
        r'AI 3D モデル生成 — text-to-3D / image-to-3D / GLB/FBX/USDZ 出力 / Unity・Unreal 統合 / Pro \$20/月 / ★8/9',
  ),
  // === DB seed には存在するが registry 漏れ補正 (Win版#132 part 26 / Master Brain 提案 #5) ===
  AiProviderEntry(
    id: 'adobe-firefly',
    displayName: 'Adobe Firefly',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://firefly.adobe.com/',
    note:
        r'Adobe 商業利用安全な生成 AI — Creative Cloud 統合 / 学習データ商用 OK / Generative Fill / Text-to-Image / ★9/9',
  ),
  AiProviderEntry(
    id: 'fireflies-ai',
    displayName: 'Fireflies.ai',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://fireflies.ai/',
    note:
        r'AI 会議アシスタント — 自動文字起こし + 要約 + Action Items / Slack/CRM 統合 / GraphQL API / ★8/9',
  ),
  AiProviderEntry(
    id: 'gong',
    displayName: 'Gong',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.gong.io/',
    note:
        r'AI Revenue Intelligence — 営業通話録音 + 分析 + コーチング / 勝率 +21% / \$7.25B 評価 / エンタープライズ特化 / ★9/9',
  ),
  AiProviderEntry(
    id: 'canva-ai',
    displayName: 'Canva AI',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.canva.com/ai/',
    note:
        r'世界最大デザイン PF + AI — Magic Studio / Magic Design / Magic Write / MAU 1.5 億+ / \$26B 評価 / ★9/9',
  ),
  AiProviderEntry(
    id: 'zapier-ai',
    displayName: 'Zapier AI',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://zapier.com/ai',
    note:
        r'WF 自動化の王者 + AI — 6000+ アプリ連携 / Zapier Central AI Agent / Fortune 500 87% 利用 / ★9/9',
  ),
  AiProviderEntry(
    id: 'framer-ai',
    displayName: 'Framer AI',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.framer.com/ai/',
    note: r'AI Web サイトビルダー — 自然言語でサイト生成 / React 出力 / デザイナー特化 / ノーコード / ★8/9',
  ),
  AiProviderEntry(
    id: 'beautiful-ai',
    displayName: 'Beautiful.ai',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://www.beautiful.ai/',
    note:
        r'AI プレゼンビルダー — Smart Slides 自動レイアウト調整 / デザイン品質担保 / 企業向け / API 提供 / ★8/9',
  ),
  AiProviderEntry(
    id: 'writesonic',
    displayName: 'Writesonic',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://writesonic.com/',
    note:
        r'AI コピーライティング — Chatsonic / Botsonic / Article Writer 6 / 100+ 言語 / SEO 最適化 / ★8/9',
  ),
  AiProviderEntry(
    id: 'dust',
    displayName: 'Dust',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://dust.tt/',
    note:
        r'エンタープライズ AI Agent PF — カスタム AI アシスタント / Slack/Notion 統合 / マルチモデル対応 / ★8/9',
  ),
  AiProviderEntry(
    id: 'sierra',
    displayName: 'Sierra',
    status: AiProviderStatus.notImplemented,
    entryPoint: 'https://sierra.ai/',
    note:
        r'AI カスタマーサービス Agent — Bret Taylor (元 OpenAI 会長 / 元 Salesforce co-CEO) + Clay Bavor 創業 / エンタープライズ特化 / ★8/9',
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
