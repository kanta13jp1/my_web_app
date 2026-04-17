import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── ステータス定義 ────────────────────────────────────────────────────────────

enum ProviderStatus {
  implemented,   // 実装済み
  needsApiKey,   // 実装済みだがAPIキー設定が必要
  needsPayment,  // 実装済みだがプロバイダーに課金が必要
  notImplemented, // 未実装
}

class ProviderInfo {
  final String id;
  final String name;
  final String emoji;
  final ProviderStatus status;
  final String description;
  final String? model;

  const ProviderInfo({
    required this.id,
    required this.name,
    required this.emoji,
    required this.status,
    required this.description,
    this.model,
  });
}

// ── 全プロバイダー定義 ────────────────────────────────────────────────────────

const _providers = <ProviderInfo>[
  // ── 実装済み ──────────────────────────────────────────────────────────────
  ProviderInfo(id: 'google',     name: 'Google AI',       emoji: '🔵', status: ProviderStatus.implemented,   description: 'Gemini 2.0 Flash',          model: 'gemini-2.0-flash'),
  ProviderInfo(id: 'anthropic',  name: 'Anthropic',       emoji: '🟠', status: ProviderStatus.implemented,   description: 'Claude Haiku 4.5',          model: 'claude-haiku-4-5'),
  ProviderInfo(id: 'groq',       name: 'Groq',            emoji: '⚡', status: ProviderStatus.implemented,   description: 'LLaMA 3.3 70B (超高速)',    model: 'llama-3.3-70b'),

  // ── APIキー設定が必要 ─────────────────────────────────────────────────────
  ProviderInfo(id: 'openai',      name: 'OpenAI',          emoji: '🤖', status: ProviderStatus.needsApiKey, description: 'GPT-4o-mini',               model: 'gpt-4o-mini'),
  ProviderInfo(id: 'deepseek',    name: 'DeepSeek',        emoji: '🐋', status: ProviderStatus.needsApiKey, description: 'DeepSeek Chat V3',          model: 'deepseek-chat'),
  ProviderInfo(id: 'mistral',     name: 'Mistral AI',      emoji: '🌪️', status: ProviderStatus.needsApiKey, description: 'Mistral Small',             model: 'mistral-small'),
  ProviderInfo(id: 'cohere',      name: 'Cohere',          emoji: '🔗', status: ProviderStatus.needsApiKey, description: 'Command R+ (RAG特化)',      model: 'command-r-plus'),
  ProviderInfo(id: 'perplexity',  name: 'Perplexity AI',   emoji: '🔍', status: ProviderStatus.needsApiKey, description: 'Sonar 70B (Web検索付き)',   model: 'sonar-70b'),
  ProviderInfo(id: 'x',           name: 'xAI / Grok',      emoji: '𝕏',  status: ProviderStatus.needsApiKey, description: 'Grok-2 (api.x.ai)',        model: 'grok-2'),
  ProviderInfo(id: 'together_ai', name: 'Together AI',     emoji: '🤝', status: ProviderStatus.needsApiKey, description: '多モデルホスティング',        model: 'multiple'),
  ProviderInfo(id: 'fireworks_ai',name: 'Fireworks AI',    emoji: '🎆', status: ProviderStatus.needsApiKey, description: '高速推論プラットフォーム',    model: 'multiple'),
  ProviderInfo(id: 'replicate',   name: 'Replicate',       emoji: '🔄', status: ProviderStatus.needsApiKey, description: 'OSS モデルAPI',              model: 'multiple'),
  ProviderInfo(id: 'openrouter',  name: 'OpenRouter',      emoji: '🌐', status: ProviderStatus.needsApiKey, description: '統合ルーターAPI',             model: 'multiple'),
  ProviderInfo(id: 'elevenlabs',  name: 'ElevenLabs',      emoji: '🔊', status: ProviderStatus.needsApiKey, description: 'テキスト→音声 (TTS)',        model: 'multilingual-v2'),
  ProviderInfo(id: 'assemblyai',  name: 'AssemblyAI',      emoji: '🎙️', status: ProviderStatus.needsApiKey, description: '音声→テキスト (STT)',        model: 'nova-2'),
  ProviderInfo(id: 'nvidia',      name: 'NVIDIA NIM',      emoji: '🟢', status: ProviderStatus.needsApiKey, description: 'NVIDIA AI Endpoints',       model: 'llama-3.1-70b'),
  ProviderInfo(id: 'ai21',        name: 'AI21 Labs',       emoji: '🔬', status: ProviderStatus.needsApiKey, description: 'Jamba 1.5',                 model: 'jamba-1.5'),
  ProviderInfo(id: 'writer',      name: 'Writer',          emoji: '✍️', status: ProviderStatus.needsApiKey, description: 'Palmyra X 004',             model: 'palmyra-x-004'),
  ProviderInfo(id: 'voyage',      name: 'Voyage AI',       emoji: '🚀', status: ProviderStatus.needsApiKey, description: 'Embeddings特化',             model: 'voyage-3'),
  ProviderInfo(id: 'reka',        name: 'Reka',            emoji: '🔮', status: ProviderStatus.needsApiKey, description: 'Reka Core',                 model: 'reka-core'),
  ProviderInfo(id: 'aleph_alpha', name: 'Aleph Alpha',     emoji: '🇩🇪', status: ProviderStatus.needsApiKey, description: 'Luminous (欧州)',           model: 'luminous-supreme'),
  ProviderInfo(id: 'oracle',      name: 'Oracle AI',       emoji: '🏛️', status: ProviderStatus.needsApiKey, description: 'OCI Generative AI',         model: 'cohere.command-r-plus'),
  ProviderInfo(id: 'ollama',      name: 'Ollama',          emoji: '🦙', status: ProviderStatus.needsApiKey, description: 'ローカルLLM実行',            model: 'local'),
  ProviderInfo(id: '01ai',        name: '01.AI (Yi)',       emoji: '①',  status: ProviderStatus.needsApiKey, description: 'Yi-34B API',                model: 'yi-34b'),
  ProviderInfo(id: 'coze',        name: 'Coze',            emoji: '💬', status: ProviderStatus.needsApiKey, description: 'ByteDance Bot Platform',    model: 'bot-api'),
  ProviderInfo(id: 'zhipu',       name: 'Zhipu AI',        emoji: '🇨🇳', status: ProviderStatus.needsApiKey, description: 'ChatGLM-4',                model: 'glm-4'),
  ProviderInfo(id: 'qwen',        name: 'Qwen (Alibaba)',  emoji: '☁️', status: ProviderStatus.needsApiKey, description: 'Qwen2.5-72B',              model: 'qwen2.5-72b'),
  ProviderInfo(id: 'moonshot',    name: 'Moonshot AI',     emoji: '🌙', status: ProviderStatus.needsApiKey, description: 'Kimi (moonshot.cn)',        model: 'moonshot-v1-8k'),
  ProviderInfo(id: 'twelve_labs', name: 'Twelve Labs',     emoji: '📹', status: ProviderStatus.needsApiKey, description: '動画理解AI',                 model: 'pegasus-1'),
  ProviderInfo(id: 'huggingface', name: 'Hugging Face',    emoji: '🤗', status: ProviderStatus.needsApiKey, description: 'Inference API (多モデル)',   model: 'multiple'),

  // ── 課金が必要 ────────────────────────────────────────────────────────────
  ProviderInfo(id: 'midjourney',     name: 'Midjourney',       emoji: '🎨', status: ProviderStatus.needsPayment, description: '画像生成 (Discordサブスク)', model: null),
  ProviderInfo(id: 'runway',         name: 'Runway',           emoji: '🎬', status: ProviderStatus.needsPayment, description: '動画生成 Gen-3 (有料API)',   model: 'gen-3-alpha'),
  ProviderInfo(id: 'suno',           name: 'Suno',             emoji: '🎵', status: ProviderStatus.needsPayment, description: 'AI音楽生成 (サブスク)',      model: null),
  ProviderInfo(id: 'udio',           name: 'Udio',             emoji: '🎶', status: ProviderStatus.needsPayment, description: 'AI音楽生成 (サブスク)',      model: null),
  ProviderInfo(id: 'adobe_firefly',  name: 'Adobe Firefly',    emoji: '🔥', status: ProviderStatus.needsPayment, description: '画像生成 (Creative Cloud)',  model: null),
  ProviderInfo(id: 'heygen',         name: 'HeyGen',           emoji: '👤', status: ProviderStatus.needsPayment, description: 'AI動画アバター (有料API)',   model: null),
  ProviderInfo(id: 'hedra',          name: 'Hedra',            emoji: '🎭', status: ProviderStatus.needsPayment, description: 'キャラクター動画 (有料)',    model: null),
  ProviderInfo(id: 'kling',          name: 'Kling',            emoji: '🎞️', status: ProviderStatus.needsPayment, description: '動画生成 (有料API)',         model: 'kling-v2'),
  ProviderInfo(id: 'luma',           name: 'Luma AI',          emoji: '✨', status: ProviderStatus.needsPayment, description: 'Dream Machine (有料API)',    model: 'dream-machine'),
  ProviderInfo(id: 'ideogram',       name: 'Ideogram',         emoji: '🖼️', status: ProviderStatus.needsPayment, description: '画像生成 (有料API)',         model: 'ideogram-v2'),
  ProviderInfo(id: 'pika',           name: 'Pika',             emoji: '⚡', status: ProviderStatus.needsPayment, description: '動画生成 (有料)',            model: null),
  ProviderInfo(id: 'stability',      name: 'Stability AI',     emoji: '🌈', status: ProviderStatus.needsPayment, description: 'Stable Diffusion (API課金)',model: 'sd3.5-large'),
  ProviderInfo(id: 'hailuo',         name: 'Hailuo AI',        emoji: '🌊', status: ProviderStatus.needsPayment, description: 'MiniMax 動画生成',          model: null),
  ProviderInfo(id: 'krea',           name: 'Krea',             emoji: '🎨', status: ProviderStatus.needsPayment, description: 'AI画像強化 (有料)',          model: null),
  ProviderInfo(id: 'recraft',        name: 'Recraft',          emoji: '✏️', status: ProviderStatus.needsPayment, description: 'ベクターイラスト生成 (有料)',model: 'recraft-v3'),
  ProviderInfo(id: 'runware',        name: 'Runware',          emoji: '🏃', status: ProviderStatus.needsPayment, description: '高速画像生成 (有料API)',     model: null),
  ProviderInfo(id: 'character_ai',   name: 'Character.AI',     emoji: '🎭', status: ProviderStatus.needsPayment, description: 'キャラクターチャット (API未公開)', model: null),
  ProviderInfo(id: 'manus',          name: 'Manus',            emoji: '🤖', status: ProviderStatus.needsPayment, description: 'AI Agentサービス (招待制)',  model: null),

  // ── 未実装 ────────────────────────────────────────────────────────────────
  ProviderInfo(id: 'meta',          name: 'Meta AI',          emoji: '🦙', status: ProviderStatus.notImplemented, description: 'LLaMA (オープンソース)',      model: null),
  ProviderInfo(id: 'microsoft',     name: 'Microsoft Copilot',emoji: '🪟', status: ProviderStatus.notImplemented, description: 'Azure OpenAI (企業向け)',     model: null),
  ProviderInfo(id: 'ibm',           name: 'IBM watsonx',      emoji: '🔷', status: ProviderStatus.notImplemented, description: '企業向けAIプラットフォーム', model: null),
  ProviderInfo(id: 'sakana',        name: 'Sakana AI',        emoji: '🐟', status: ProviderStatus.notImplemented, description: '研究段階 (公開API未提供)',    model: null),
  ProviderInfo(id: 'baidu',         name: 'Baidu ERNIE',      emoji: '🔴', status: ProviderStatus.notImplemented, description: 'ERNIE Bot (中国国内のみ)',    model: null),
  ProviderInfo(id: 'apple',         name: 'Apple Intelligence',emoji: '🍎',status: ProviderStatus.notImplemented, description: 'デバイス内蔵のみ (API未公開)',model: null),
  ProviderInfo(id: 'samsung',       name: 'Samsung Gauss',    emoji: '📱', status: ProviderStatus.notImplemented, description: 'デバイス内蔵のみ',           model: null),
  ProviderInfo(id: 'databricks',    name: 'Databricks DBRX',  emoji: '🧱', status: ProviderStatus.notImplemented, description: 'エンタープライズ向け',       model: null),
  ProviderInfo(id: 'harvey',        name: 'Harvey AI',        emoji: '⚖️', status: ProviderStatus.notImplemented, description: '法律特化AI (法律事務所向け)',model: null),
  ProviderInfo(id: 'naver',         name: 'NAVER HyperCLOVA', emoji: '🇰🇷', status: ProviderStatus.notImplemented, description: '韓国語特化 (国内向け)',     model: null),
  ProviderInfo(id: 'tencent',       name: 'Tencent Hunyuan',  emoji: '🐧', status: ProviderStatus.notImplemented, description: 'Hunyuan (中国国内のみ)',     model: null),
  ProviderInfo(id: 'bytedance',     name: 'ByteDance Doubao', emoji: '🎵', status: ProviderStatus.notImplemented, description: 'Doubao (中国国内のみ)',      model: null),
  ProviderInfo(id: 'black_forest_labs', name: 'Black Forest Labs', emoji: '🌲', status: ProviderStatus.notImplemented, description: 'FLUX (Replicateで利用可)', model: null),
  ProviderInfo(id: 'liquid_ai',     name: 'Liquid AI',        emoji: '💧', status: ProviderStatus.notImplemented, description: 'LFM (エンタープライズ)',     model: null),
  ProviderInfo(id: 'allenai',       name: 'Allen AI',         emoji: '🔬', status: ProviderStatus.notImplemented, description: 'OLMo (研究機関)',           model: null),
  ProviderInfo(id: 'adept',         name: 'Adept AI',         emoji: '🛠️', status: ProviderStatus.notImplemented, description: 'ACT-1 (企業向け統合)',      model: null),
  ProviderInfo(id: 'prover',        name: 'Prover AI',        emoji: '📐', status: ProviderStatus.notImplemented, description: '数学証明特化 (研究)',        model: null),
  ProviderInfo(id: 'lmsys',         name: 'LMSYS',            emoji: '🏆', status: ProviderStatus.notImplemented, description: 'Chatbot Arena (ベンチマーク)',model: null),
  ProviderInfo(id: 'falcon_tii',    name: 'Falcon (TII)',      emoji: '🦅', status: ProviderStatus.notImplemented, description: 'Falcon 180B (オープンソース)',model: null),
  ProviderInfo(id: 'inception_labs',name: 'Inception Labs',   emoji: '🧠', status: ProviderStatus.notImplemented, description: 'Mercury Coder (招待制)',     model: null),
  ProviderInfo(id: 'world_labs',    name: 'World Labs',       emoji: '🌍', status: ProviderStatus.notImplemented, description: '空間インテリジェンス (研究)',model: null),
  ProviderInfo(id: 'sambanova',     name: 'SambaNova',        emoji: '🔴', status: ProviderStatus.notImplemented, description: 'SN50 RDU (ハードウェア)',   model: null),
  ProviderInfo(id: 'snowflake',     name: 'Snowflake Arctic', emoji: '❄️', status: ProviderStatus.notImplemented, description: 'Arctic (データ基盤向け)',    model: null),
  ProviderInfo(id: 'poolside',      name: 'Poolside AI',      emoji: '🏊', status: ProviderStatus.notImplemented, description: 'コード特化 (招待制)',        model: null),
  ProviderInfo(id: 'scale_ai',      name: 'Scale AI',         emoji: '📊', status: ProviderStatus.notImplemented, description: 'データアノテーション特化',   model: null),
  ProviderInfo(id: 'cognition',     name: 'Cognition (Devin)',emoji: '💻', status: ProviderStatus.notImplemented, description: 'AI SWEエージェント (招待制)',model: null),
  ProviderInfo(id: 'inflection',    name: 'Inflection AI',    emoji: '💜', status: ProviderStatus.notImplemented, description: 'Pi (限定API)',              model: null),
  ProviderInfo(id: 'cerebras',      name: 'Cerebras',         emoji: '🧊', status: ProviderStatus.notImplemented, description: 'ウェーハースケールチップ',   model: null),
  ProviderInfo(id: 'core',          name: 'Core (Exa)',       emoji: '🔑', status: ProviderStatus.notImplemented, description: 'Exa Search (研究)',         model: null),
];

// ── ページ本体 ────────────────────────────────────────────────────────────────

class AiProviderStatusPage extends StatefulWidget {
  const AiProviderStatusPage({super.key});

  @override
  State<AiProviderStatusPage> createState() => _AiProviderStatusPageState();
}

class _AiProviderStatusPageState extends State<AiProviderStatusPage> {
  ProviderStatus? _filter;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  List<ProviderInfo> get _filtered {
    final q = _searchQuery.toLowerCase();
    return _providers.where((p) {
      final matchStatus = _filter == null || p.status == _filter;
      final matchSearch = q.isEmpty || p.name.toLowerCase().contains(q) || p.id.contains(q) || p.description.toLowerCase().contains(q);
      return matchStatus && matchSearch;
    }).toList();
  }

  Map<ProviderStatus, int> get _counts => {
    for (final s in ProviderStatus.values) s: _providers.where((p) => p.status == s).length,
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('AI プロバイダー一覧', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('${_providers.length}社', style: const TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 検索バー ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'プロバイダーを検索…',
                hintStyle: const TextStyle(color: Color(0xFF707070)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF707070)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF707070)),
                        onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          // ── フィルターチップ ───────────────────────────────────────────────
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _FilterChip(label: '全て (${_providers.length})', selected: _filter == null, onTap: () => setState(() => _filter = null)),
                const SizedBox(width: 8),
                _FilterChip(label: '実装済み (${_counts[ProviderStatus.implemented]})', selected: _filter == ProviderStatus.implemented, color: const Color(0xFF4CAF50), onTap: () => setState(() => _filter = _filter == ProviderStatus.implemented ? null : ProviderStatus.implemented)),
                const SizedBox(width: 8),
                _FilterChip(label: 'APIキー設定が必要 (${_counts[ProviderStatus.needsApiKey]})', selected: _filter == ProviderStatus.needsApiKey, color: const Color(0xFFFFC107), onTap: () => setState(() => _filter = _filter == ProviderStatus.needsApiKey ? null : ProviderStatus.needsApiKey)),
                const SizedBox(width: 8),
                _FilterChip(label: '課金が必要 (${_counts[ProviderStatus.needsPayment]})', selected: _filter == ProviderStatus.needsPayment, color: const Color(0xFF3D5AFE), onTap: () => setState(() => _filter = _filter == ProviderStatus.needsPayment ? null : ProviderStatus.needsPayment)),
                const SizedBox(width: 8),
                _FilterChip(label: '未実装 (${_counts[ProviderStatus.notImplemented]})', selected: _filter == ProviderStatus.notImplemented, color: const Color(0xFF707070), onTap: () => setState(() => _filter = _filter == ProviderStatus.notImplemented ? null : ProviderStatus.notImplemented)),
              ],
            ),
          ),
          // ── プロバイダーリスト ─────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('該当なし', style: TextStyle(color: Color(0xFF707070))))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _ProviderCard(
                      provider: filtered[i],
                      onTry: filtered[i].status == ProviderStatus.implemented
                          ? () => _openChatSheet(context, filtered[i])
                          : null,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _openChatSheet(BuildContext context, ProviderInfo provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChatSheet(provider: provider),
    );
  }
}

// ── フィルターチップ ──────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color = const Color(0xFFFF6B35)});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : const Color(0xFF333333)),
        ),
        child: Text(label, style: TextStyle(color: selected ? color : const Color(0xFFB0B0B0), fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

// ── プロバイダーカード ─────────────────────────────────────────────────────────

class _ProviderCard extends StatelessWidget {
  final ProviderInfo provider;
  final VoidCallback? onTry;

  const _ProviderCard({required this.provider, this.onTry});

  static _statusConfig(ProviderStatus s) => switch (s) {
    ProviderStatus.implemented   => (label: '実装済み',              color: Color(0xFF4CAF50)),
    ProviderStatus.needsApiKey   => (label: 'APIキー設定が必要',      color: Color(0xFFFFC107)),
    ProviderStatus.needsPayment  => (label: 'プロバイダーに課金が必要', color: Color(0xFF3D5AFE)),
    ProviderStatus.notImplemented=> (label: '未実装',                color: Color(0xFF707070)),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _statusConfig(provider.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Text(provider.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(provider.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(provider.description, style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 12)),
                  if (provider.model != null) ...[
                    const SizedBox(height: 4),
                    Text(provider.model!, style: const TextStyle(color: Color(0xFF707070), fontSize: 11, fontFamily: 'monospace')),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cfg.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: cfg.color.withValues(alpha: 0.4)),
                  ),
                  child: Text(cfg.label, style: TextStyle(color: cfg.color, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
                if (onTry != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: onTry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('試す'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── チャットボトムシート ───────────────────────────────────────────────────────

class _ChatMessage {
  final bool isUser;
  final String text;
  final DateTime time;

  _ChatMessage({required this.isUser, required this.text}) : time = DateTime.now();
}

class _ChatSheet extends StatefulWidget {
  final ProviderInfo provider;
  const _ChatSheet({required this.provider});

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _messages = <_ChatMessage>[];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _loading = false;

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: text));
      _loading = true;
    });
    _inputCtrl.clear();
    _scrollToBottom();

    try {
      final supabase = Supabase.instance.client;
      final resp = await supabase.functions.invoke(
        'ai-hub',
        body: {'action': 'provider.chat', 'provider': widget.provider.id, 'message': text},
      );

      final data = resp.data as Map<String, dynamic>?;
      final response = data?['response'] as String? ?? data?['error'] as String? ?? 'エラーが発生しました';
      setState(() => _messages.add(_ChatMessage(isUser: false, text: response)));
    } catch (e) {
      setState(() => _messages.add(_ChatMessage(isUser: false, text: 'エラー: $e')));
    } finally {
      setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ヘッダー
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                Text(widget.provider.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.provider.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    if (widget.provider.model != null)
                      Text(widget.provider.model!, style: const TextStyle(color: Color(0xFF707070), fontSize: 12)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF4CAF50).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4))),
                  child: const Text('実装済み', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 10, fontWeight: FontWeight.w600)),
                ),
                IconButton(icon: const Icon(Icons.close, color: Color(0xFFB0B0B0)), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 1),
          // メッセージリスト
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.provider.emoji, style: const TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text('${widget.provider.name} に話しかけてみましょう', style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('下のテキストボックスからメッセージを送信できます', style: TextStyle(color: Color(0xFF707070), fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _messages.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [SizedBox(width: 8), SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B35)))]),
                        );
                      }
                      final msg = _messages[i];
                      return _Bubble(message: msg);
                    },
                  ),
          ),
          // 入力エリア
          const Divider(color: Color(0xFF2A2A2A), height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    maxLines: null,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'メッセージを入力…',
                      hintStyle: const TextStyle(color: Color(0xFF707070)),
                      filled: true,
                      fillColor: const Color(0xFF2A2A2A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      disabledBackgroundColor: const Color(0xFF333333),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.zero,
                    ),
                    child: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── チャットバブル ─────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final _ChatMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: message.isUser ? const Color(0xFFFF6B35).withValues(alpha: 0.2) : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: message.isUser ? const Color(0xFFFF6B35).withValues(alpha: 0.4) : const Color(0xFF333333)),
        ),
        child: SelectableText(
          message.text,
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
        ),
      ),
    );
  }
}
