import 'dart:convert';
import 'dart:math' show Random;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web_api;
import '../services/ai_fsrs_service.dart';
import '../services/ai_learner_profile_service.dart';
import '../services/gamification_service.dart';
import '../services/theme_service.dart';
import 'ai_university_ranking_page.dart';
import 'api_playground_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// プロバイダーメタデータ
//
// DB (ai_university_content) に新プロバイダーの rows を追加するだけで
// UI に自動反映される。このマップへの追記は任意（未登録は汎用デフォルト表示）。
//
// セッション毎に新興AIプロバイダーを検討し必要に応じて追記する。
// 例: deepseek, mistral, cohere, perplexity, amazon, inflection, etc.
// ─────────────────────────────────────────────────────────────────────────────

class _ProviderMeta {
  _ProviderMeta({
    required this.name,
    required this.emoji,
    required this.color,
    required this.officialUrl,
  });
  final String name;
  final String emoji;
  final Color color;
  final String officialUrl;
}

final _unknownMeta = _ProviderMeta(
  name: 'AI',
  emoji: '🤖',
  color: const Color(0xFF607D8B),
  officialUrl: '',
);

// 既知プロバイダーの表示設定。DB に新しい provider が現れれば自動的にタブが増える。
// 表示名・絵文字・色・URL をカスタマイズしたい場合のみここに追加する。
final Map<String, _ProviderMeta> _providerMeta = {
  'google': _ProviderMeta(
    name: 'Google',
    emoji: '🔵',
    color: const Color(0xFF4285F4),
    officialUrl: 'https://ai.google.dev/',
  ),
  'openai': _ProviderMeta(
    name: 'OpenAI',
    emoji: '⚫',
    color: const Color(0xFF10A37F),
    officialUrl: 'https://platform.openai.com/',
  ),
  'anthropic': _ProviderMeta(
    name: 'Anthropic',
    emoji: '🟠',
    color: const Color(0xFFD4690E),
    officialUrl: 'https://docs.anthropic.com/',
  ),
  'microsoft': _ProviderMeta(
    name: 'Microsoft',
    emoji: '🔷',
    color: const Color(0xFF00A4EF),
    officialUrl: 'https://azure.microsoft.com/ja-jp/solutions/ai/',
  ),
  'meta': _ProviderMeta(
    name: 'Meta',
    emoji: '🟣',
    color: const Color(0xFF0866FF),
    officialUrl: 'https://ai.meta.com/',
  ),
  'x': _ProviderMeta(
    name: 'xAI',
    emoji: '⚡',
    color: const Color(0xFF1DA1F2),
    officialUrl: 'https://x.ai/',
  ),
  'deepseek': _ProviderMeta(
    name: 'DeepSeek',
    emoji: '🐋',
    color: const Color(0xFF4D6BFE),
    officialUrl: 'https://platform.deepseek.com/',
  ),
  'mistral': _ProviderMeta(
    name: 'Mistral',
    emoji: '💨',
    color: const Color(0xFFFF7000),
    officialUrl: 'https://docs.mistral.ai/',
  ),
  'cohere': _ProviderMeta(
    name: 'Cohere',
    emoji: '🏢',
    color: const Color(0xFF39B5F0),
    officialUrl: 'https://dashboard.cohere.com/',
  ),
  'core': _ProviderMeta(
    name: 'Core',
    emoji: '⚙️',
    color: const Color(0xFF00BFFF),
    officialUrl: 'https://www.coreweave.com/',
  ),
  'perplexity': _ProviderMeta(
    name: 'Perplexity',
    emoji: '🔍',
    color: const Color(0xFF20808D),
    officialUrl: 'https://docs.perplexity.ai/',
  ),
  'amazon': _ProviderMeta(
    name: 'Amazon',
    emoji: '🔶',
    color: const Color(0xFFFF9900),
    officialUrl: 'https://aws.amazon.com/jp/bedrock/',
  ),
  'groq': _ProviderMeta(
    name: 'Groq',
    emoji: '🔥',
    color: const Color(0xFFF55036),
    officialUrl: 'https://console.groq.com/',
  ),
  'stability': _ProviderMeta(
    name: 'Stability AI',
    emoji: '🎨',
    color: const Color(0xFF6C35DE),
    officialUrl: 'https://platform.stability.ai/',
  ),
  'huggingface': _ProviderMeta(
    name: 'Hugging Face',
    emoji: '🤗',
    color: const Color(0xFFFFD21E),
    officialUrl: 'https://huggingface.co/',
  ),
  'nvidia': _ProviderMeta(
    name: 'Nvidia',
    emoji: '🟢',
    color: const Color(0xFF76B900),
    officialUrl: 'https://build.nvidia.com/',
  ),
  'ibm': _ProviderMeta(
    name: 'IBM watsonx',
    emoji: '🔵',
    color: const Color(0xFF0F62FE),
    officialUrl: 'https://cloud.ibm.com/watsonx',
  ),
  'sakana': _ProviderMeta(
    name: 'Sakana AI',
    emoji: '🐟',
    color: const Color(0xFF00B4D8),
    officialUrl: 'https://huggingface.co/SakanaAI',
  ),
  'ai21': _ProviderMeta(
    name: 'AI21 Labs',
    emoji: '🧬',
    color: const Color(0xFF1E40AF),
    officialUrl: 'https://docs.ai21.com/',
  ),
  'aleph_alpha': _ProviderMeta(
    name: 'Aleph Alpha',
    emoji: '🇩🇪',
    color: const Color(0xFF4A90D9),
    officialUrl: 'https://docs.aleph-alpha.com/',
  ),
  'baidu': _ProviderMeta(
    name: 'Baidu ERNIE',
    emoji: '🔴',
    color: const Color(0xFF2932E1),
    officialUrl: 'https://cloud.baidu.com/',
  ),
  'elevenlabs': _ProviderMeta(
    name: 'ElevenLabs',
    emoji: '🎙️',
    color: const Color(0xFF1A1A1A),
    officialUrl: 'https://elevenlabs.io/docs',
  ),
  'fireworks_ai': _ProviderMeta(
    name: 'Fireworks AI',
    emoji: '🎆',
    color: const Color(0xFFFF6B00),
    officialUrl: 'https://docs.fireworks.ai/',
  ),
  'ideogram': _ProviderMeta(
    name: 'Ideogram AI',
    emoji: '🖼️',
    color: const Color(0xFF6B21A8),
    officialUrl: 'https://developer.ideogram.ai/',
  ),
  'ollama': _ProviderMeta(
    name: 'Ollama',
    emoji: '🦙',
    color: const Color(0xFF1A1A1A),
    officialUrl: 'https://ollama.com/',
  ),
  'openrouter': _ProviderMeta(
    name: 'OpenRouter',
    emoji: '🔀',
    color: const Color(0xFF6240C8),
    officialUrl: 'https://openrouter.ai/docs',
  ),
  'oracle': _ProviderMeta(
    name: 'Oracle',
    emoji: '🔴',
    color: const Color(0xFFC74634),
    officialUrl: 'https://www.oracle.com/artificial-intelligence/',
  ),
  'reka': _ProviderMeta(
    name: 'Reka',
    emoji: '⚡',
    color: const Color(0xFF6C47FF),
    officialUrl: 'https://docs.reka.ai/quick-start',
  ),
  'replicate': _ProviderMeta(
    name: 'Replicate',
    emoji: '🔄',
    color: const Color(0xFF0F0F0F),
    officialUrl: 'https://replicate.com/docs',
  ),
  'runway': _ProviderMeta(
    name: 'Runway',
    emoji: '🎬',
    color: const Color(0xFF0F0F0F),
    officialUrl: 'https://docs.runwayml.com/',
  ),
  'suno': _ProviderMeta(
    name: 'Suno AI',
    emoji: '🎵',
    color: const Color(0xFF1C1C2E),
    officialUrl: 'https://suno.com/',
  ),
  'together_ai': _ProviderMeta(
    name: 'Together AI',
    emoji: '🤝',
    color: const Color(0xFF0066CC),
    officialUrl: 'https://docs.together.ai/',
  ),
  'udio': _ProviderMeta(
    name: 'Udio',
    emoji: '🎸',
    color: const Color(0xFF9B59B6),
    officialUrl: 'https://www.udio.com/',
  ),
  'voyage': _ProviderMeta(
    name: 'Voyage AI',
    emoji: '⚓',
    color: const Color(0xFF0F4C81),
    officialUrl: 'https://docs.voyageai.com/',
  ),
  'writer': _ProviderMeta(
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
  'qwen': _ProviderMeta(
    name: 'Qwen (Alibaba)',
    emoji: '🌐',
    color: const Color(0xFFFF6A00),
    officialUrl: 'https://dashscope.aliyuncs.com',
  ),
  'moonshot': _ProviderMeta(
    name: 'Moonshot AI',
    emoji: '🌙',
    color: const Color(0xFF6366F1),
    officialUrl: 'https://www.moonshot.cn',
  ),
  'pika': _ProviderMeta(
    name: 'Pika Labs',
    emoji: '⚡',
    color: const Color(0xFF6C63FF),
    officialUrl: 'https://pika.art',
  ),
  'assemblyai': _ProviderMeta(
    name: 'AssemblyAI',
    emoji: '🎙️',
    color: const Color(0xFF00BFA5),
    officialUrl: 'https://www.assemblyai.com',
  ),
  'twelve_labs': _ProviderMeta(
    name: 'Twelve Labs',
    emoji: '🎞️',
    color: const Color(0xFF4A90D9),
    officialUrl: 'https://twelvelabs.io',
  ),
  'midjourney': _ProviderMeta(
    name: 'Midjourney',
    emoji: '🎨',
    color: const Color(0xFF000000),
    officialUrl: 'https://www.midjourney.com',
  ),
  'hailuo': _ProviderMeta(
    name: 'Hailuo AI',
    emoji: '🎬',
    color: const Color(0xFF0066FF),
    officialUrl: 'https://hailuoai.com',
  ),
  'adobe_firefly': _ProviderMeta(
    name: 'Adobe Firefly',
    emoji: '🔥',
    color: const Color(0xFFFF0000),
    officialUrl: 'https://firefly.adobe.com',
  ),
  '01ai': _ProviderMeta(
    name: '01.AI (Yi)',
    emoji: '🀄',
    color: const Color(0xFF1A73E8),
    officialUrl: 'https://www.01.ai',
  ),
  'coze': _ProviderMeta(
    name: 'Coze',
    emoji: '🤖',
    color: const Color(0xFF5B61FF),
    officialUrl: 'https://www.coze.com',
  ),
  'apple': _ProviderMeta(
    name: 'Apple Intelligence',
    emoji: '🍎',
    color: const Color(0xFF1D1D1F),
    officialUrl: 'https://apple.com/apple-intelligence',
  ),
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
  'databricks': _ProviderMeta(
    name: 'Databricks',
    emoji: '🧱',
    color: const Color(0xFFFF3621),
    officialUrl: 'https://www.databricks.com/product/machine-learning',
  ),
  'samsung': _ProviderMeta(
    name: 'Samsung Galaxy AI',
    emoji: '📱',
    color: const Color(0xFF1428A0),
    officialUrl: 'https://www.samsung.com/ai',
  ),
  'zhipu': _ProviderMeta(
    name: 'Zhipu AI (GLM)',
    emoji: '🔮',
    color: const Color(0xFF4E5FFF),
    officialUrl: 'https://www.zhipuai.cn',
  ),
  'character_ai': _ProviderMeta(
    name: 'Character.AI',
    emoji: '🎭',
    color: const Color(0xFF000000),
    officialUrl: 'https://character.ai',
  ),
  'inflection': _ProviderMeta(
    name: 'Inflection AI (Pi)',
    emoji: '💙',
    color: const Color(0xFF6B48FF),
    officialUrl: 'https://pi.ai',
  ),
  'adept': _ProviderMeta(
    name: 'Adept AI',
    emoji: '🖥️',
    color: const Color(0xFF2B5CE6),
    officialUrl: 'https://www.adept.ai/',
  ),
  'cerebras': _ProviderMeta(
    name: 'Cerebras',
    emoji: '⚡',
    color: const Color(0xFFFFD700),
    officialUrl: 'https://www.cerebras.ai/',
  ),
  'prover': _ProviderMeta(
    name: 'Prover',
    emoji: '🧮',
    color: const Color(0xFF9370DB),
    officialUrl: 'https://www.prover.io/',
  ),
  'lmsys': _ProviderMeta(
    name: 'LMSYS / Chatbot Arena',
    emoji: '🏆',
    color: const Color(0xFF1E40AF),
    officialUrl: 'https://lmsys.org/',
  ),
  'falcon_tii': _ProviderMeta(
    name: 'Falcon (TII)',
    emoji: '🦅',
    color: const Color(0xFF059669),
    officialUrl: 'https://falconllm.tii.ae/',
  ),
  'black_forest_labs': _ProviderMeta(
    name: 'Black Forest Labs (FLUX)',
    emoji: '🌲',
    color: const Color(0xFF111827),
    officialUrl: 'https://blackforestlabs.ai/',
  ),
  'liquid_ai': _ProviderMeta(
    name: 'Liquid AI',
    emoji: '💧',
    color: const Color(0xFF0EA5E9),
    officialUrl: 'https://liquid.ai/',
  ),
  'snowflake': _ProviderMeta(
    name: 'Snowflake AI',
    emoji: '❄️',
    color: const Color(0xFF29B5E8),
    officialUrl: 'https://www.snowflake.com/en/data-cloud/cortex/',
  ),
  'cognition': _ProviderMeta(
    name: 'Cognition AI (Devin)',
    emoji: '🤖',
    color: const Color(0xFF7C3AED),
    officialUrl: 'https://cognition.ai/',
  ),
  'scale_ai': _ProviderMeta(
    name: 'Scale AI',
    emoji: '⚖️',
    color: const Color(0xFF7C3AED),
    officialUrl: 'https://scale.com/',
  ),
  'poolside': _ProviderMeta(
    name: 'Poolside AI',
    emoji: '🏊',
    color: const Color(0xFF0F172A),
    officialUrl: 'https://poolside.ai/',
  ),
  'harvey': _ProviderMeta(
    name: 'Harvey AI',
    emoji: '⚖️',
    color: const Color(0xFF2C5282),
    officialUrl: 'https://www.harvey.ai/',
  ),
  'manus': _ProviderMeta(
    name: 'Manus AI',
    emoji: '🤖',
    color: const Color(0xFF553C9A),
    officialUrl: 'https://manus.im/',
  ),
  'hedra': _ProviderMeta(
    name: 'Hedra AI',
    emoji: '🎭',
    color: const Color(0xFF9C4DCC),
    officialUrl: 'https://www.hedra.com/',
  ),
  'heygen': _ProviderMeta(
    name: 'HeyGen',
    emoji: '🎬',
    color: const Color(0xFF1976D2),
    officialUrl: 'https://www.heygen.com/',
  ),
  'recraft': _ProviderMeta(
    name: 'Recraft',
    emoji: '🎨',
    color: const Color(0xFFE74C3C),
    officialUrl: 'https://www.recraft.ai/',
  ),
  'krea': _ProviderMeta(
    name: 'Krea',
    emoji: '⚡',
    color: const Color(0xFF7B68EE),
    officialUrl: 'https://www.krea.ai/',
  ),
  'tencent': _ProviderMeta(
    name: 'Tencent Hunyuan',
    emoji: '🐉',
    color: const Color(0xFF1E88E5),
    officialUrl: 'https://hunyuan.tencent.com/',
  ),
  'bytedance': _ProviderMeta(
    name: 'ByteDance Doubao',
    emoji: '🎵',
    color: const Color(0xFF6366F1),
    officialUrl: 'https://www.doubao.com/',
  ),
  'inception_labs': _ProviderMeta(
    name: 'Inception (Mercury)',
    emoji: '💨',
    color: const Color(0xFF00BFA5),
    officialUrl: 'https://www.inceptionlabs.ai/',
  ),
  'world_labs': _ProviderMeta(
    name: 'World Labs',
    emoji: '🌍',
    color: const Color(0xFF2E7D32),
    officialUrl: 'https://www.worldlabs.ai/',
  ),
  'runware': _ProviderMeta(
    name: 'Runware (Sonic)',
    emoji: '⚡',
    color: const Color(0xFF5E17EB),
    officialUrl: 'https://runware.ai/',
  ),
  'sambanova': _ProviderMeta(
    name: 'SambaNova',
    emoji: '🔴',
    color: const Color(0xFFE03E3E),
    officialUrl: 'https://sambanova.ai/',
  ),
  'lightricks': _ProviderMeta(
    name: 'Lightricks LTX-2',
    emoji: '🎬',
    color: const Color(0xFFFF4D6D),
    officialUrl: 'https://ltx.io/model/ltx-2',
  ),
  'arcee_ai': _ProviderMeta(
    name: 'Arcee AI Trinity',
    emoji: '🇺🇸',
    color: const Color(0xFF1E40AF),
    officialUrl: 'https://www.arcee.ai/trinity',
  ),
  'minimax': _ProviderMeta(
    name: 'MiniMax (Hailuo)',
    emoji: '🌊',
    color: const Color(0xFF00B4D8),
    officialUrl: 'https://www.minimax.io',
  ),
  'moondream': _ProviderMeta(
    name: 'Moondream VLM',
    emoji: '🌙',
    color: const Color(0xFF8B5CF6),
    officialUrl: 'https://moondream.ai/',
  ),
  'rakuten_ai': _ProviderMeta(
    name: 'Rakuten AI 3.0',
    emoji: '🎌',
    color: const Color(0xFFBF0000),
    officialUrl: 'https://huggingface.co/Rakuten',
  ),
  'pfn': _ProviderMeta(
    name: 'PFN (PLaMo)',
    emoji: '🗾',
    color: const Color(0xFF0BAF55),
    officialUrl: 'https://www.preferred.jp/en/business/genai',
  ),
  'siliconflow': _ProviderMeta(
    name: 'SiliconFlow',
    emoji: '🧪',
    color: const Color(0xFF6E56CF),
    officialUrl: 'https://siliconflow.cn/',
  ),
  'novita_ai': _ProviderMeta(
    name: 'Novita AI',
    emoji: '🎨',
    color: const Color(0xFF00B5C7),
    officialUrl: 'https://novita.ai/',
  ),
  'deepinfra': _ProviderMeta(
    name: 'DeepInfra',
    emoji: '⚡',
    color: const Color(0xFF6B3FFF),
    officialUrl: 'https://deepinfra.com/',
  ),
  'nebius': _ProviderMeta(
    name: 'Nebius AI Studio',
    emoji: '🌐',
    color: const Color(0xFF0052CC),
    officialUrl: 'https://nebius.com/ai-studio',
  ),
  'fal_ai': _ProviderMeta(
    name: 'fal.ai',
    emoji: '🎬',
    color: const Color(0xFFFF4D6D),
    officialUrl: 'https://fal.ai/',
  ),
  'fish_audio': _ProviderMeta(
    name: 'Fish Audio',
    emoji: '🐟',
    color: const Color(0xFF1E88E5),
    officialUrl: 'https://fish.audio/',
  ),
  'atlas_cloud': _ProviderMeta(
    name: 'Atlas Cloud',
    emoji: '🗺️',
    color: const Color(0xFF1976D2),
    officialUrl: 'https://www.atlascloud.ai/',
  ),
  'mira_network': _ProviderMeta(
    name: 'Mira Network',
    emoji: '🔗',
    color: const Color(0xFF8E44AD),
    officialUrl: 'https://docs.mira.network/',
  ),
  'gmi_cloud': _ProviderMeta(
    name: 'GMI Cloud',
    emoji: '⚡',
    color: const Color(0xFF76B900),
    officialUrl: 'https://www.gmicloud.ai/',
  ),
  'inworld': _ProviderMeta(
    name: 'Inworld AI',
    emoji: '🎮',
    color: const Color(0xFF9B59B6),
    officialUrl: 'https://inworld.ai/',
  ),
  'coreweave': _ProviderMeta(
    name: 'CoreWeave',
    emoji: '🏭',
    color: const Color(0xFFFF6B35),
    officialUrl: 'https://www.coreweave.com/',
  ),
  'lambda_labs': _ProviderMeta(
    name: 'Lambda Labs',
    emoji: 'λ',
    color: const Color(0xFF7C3AED),
    officialUrl: 'https://lambda.ai/',
  ),
  'hyperbolic': _ProviderMeta(
    name: 'Hyperbolic Labs',
    emoji: '🌐',
    color: const Color(0xFF10B981),
    officialUrl: 'https://www.hyperbolic.ai/',
  ),
  'anyscale': _ProviderMeta(
    name: 'Anyscale',
    emoji: '🚂',
    color: const Color(0xFF3B82F6),
    officialUrl: 'https://www.anyscale.com/',
  ),
  'cerebrium': _ProviderMeta(
    name: 'Cerebrium',
    emoji: '⚡',
    color: const Color(0xFFEAB308),
    officialUrl: 'https://www.cerebrium.ai/',
  ),
  'magic_ai': _ProviderMeta(
    name: 'Magic AI',
    emoji: '🪄',
    color: const Color(0xFFEC4899),
    officialUrl: 'https://magic.dev/',
  ),
  'jina_ai': _ProviderMeta(
    name: 'Jina AI',
    emoji: '🔍',
    color: const Color(0xFF10B981),
    officialUrl: 'https://jina.ai/',
  ),
  'stepfun': _ProviderMeta(
    name: 'StepFun (阶跃星辰)',
    emoji: '🚀',
    color: const Color(0xFF6366F1),
    officialUrl: 'https://www.stepfun.com/',
  ),
  'modular': _ProviderMeta(
    name: 'Modular',
    emoji: '⚡',
    color: const Color(0xFFF59E0B),
    officialUrl: 'https://www.modular.com/',
  ),
  'radixark': _ProviderMeta(
    name: 'RadixArk (SGLang)',
    emoji: '🌐',
    color: const Color(0xFF0EA5E9),
    officialUrl: 'https://github.com/sgl-project/sglang',
  ),
  'baseten': _ProviderMeta(
    name: 'Baseten',
    emoji: '🏗️',
    color: const Color(0xFF7C3AED),
    officialUrl: 'https://www.baseten.co/',
  ),
  'baichuan': _ProviderMeta(
    name: 'Baichuan AI (百川智能)',
    emoji: '🏥',
    color: const Color(0xFF059669),
    officialUrl: 'https://www.baichuan-ai.com/',
  ),
  'lepton': _ProviderMeta(
    name: 'Lepton AI (NVIDIA)',
    emoji: '⚡',
    color: const Color(0xFF76B900),
    officialUrl: 'https://www.lepton.ai/',
  ),
  'krutrim': _ProviderMeta(
    name: 'Krutrim AI',
    emoji: '🇮🇳',
    color: const Color(0xFFFF9933),
    officialUrl: 'https://cloud.olakrutrim.com/',
  ),
  'deepgram': _ProviderMeta(
    name: 'Deepgram',
    emoji: '🎙️',
    color: const Color(0xFF00B4D8),
    officialUrl: 'https://deepgram.com/',
  ),
  'did': _ProviderMeta(
    name: 'D-ID',
    emoji: '🎬',
    color: const Color(0xFF7B2FBE),
    officialUrl: 'https://www.d-id.com/',
  ),
  'cartesia': _ProviderMeta(
    name: 'Cartesia AI',
    emoji: '🔊',
    color: const Color(0xFF4F46E5),
    officialUrl: 'https://cartesia.ai/',
  ),
  'tavus': _ProviderMeta(
    name: 'Tavus',
    emoji: '🎥',
    color: const Color(0xFF059669),
    officialUrl: 'https://www.tavus.io/',
  ),
  'synthesia': _ProviderMeta(
    name: 'Synthesia',
    emoji: '🧑‍💼',
    color: const Color(0xFF0EA5E9),
    officialUrl: 'https://www.synthesia.io/',
  ),
  'play_ht': _ProviderMeta(
    name: 'PlayHT',
    emoji: '🔉',
    color: const Color(0xFFEF4444),
    officialUrl: 'https://play.ht/',
  ),
  'descript': _ProviderMeta(
    name: 'Descript',
    emoji: '✂️',
    color: const Color(0xFF8B5CF6),
    officialUrl: 'https://www.descript.com/',
  ),
  'wandb': _ProviderMeta(
    name: 'Weights & Biases',
    emoji: '📊',
    color: const Color(0xFFFBBF24),
    officialUrl: 'https://wandb.ai/',
  ),
  'modal': _ProviderMeta(
    name: 'Modal Labs',
    emoji: '⚡',
    color: const Color(0xFF6366F1),
    officialUrl: 'https://modal.com/',
  ),
  'pinecone': _ProviderMeta(
    name: 'Pinecone',
    emoji: '🌲',
    color: const Color(0xFF10B981),
    officialUrl: 'https://www.pinecone.io/',
  ),
  'langchain': _ProviderMeta(
    name: 'LangChain',
    emoji: '🔗',
    color: const Color(0xFF1C7C54),
    officialUrl: 'https://www.langchain.com/',
  ),
  'llamaindex': _ProviderMeta(
    name: 'LlamaIndex',
    emoji: '🦙',
    color: const Color(0xFF7C3AED),
    officialUrl: 'https://www.llamaindex.ai/',
  ),
  'qdrant': _ProviderMeta(
    name: 'Qdrant',
    emoji: '🎯',
    color: const Color(0xFFDC143C),
    officialUrl: 'https://qdrant.tech/',
  ),
  'roboflow': _ProviderMeta(
    name: 'Roboflow',
    emoji: '👁️',
    color: const Color(0xFF6706CE),
    officialUrl: 'https://roboflow.com/',
  ),
  'lightning_ai': _ProviderMeta(
    name: 'Lightning AI',
    emoji: '⚡',
    color: const Color(0xFF792EE5),
    officialUrl: 'https://lightning.ai/',
  ),
  'weave': _ProviderMeta(
    name: 'W&B Weave',
    emoji: '🧵',
    color: const Color(0xFFFCB833),
    officialUrl: 'https://weave.wandb.ai/',
  ),
  'oxen_ai': _ProviderMeta(
    name: 'Oxen AI',
    emoji: '🐂',
    color: const Color(0xFF8B4513),
    officialUrl: 'https://oxen.ai/',
  ),
  'predibase': _ProviderMeta(
    name: 'Predibase',
    emoji: '🔧',
    color: const Color(0xFF4F46E5),
    officialUrl: 'https://predibase.com/',
  ),
  'argilla': _ProviderMeta(
    name: 'Argilla',
    emoji: '📝',
    color: const Color(0xFF059669),
    officialUrl: 'https://argilla.io/',
  ),
  'dify': _ProviderMeta(
    name: 'Dify',
    emoji: '🔮',
    color: const Color(0xFF2563EB),
    officialUrl: 'https://dify.ai/',
  ),
  'decart': _ProviderMeta(
    name: 'Decart',
    emoji: '🎮',
    color: const Color(0xFF7C3AED),
    officialUrl: 'https://decart.ai/',
  ),
  'goodfire': _ProviderMeta(
    name: 'Goodfire',
    emoji: '🔬',
    color: const Color(0xFFEA580C),
    officialUrl: 'https://www.goodfire.ai/',
  ),
  'nous_research': _ProviderMeta(
    name: 'Nous Research',
    emoji: '🌐',
    color: const Color(0xFF0EA5E9),
    officialUrl: 'https://nousresearch.com/',
  ),
  'prime_intellect': _ProviderMeta(
    name: 'Prime Intellect',
    emoji: '🧠',
    color: const Color(0xFF1E40AF),
    officialUrl: 'https://www.primeintellect.ai/',
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// クイズデータ（プロバイダー別、DB コンテンツとは独立）
// ─────────────────────────────────────────────────────────────────────────────

class _Quiz {
  _Quiz({required this.question, required this.options, required this.correct});
  final String question;
  final List<String> options;
  final int correct;
}

final Map<String, _Quiz> _quizzes = {
  'google': _Quiz(
    question: 'Gemini 2.5 シリーズの最大入力コンテキスト長は？',
    options: ['128K', '256K', '1M', '2M'],
    correct: 2,
  ),
  'openai': _Quiz(
    question: 'OpenAI o1/o3 シリーズの特徴として正しいのは？',
    options: ['高速低コスト', '推論前の thinking ステップ', '画像生成特化', 'リアルタイム検索'],
    correct: 1,
  ),
  'anthropic': _Quiz(
    question: 'Anthropic が提唱する「Constitutional AI」の目的は？',
    options: ['高速化', '安全で有害性の低い応答の実現', '長文生成', '低コスト化'],
    correct: 1,
  ),
  'microsoft': _Quiz(
    question: 'Microsoft Copilot が統合されている主なサービスは？',
    options: ['Google Workspace', 'Microsoft 365 / Azure', 'AWS', 'Slack'],
    correct: 1,
  ),
  'meta': _Quiz(
    question: 'Meta の LLaMA モデルが注目される最大の理由は？',
    options: ['クローズドソース', 'オープンソース公開・商用利用可', '音声特化', '最安値API'],
    correct: 1,
  ),
  'x': _Quiz(
    question: 'xAI Grok の特徴として正しいのは？',
    options: ['オフライン専用', 'X(Twitter)リアルタイム情報へのアクセス', '画像専用', '翻訳特化'],
    correct: 1,
  ),
  'deepseek': _Quiz(
    question: 'DeepSeek R1 が注目される理由として正しいのは？',
    options: ['Google が開発', '低コストで高性能な推論モデル・OSS公開', '音声合成特化', '画像生成のみ'],
    correct: 1,
  ),
  'mistral': _Quiz(
    question: 'Mistral AI の本拠地はどこ？',
    options: ['米国', 'フランス', '英国', '日本'],
    correct: 1,
  ),
  'perplexity': _Quiz(
    question: 'Perplexity AI の主な特徴は？',
    options: ['画像生成', 'リアルタイム検索+引用付き回答', '音声合成', 'コード専用'],
    correct: 1,
  ),
  'groq': _Quiz(
    question: 'Groq が開発した独自 AI チップの名称は？',
    options: ['LPU', 'TPU', 'GPU', 'NPU'],
    correct: 0,
  ),
  'cohere': _Quiz(
    question: 'Cohere の RAG パイプラインで検索結果の精度を向上させるモデルは？',
    options: ['Rerank', 'Embed', 'Command R', 'Aya'],
    correct: 0,
  ),
  'amazon': _Quiz(
    question: 'Amazon Bedrock の Converse API の主な利点は何ですか？',
    options: ['全モデルを統一インターフェースで利用可能', '最高速度の推論', '最低コストの利用', '日本語専用最適化'],
    correct: 0,
  ),
  'stability': _Quiz(
    question: 'Stable Diffusion を開発した企業はどこですか？',
    options: ['Stability AI', 'OpenAI', 'Midjourney', 'Adobe'],
    correct: 0,
  ),
  'huggingface': _Quiz(
    question: 'Hugging Face Hub に登録されているモデル数はおよそ何個ですか？',
    options: ['100万以上', '1万以上', '10万以上', '1000以上'],
    correct: 0,
  ),
  'nvidia': _Quiz(
    question: 'NVIDIA NIM の API は何の API と互換性がありますか？',
    options: ['OpenAI API', 'Anthropic API', 'Gemini API', '独自 API'],
    correct: 0,
  ),
  'ibm': _Quiz(
    question: 'IBM Granite モデルのオープンソースライセンスは？',
    options: ['Apache 2.0', 'MIT', 'GPL v3', 'CC BY-NC'],
    correct: 0,
  ),
  'sakana': _Quiz(
    question: 'Sakana AI が開発した独自のモデル作成手法は？',
    options: ['進化的モデルマージング', 'LoRA ファインチューニング', 'RLHF', '知識蒸留'],
    correct: 0,
  ),
  'ai21': _Quiz(
    question: 'Jamba のアーキテクチャが革新的な理由は何ですか？',
    options: [
      'SSM と Transformer を融合しO(n)の線形計算量で長文処理',
      '世界最大のパラメータ数',
      '画像生成に特化した設計',
      '量子コンピュータを活用',
    ],
    correct: 0,
  ),
  'aleph_alpha': _Quiz(
    question: 'Aleph Alpha が開発した「説明可能AI」技術の名称は？',
    options: ['AtMan', 'SHAP', 'LIME', 'Grad-CAM'],
    correct: 0,
  ),
  'baidu': _Quiz(
    question: 'Baidu の AI チャットサービス ERNIE Bot の中国語名は？',
    options: ['文心一言', '通义千问', '讯飞星火', '混元'],
    correct: 0,
  ),
  'elevenlabs': _Quiz(
    question: 'ElevenLabs の Eleven Turbo v2.5 の主な特徴は？',
    options: [
      '低レイテンシ (<250ms) でリアルタイムAI音声に最適',
      '最高音質の有声本生成専用',
      '音声認識特化',
      '画像から音声生成',
    ],
    correct: 0,
  ),
  'fireworks_ai': _Quiz(
    question: 'Fireworks AI が特に強みとする点は？',
    options: ['業界最高水準の推論速度 (150+ tokens/秒)', '最多モデル数', '最安値料金', '独自LLM'],
    correct: 0,
  ),
  'ideogram': _Quiz(
    question: 'Ideogram AI が他の画像生成AIと比べて特に優れている点は？',
    options: [
      '画像内のテキスト (文字) を正確に生成できる',
      '動画から静止画を抽出',
      'リアルタイム画像ストリーミング',
      '音声から画像を生成',
    ],
    correct: 0,
  ),
  'ollama': _Quiz(
    question: 'Ollama の最大のメリットは？',
    options: [
      'データが外部送信されず完全ローカル実行 → プライバシー保護 + API料金ゼロ',
      'クラウドで最新GPT-4より高精度',
      'リアルタイムWeb検索',
      '1秒以内の超高速レスポンス保証',
    ],
    correct: 0,
  ),
  'openrouter': _Quiz(
    question: 'OpenRouter の API は既存のどの SDK と互換性がある？',
    options: [
      'OpenAI SDK (base_url変更のみ)',
      'LangChain専用SDK',
      'Anthropic SDKのみ',
      '独自SDK',
    ],
    correct: 0,
  ),
  'oracle': _Quiz(
    question: 'Oracle Database 23ai でベクトル検索を実行する際に使う関数は？',
    options: [
      'VECTOR_DISTANCE()',
      'COSINE_SEARCH()',
      'AI_SEARCH()',
      'EMBED_QUERY()',
    ],
    correct: 0,
  ),
  'reka': _Quiz(
    question: 'Reka のモデルが他の主要 LLM と大きく異なるマルチモーダル能力とは？',
    options: ['動画ファイルを直接入力して理解できる', 'リアルタイム音声合成', '3Dモデル生成', 'オンライン学習'],
    correct: 0,
  ),
  'replicate': _Quiz(
    question: 'Replicate で自分のカスタムモデルをデプロイするツールは？',
    options: ['cog', 'docker-compose', 'kubectl', 'terraform'],
    correct: 0,
  ),
  'runway': _Quiz(
    question: 'Runway Gen-3 Alpha の最大動画生成時間は？',
    options: ['最大10秒 (4K解像度)', '最大60秒 (1080p)', '最大5秒 (720p)', '無制限'],
    correct: 0,
  ),
  'suno': _Quiz(
    question: 'Suno AI で生成される楽曲に含まれるものは？',
    options: ['ボーカル・伴奏・ミックス・マスタリングが全て含まれる完全楽曲', 'MIDIデータのみ', '歌詞と楽譜のみ', '伴奏のみ'],
    correct: 0,
  ),
  'together_ai': _Quiz(
    question: 'Together AI の主な特徴として正しいものは？',
    options: ['200以上のOSSモデルをひとつのAPIで提供', '独自クローズドモデルのみ', 'テキスト生成のみ', '日本語専用'],
    correct: 0,
  ),
  'udio': _Quiz(
    question: 'Udio が Suno より優れているとされる領域は？',
    options: [
      'インストゥルメンタル生成と音楽理論の精度',
      '日本語ボーカルの自然さ',
      '短い楽曲の高速生成',
      '無料プランでの生成曲数',
    ],
    correct: 0,
  ),
  'voyage': _Quiz(
    question: 'Voyage AI の Reranker を RAG パイプラインに組み込む目的は？',
    options: [
      'ベクトル検索の上位N件を精密に再スコアリングしてRAG精度向上',
      'テキストを圧縮してコスト削減',
      'クエリを自動翻訳',
      'DB検索速度向上',
    ],
    correct: 0,
  ),
  'writer': _Quiz(
    question: 'Writer の Palmyra Med / Palmyra Fin はどのような特化モデルですか？',
    options: ['医療・金融ドメインに特化したビジネス文書生成モデル', '音声認識専用', '画像生成専用', 'コード生成専用'],
    correct: 0,
  ),
  'luma': _Quiz(
    question: 'Luma AI Dream Machine の最大の特徴は？',
    options: [
      '3D空間を理解した動画生成 (物体の奥行き・動きを正確にレンダリング)',
      '音声から動画を生成',
      '静止画の解像度向上',
      'テキスト文書の要約',
    ],
    correct: 0,
  ),
  'kling': _Quiz(
    question: 'Kling AI が生成できる動画の最大長は？',
    options: ['最大3分 (180秒)', '最大10秒', '最大60秒', '最大30秒'],
    correct: 0,
  ),
  'qwen': _Quiz(
    question: 'Alibaba Cloud の Qwen2.5-72B の特徴として正しいのは？',
    options: ['クローズドソースのみ', 'OpenAIのみ互換', 'HuggingFaceで公開・29言語対応', '音声生成特化'],
    correct: 2,
  ),
  'moonshot': _Quiz(
    question: 'Moonshot AI (Kimi) の最大コンテキスト長は？',
    options: ['8K', '32K', '128K', '4K'],
    correct: 2,
  ),
  'pika': _Quiz(
    question: 'Pika Labs の動画生成コストとして知られる金額は？',
    options: [r'$0.03/生成', r'$0.30/生成', r'$3.00/生成', r'$0.003/生成'],
    correct: 0,
  ),
  'assemblyai': _Quiz(
    question: 'AssemblyAI の LeMUR が使うデフォルト LLM は？',
    options: ['Claude (Anthropic)', 'GPT-4', 'Gemini', 'Llama'],
    correct: 0,
  ),
  'twelve_labs': _Quiz(
    question: 'Twelve Labs の動画理解エンジンの名前は？',
    options: ['Marengo', 'Pegasus', 'Apollo', 'Titan'],
    correct: 0,
  ),
  'midjourney': _Quiz(
    question: 'Midjourney が主に利用するプラットフォームはどれですか？',
    options: ['Discord', 'Slack', 'Twitter', 'Reddit'],
    correct: 0,
  ),
  'hailuo': _Quiz(
    question: 'Hailuo AI (MiniMax) の LLM が対応する最大コンテキスト長は？',
    options: ['100万トークン', '20万トークン', '32Kトークン', '128Kトークン'],
    correct: 0,
  ),
  'adobe_firefly': _Quiz(
    question: 'Adobe Firefly の最大の差別化ポイントは何ですか？',
    options: ['商業利用安全な学習データ', '最高の画質', '無料で使える', '最速の生成速度'],
    correct: 0,
  ),
  '01ai': _Quiz(
    question: '01.AI を創業した著名人は誰ですか？',
    options: [
      '李開復 (Kai-Fu Lee)',
      '李飛飛 (Fei-Fei Li)',
      'Andrew Ng',
      'Yann LeCun',
    ],
    correct: 0,
  ),
  'coze': _Quiz(
    question: 'Coze を開発した企業はどこですか？',
    options: ['ByteDance', 'Alibaba', 'Tencent', 'Baidu'],
    correct: 0,
  ),
  'apple': _Quiz(
    question: 'Apple Intelligence のプライバシー保護技術の名称は？',
    options: [
      'Private Cloud Compute',
      'Secure Enclave AI',
      'Neural Guard',
      'On-Device Shield',
    ],
    correct: 0,
  ),
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
  'databricks': _Quiz(
    question: 'Databricks の LLM DBRX のアーキテクチャは？',
    options: ['MoE (Mixture of Experts)', 'Dense Transformer', 'CNN', 'RNN'],
    correct: 0,
  ),
  'samsung': _Quiz(
    question: 'Samsung Galaxy AI で搭載されているオンデバイスモデルは？',
    options: ['Gemini Nano', 'GPT-4o mini', 'Claude Haiku', 'Llama 3'],
    correct: 0,
  ),
  'zhipu': _Quiz(
    question: 'Zhipu AI (GLM-4) の最大コンテキスト長は？',
    options: ['128K', '32K', '8K', '64K'],
    correct: 0,
  ),
  'character_ai': _Quiz(
    question: 'Character.AI の月間アクティブユーザー数は？',
    options: ['1.5億人', '1,000万人', '5,000万人', '3億人'],
    correct: 0,
  ),
  'inflection': _Quiz(
    question: 'Inflection AI の Pi が最も特化している領域は？',
    options: ['感情的知性・共感的対話', '数学・推論', 'コード生成', '画像生成'],
    correct: 0,
  ),
  'adept': _Quiz(
    question: 'Adept AI の ACT-1 / ACT-2 が得意とする領域は？',
    options: ['ブラウザや業務ソフトの操作自動化', '画像生成', '音声合成', '半導体設計'],
    correct: 0,
  ),
  'prover': _Quiz(
    question: 'Prover が特化している領域として正しいのは？',
    options: ['定理証明・形式検証・数学的正確性保証', '画像生成', 'リアルタイムWeb検索', '音声合成'],
    correct: 0,
  ),
  'lmsys': _Quiz(
    question: 'LMSYS の Chatbot Arena が採用しているモデル評価方式は？',
    options: ['自動スコアリング', 'Elo レーティング (人間ブラインド比較)', 'MMLU ベンチマーク', 'API コスト比較'],
    correct: 1,
  ),
  'falcon_tii': _Quiz(
    question: 'Falcon LLM を開発した TII の所在国は？',
    options: ['米国', '英国', 'UAE（アラブ首長国連邦）', 'ドイツ'],
    correct: 2,
  ),
  'black_forest_labs': _Quiz(
    question: 'Black Forest Labs が開発した画像生成モデルシリーズは？',
    options: ['DALL-E', 'Midjourney', 'FLUX', 'Stable Diffusion XL'],
    correct: 2,
  ),
  'liquid_ai': _Quiz(
    question: 'Liquid AI の LFM（Liquid Foundation Models）の特徴として正しいのは？',
    options: [
      'Transformer アーキテクチャ踏襲',
      '液体状態機械ベースの新アーキテクチャ',
      'GPT-4 のファインチューニング',
      '画像専用モデル',
    ],
    correct: 1,
  ),
  'snowflake': _Quiz(
    question: 'Snowflake Cortex AI の主な特徴は？',
    options: ['画像生成特化', 'SNS 投稿自動化', 'データウェアハウスと密接に統合されたエンタープライズ AI', 'ゲーム AI'],
    correct: 2,
  ),
  'cognition': _Quiz(
    question: 'Cognition AI の代表製品「Devin」の特徴は？',
    options: [
      'テキスト翻訳 AI',
      '自律的に GitHub Issue から PR まで完結させる AI ソフトウェアエンジニア',
      '音楽生成 AI',
      '画像編集 AI',
    ],
    correct: 1,
  ),
  'scale_ai': _Quiz(
    question: 'Scale AI が主に提供するサービスは？',
    options: [
      'クラウドホスティング',
      'AI モデル訓練用の高品質データ収集・アノテーション',
      'SNS プラットフォーム',
      '量子コンピューティング',
    ],
    correct: 1,
  ),
  'poolside': _Quiz(
    question: 'Poolside AI が特化しているドメインは？',
    options: ['医療診断', '金融予測', 'ソフトウェアエンジニアリング（コーディング）', '音楽生成'],
    correct: 2,
  ),
  'harvey': _Quiz(
    question: 'Harvey AI が最も強みを持つ分野はどれですか？',
    options: ['ゲーム開発', '法律・リーガルサービス', '医療診断', '動画生成'],
    correct: 1,
  ),
  'manus': _Quiz(
    question: 'Manus AI の最大の特徴は何ですか？',
    options: ['画像生成の高品質さ', 'コード補完の速さ', '複雑タスクの自律実行', '音声合成の自然さ'],
    correct: 2,
  ),
  'hedra': _Quiz(
    question: 'Hedra AI の Character-3 の最大の特徴は何ですか？',
    options: ['高解像度画像生成', '音声・画像・テキストを同時処理するオムニモーダルAI', '最安値の動画生成', '最多言語対応'],
    correct: 1,
  ),
  'heygen': _Quiz(
    question: 'HeyGen が対応している言語数はどのくらいですか？',
    options: ['30言語', '50言語', '100言語', '175言語'],
    correct: 3,
  ),
  'recraft': _Quiz(
    question: 'Recraft V4 が他の画像生成モデルと決定的に差別化している要素は？',
    options: ['高速推論', '編集可能なSVGベクター生成', 'ゼロショット翻訳', '3Dメッシュ生成'],
    correct: 1,
  ),
  'krea': _Quiz(
    question: 'Krea AI のリアルタイム画像生成の応答速度は？',
    options: ['約1秒', '約500ms', '約50ms以下', '約10秒'],
    correct: 2,
  ),
  'tencent': _Quiz(
    question: 'Tencent Hunyuan-Large のコンテキスト長は？',
    options: ['32K', '128K', '256K', '1M'],
    correct: 2,
  ),
  'bytedance': _Quiz(
    question: 'ByteDance Seed 2.0 が採用する主要設計コンセプトは？',
    options: ['超大規模パラメータ', 'Agent Era (自律タスク実行)', 'マルチランゲージ特化', '長コンテキスト'],
    correct: 1,
  ),
  'inception_labs': _Quiz(
    question: 'Inception Labs の Mercury が採用する革新的な LLM アーキテクチャは？',
    options: [
      'Autoregressive Transformer',
      'Diffusion LLM (dLLM)',
      'Mixture of Experts',
      'State Space Model',
    ],
    correct: 1,
  ),
  'world_labs': _Quiz(
    question: 'World Labs を創業した「AIの母」と呼ばれる研究者は？',
    options: ['Geoffrey Hinton', 'Yann LeCun', 'Fei-Fei Li', 'Andrew Ng'],
    correct: 2,
  ),
  'runware': _Quiz(
    question: 'Runware の中核技術 Sonic Inference Engine の強みは?',
    options: ['最大コンテキスト長', 'GPU不要CPU推論', '既存比30-40%高速・5-10倍安', '完全無料'],
    correct: 2,
  ),
  'sambanova': _Quiz(
    question: 'SambaNova の独自チップ設計思想は？',
    options: ['GPU', 'TPU', 'RDU (Reconfigurable Dataflow Unit)', 'NPU'],
    correct: 2,
  ),
  'lightricks': _Quiz(
    question: 'Lightricks LTX-2 が業界で唯一ネイティブ対応する機能は?',
    options: ['4Kだけ', '音声+映像 同時生成', '無制限長動画', 'リアルタイム3D'],
    correct: 1,
  ),
  'arcee_ai': _Quiz(
    question: 'Arcee AI Trinity シリーズのライセンスと出身国は?',
    options: [
      'MIT / 中国',
      'Apache 2.0 / 米国',
      'GPL / 英国',
      'Proprietary / カナダ',
    ],
    correct: 1,
  ),
  'minimax': _Quiz(
    question: 'MiniMax の 2026年1月の主要イベントは?',
    options: ['創業', '香港証券取引所 IPO', 'ナスダック上場', '倒産'],
    correct: 1,
  ),
  'moondream': _Quiz(
    question: 'Moondream 3 のアーキテクチャと画像1枚あたりのトークン数は?',
    options: [
      'Dense 1.8B / 512 tokens',
      'MoE 9B(2B active) / 729 tokens',
      'Transformer 70B / 1024 tokens',
      'CNN 500M / 256 tokens',
    ],
    correct: 1,
  ),
  'rakuten_ai': _Quiz(
    question: 'Rakuten AI 3.0 のパラメータ数・ライセンス・プロジェクトは?',
    options: [
      '70B / MIT / Llama派生',
      '700B MoE / Apache 2.0 / GENIAC',
      '8B / GPL / 独自',
      '100B / Proprietary / 楽天独自',
    ],
    correct: 1,
  ),
  'pfn': _Quiz(
    question: 'Preferred Networks の日本製 LLM ブランド名と独自 AI チップは?',
    options: [
      'Tunnel / A100',
      'PLaMo / MN-Core',
      'Chainer / TPU',
      'Sakana / Groq',
    ],
    correct: 1,
  ),
  'siliconflow': _Quiz(
    question: 'SiliconFlow の特徴的な提供サービスは?',
    options: [
      'クローズド独自モデル専用 API',
      'OpenAI 互換 API でオープンソースモデル多数をホスティング',
      'GPU レンタル単機能のみ',
      '画像生成専用クラウド',
    ],
    correct: 1,
  ),
  'novita_ai': _Quiz(
    question: 'Novita AI が強みとするモダリティは?',
    options: [
      'テキスト LLM 単独',
      '画像・動画・音声を含むマルチモーダル GPU 推論クラウド',
      'コードのみ',
      '音楽生成専用',
    ],
    correct: 1,
  ),
  'fal_ai': _Quiz(
    question: 'fal.ai が統一 API でホストしている代表的な動画生成モデルは?',
    options: [
      'Gemini Veo 3 のみ',
      'Seedance 2.0 / SVD-XT / Stable Video',
      'Sora 単独',
      'Runway Gen-3 単独',
    ],
    correct: 1,
  ),
  'fish_audio': _Quiz(
    question: 'Fish Audio のオープンソース TTS モデル名は?',
    options: [
      'Whisper Voice',
      'Fish Speech S1',
      'Bark Tiny',
      'XTTS-v3',
    ],
    correct: 1,
  ),
  'atlas_cloud': _Quiz(
    question: 'Atlas Cloud の独自性は?',
    options: [
      'テキスト LLM 専用',
      '世界初のフルモーダル inference platform (chat/画像/音声/動画 統合 OpenAI 互換)',
      '画像生成のみ',
      'ブロックチェーン専業',
    ],
    correct: 1,
  ),
  'mira_network': _Quiz(
    question: 'Mira Network が解決する主要問題は?',
    options: [
      'GPU 不足',
      'AI 出力の信頼性 (hallucination) を分散検証で保証',
      'モデルの ファインチューニング コスト',
      'TTS の音声品質',
    ],
    correct: 1,
  ),
  'gmi_cloud': _Quiz(
    question: 'GMI Cloud が採用する低レイテンシ inference の中核技術は?',
    options: [
      'CPU のみ推論',
      'NVIDIA TensorRT-LLM + vLLM + FP8 量子化',
      'WebAssembly',
      'Bitcoin マイニング',
    ],
    correct: 1,
  ),
  'inworld': _Quiz(
    question: 'Inworld Router の特徴として正しいものは?',
    options: [
      '単一プロバイダーのみ対応',
      'OpenAI/Anthropic/Google など複数モデルを 1 つの OpenAI 互換 API で統合・自動フォールバック',
      'GPU 販売のみ',
      '画像生成専用',
    ],
    correct: 1,
  ),
  'coreweave': _Quiz(
    question: 'CoreWeave の主要顧客として該当するのは?',
    options: [
      'Netflix のみ',
      'OpenAI / Meta / Perplexity 等 Tier 1 AI 企業',
      'ゲーム会社のみ',
      '個人開発者のみ',
    ],
    correct: 1,
  ),
  'lambda_labs': _Quiz(
    question: 'Lambda Labs Inference API の今後の方針として正しいのは?',
    options: [
      '更なる拡張が決定',
      'wind-down (段階的廃止) 方針・今後は GPU 直接賃貸に集中',
      '料金 10 倍に値上げ',
      '完全クローズドβ化',
    ],
    correct: 1,
  ),
  'hyperbolic': _Quiz(
    question: 'Hyperbolic Labs の差別化ポイントとして正しいのは?',
    options: [
      '中央集権 GPU クラウド',
      '分散 GPU + zk-snarks による検証可能 AI 推論',
      '画像生成専用',
      'CPU のみ',
    ],
    correct: 1,
  ),
  'anyscale': _Quiz(
    question: 'Anyscale が商用化している OSS フレームワークは?',
    options: [
      'TensorFlow',
      'Ray.io (UC Berkeley RISELab 発の分散コンピューティング)',
      'PyTorch',
      'Kubernetes',
    ],
    correct: 1,
  ),
  'cerebrium': _Quiz(
    question: 'Cerebrium の serverless GPU の特徴は?',
    options: [
      '5 分以上の cold start',
      'sub-second cold start + OpenAI 互換 endpoints',
      'GPU 必須事前予約',
      'CPU 専用',
    ],
    correct: 1,
  ),
  'magic_ai': _Quiz(
    question: 'Magic AI の LTM-2-mini モデルが扱える context window サイズは?',
    options: [
      '8K token',
      '128K token',
      '100M token (≈ 10M 行のコード or 750 冊の小説)',
      '無制限 (ストリーミング)',
    ],
    correct: 2,
  ),
  'jina_ai': _Quiz(
    question: 'Jina AI の jina-embeddings-v3 の料金は？',
    options: [
      '\$0.002 / 1M tokens',
      '\$0.02 / 1M tokens',
      '\$0.20 / 1M tokens',
      '\$2.00 / 1M tokens',
    ],
    correct: 1,
  ),
  'stepfun': _Quiz(
    question: 'Step 3.5 Flash の MoE アーキテクチャで、1トークンあたり何パラメータが活性化する？',
    options: [
      '196B（全体）',
      '70B',
      '11B',
      '7B',
    ],
    correct: 2,
  ),
  'modular': _Quiz(
    question: 'Modular が 2026年2月に買収した AI serving ライブラリは？',
    options: [
      'vLLM',
      'BentoML',
      'Triton Inference Server',
      'Ray Serve',
    ],
    correct: 1,
  ),
  'radixark': _Quiz(
    question: 'RadixArk の SGLang が持つ KV キャッシュ最適化技術の名称は？',
    options: [
      'FlashAttention',
      'PagedAttention',
      'RadixAttention',
      'GroupedQueryAttention',
    ],
    correct: 2,
  ),
  'baseten': _Quiz(
    question: 'Baseten の GPU 時間課金で最も安いインスタンスの開始価格は？',
    options: [
      '\$0.10/hr',
      '\$0.63/hr',
      '\$1.60/hr',
      '\$3.20/hr',
    ],
    correct: 1,
  ),
  'baichuan': _Quiz(
    question: 'Baichuan-M3 が達成した医療 AI ベンチマークのランキングは？',
    options: [
      'HealthBench Hard #1',
      'MedQA #2',
      'USMLE Top 3',
      'MMLU Medical #1',
    ],
    correct: 0,
  ),
  'lepton': _Quiz(
    question: 'NVIDIA が 2025 年に買収した Lepton AI の独自推論エンジン名は？',
    options: [
      'Thunder',
      'Tuna',
      'Flash',
      'Turbo',
    ],
    correct: 1,
  ),
  'krutrim': _Quiz(
    question: 'Krutrim AI がサポートするインド言語の生成対応言語数は？',
    options: [
      '5 言語',
      '10 言語',
      '15 言語',
      '22+ 言語',
    ],
    correct: 1,
  ),
  'deepgram': _Quiz(
    question: 'Deepgram Nova-2 STT の料金は？',
    options: [
      r'$0.0012/min',
      r'$0.0043/min',
      r'$0.0120/min',
      r'$0.0250/min',
    ],
    correct: 1,
  ),
  'did': _Quiz(
    question: 'D-ID Talks API の入力として正しい組み合わせは？',
    options: [
      'テキスト + テキスト',
      '画像 + 音声',
      '動画 + テキスト',
      '音声 + 音声',
    ],
    correct: 1,
  ),
  'cartesia': _Quiz(
    question: 'Cartesia Sonic モデルの特徴として正しいものは？',
    options: [
      'Transformer ベースの大規模モデル',
      '状態空間モデルで 135ms 以下の超低遅延',
      'オフライン専用・クラウド非対応',
      '画像生成に特化したモデル',
    ],
    correct: 1,
  ),
  'tavus': _Quiz(
    question: 'Tavus CVI (Conversational Video Interface) の説明として正しいものは？',
    options: [
      '静止画から動画を生成するバッチ処理 API',
      'LLM と統合したリアルタイム会話動画エージェント',
      'テキストから音声のみを生成する TTS サービス',
      'SNS 投稿用の短尺動画自動生成ツール',
    ],
    correct: 1,
  ),
  'synthesia': _Quiz(
    question: 'Synthesia が対応している言語数は？',
    options: [
      '50 言語',
      '80 言語',
      '140 言語',
      '200 言語',
    ],
    correct: 2,
  ),
  'play_ht': _Quiz(
    question: 'PlayHT Turbo v2 モデルの特徴は？',
    options: [
      '最高品質だが遅延が大きい',
      '業界最速クラス 75ms の超低遅延 TTS',
      'オフライン専用のローカルモデル',
      '画像から音声を生成する特殊モデル',
    ],
    correct: 1,
  ),
  'descript': _Quiz(
    question: 'Descript の「Overdub」機能の説明として正しいものは？',
    options: [
      '動画にオーバーレイ字幕を自動付与する機能',
      '自分の声をクローンして後から音声を書き直せる機能',
      'バックグラウンドノイズを除去する AI 機能',
      '動画を自動でカット編集する機能',
    ],
    correct: 1,
  ),
  'wandb': _Quiz(
    question: 'W&B Weave の主な用途は？',
    options: [
      '機械学習モデルの重み可視化',
      'LLM アプリのトレーシング・評価・コスト監視',
      'ハイパーパラメータの自動最適化',
      'データセットのバージョン管理',
    ],
    correct: 1,
  ),
  'modal': _Quiz(
    question: 'Modal Labs の最大の特徴は？',
    options: [
      'ブラウザ上で Python を実行するサービス',
      'Python デコレータ1行でローカル関数をクラウド GPU で実行',
      'GPU のオークションサイト',
      '機械学習モデルのマーケットプレイス',
    ],
    correct: 1,
  ),
  'pinecone': _Quiz(
    question: 'Pinecone が RAG 構築で担う役割は？',
    options: [
      'LLM モデル本体をホスティングするサービス',
      'テキストの感情分析を行うツール',
      'ベクター埋め込みを高速検索するベクターデータベース',
      'プロンプトを自動最適化するツール',
    ],
    correct: 2,
  ),
  'langchain': _Quiz(
    question: 'LangChain の「RAG」フローで「Retriever」の役割は？',
    options: [
      'テキストを埋め込みベクターに変換する',
      'ベクターストアから関連ドキュメントを検索して取得する',
      'LLM に送るプロンプトを自動生成する',
      'ドキュメントを適切なサイズに分割する',
    ],
    correct: 1,
  ),
  'llamaindex': _Quiz(
    question: 'LlamaIndex が LangChain と比べて特に優れている点は？',
    options: [
      'チェーン・エージェント構築に特化している',
      'データ取り込み・インデックス構築に特化しRAG精度が高い',
      'SNS 投稿の自動生成に特化している',
      'Python のみ対応で JavaScript は使えない',
    ],
    correct: 1,
  ),
  'qdrant': _Quiz(
    question: 'Qdrant が Pinecone に対して持つ最大のアドバンテージは？',
    options: [
      'クラウド専用で管理が不要',
      r'料金が $0.001/クエリと最安値',
      'Rust 実装 + セルフホスト可能でデータをオンプレに保持できる',
      'GPT-4 専用に最適化されている',
    ],
    correct: 2,
  ),
  'roboflow': _Quiz(
    question: 'Roboflow が提供する「Supervision」ライブラリの主な用途は？',
    options: [
      'LLM のプロンプトを監視・改善するツール',
      'コンピュータビジョンの推論結果を可視化・後処理するユーティリティ',
      'クラウド GPU の使用量を監視するツール',
      'アノテーター（人間）の作業を管理するシステム',
    ],
    correct: 1,
  ),
  'lightning_ai': _Quiz(
    question: 'PyTorch Lightning の主な役割は？',
    options: [
      'クラウドへのモデルデプロイを自動化するツール',
      'GPU/TPU 学習のボイラープレートを排除してコードを整理するフレームワーク',
      'ハイパーパラメータを自動チューニングするツール',
      'モデルの推論を高速化する量子化ライブラリ',
    ],
    correct: 1,
  ),
  'weave': _Quiz(
    question: 'W&B Weave で @weave.op() デコレータをつけると何が起きる？',
    options: [
      '関数が GPU で並列実行される',
      '関数の呼び出し・入出力・レイテンシが自動トレースされてダッシュボードに記録される',
      '関数がキャッシュされて2回目以降は高速化される',
      'プロンプトが自動最適化される',
    ],
    correct: 1,
  ),
  'oxen_ai': _Quiz(
    question: 'Oxen AI が解決する「Git の限界」とは？',
    options: [
      'コードのバージョン管理ができない',
      '大容量の ML データ (画像/CSV/Parquet) を効率的にバージョン管理できない',
      'クラウドへのデプロイが複雑',
      'チームコラボレーション機能がない',
    ],
    correct: 1,
  ),
  'predibase': _Quiz(
    question: 'Predibase の「LoRAX」エンジンが実現する革新とは？',
    options: [
      '1 GPU で複数の LLM ベースモデルを同時起動する',
      '1 GPU で 1000+ の LoRA アダプターを同時サーブし、リクエストごとに切り替える',
      'LoRA 学習を自動で100回実行して最良の結果を選ぶ',
      'GPU なしで LLM をCPUだけで学習できる',
    ],
    correct: 1,
  ),
  'argilla': _Quiz(
    question: 'Argilla が RLHF データ収集で担う役割は？',
    options: [
      'LLM のファインチューニングを自動実行する',
      '人間が AI 出力を評価・比較してフィードバックデータを収集・管理する',
      'ベクターデータベースに埋め込みを保存する',
      'プロンプトを自動最適化する',
    ],
    correct: 1,
  ),
  'dify': _Quiz(
    question: 'Dify が LangChain と比べて優れている点は？',
    options: [
      'より多くの LLM モデルに対応している',
      'ビジュアル GUI でノーコード・ローコードで LLM ワークフローを構築できる',
      'Python コードで細かい制御ができる',
      '無料プランのトークン上限が最も高い',
    ],
    correct: 1,
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// フォールバックコンテンツ（DB が空の場合に表示）
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, String> _fallback = {
  'google': '''
## Google AI (Gemini)

### 主要モデル
- **Gemini 2.5 Pro** — 最高精度・1Mトークン・Thinking機能
- **Gemini 2.5 Flash** — 高速・低コスト・Thinking対応
- **Gemini 2.0 Flash** — 安定版

### 特徴
- 100万トークンの超長文コンテキスト
- 画像・動画・音声のネイティブ処理
- Google Search連携・リアルタイム情報
- Vertex AI / Google AI Studio でAPI提供
''',
  'openai': '''
## OpenAI

### 主要モデル
- **GPT-4o** — 高汎用性・マルチモーダル
- **o1 / o3** — 推論特化・Thinking機能
- **o1-mini / o3-mini** — 軽量推論

### 特徴
- Function Calling / Structured Outputs
- Assistants API でのスレッド管理
- DALL-E 3 による画像生成
- 業界標準のAPIエコシステム
''',
  'anthropic': '''
## Anthropic (Claude)

### 主要モデル
- **Claude Sonnet 4.6** — 最新・高性能バランス型
- **Claude Opus 4.6** — 最高精度
- **Claude Haiku 4.5** — 高速・低コスト

### 特徴
- Constitutional AI による安全設計
- 200Kトークンコンテキスト
- コーディング・文章作成に高評価
- Claude Code (CLIツール) で開発者支援
''',
  'microsoft': '''
## Microsoft (Copilot / Azure AI)

### 主要サービス
- **Microsoft Copilot** — Word/Excel/Teams統合
- **Azure OpenAI Service** — GPT-4o/o1エンタープライズ版
- **Phi-4** — 軽量オープンソースSLM

### 特徴
- Microsoft 365 との深い統合
- エンタープライズセキュリティ・コンプライアンス
- GitHub Copilot でコーディング支援
- RAG構築: Azure AI Search + OpenAI
''',
  'meta': '''
## Meta AI (LLaMA)

### 主要モデル
- **LLaMA 3.3 70B** — 最新・高精度オープンソース
- **LLaMA 3.2** — マルチモーダル対応
- **LLaMA 3.1 405B** — 大規模・GPT-4級

### 特徴
- 完全オープンソース (商用利用可能ライセンス)
- ローカル実行対応 (Ollama等)
- WhatsApp/Instagram統合の Meta AI バックエンド
- 自由なファインチューニング
''',
  'x': '''
## xAI (Grok)

### 主要モデル
- **Grok 3** — 最新・高性能
- **Grok 3 mini** — 軽量版
- **Grok 2** — 安定版

### 特徴
- X(Twitter) のリアルタイム情報へのアクセス
- Aurora (画像生成) 統合
- X Premium ユーザーは無料利用可
- 制限の少ない応答スタイル
''',
  'deepseek': '''
## DeepSeek

中国の AI 企業が開発。圧倒的コストパフォーマンスで2025年初頭に世界的注目を集めた。

### 主要モデル
- **DeepSeek R1** — 推論特化・o1に匹敵・超低コスト・OSS
- **DeepSeek V3** — 汎用・高性能
- **DeepSeek Coder V2** — コーディング特化

### 特徴
- GPT-4o 比 約30〜50倍安いAPI料金
- R1 は Chain-of-Thought 推論ステップを明示出力
- MIT ライセンスでオープンソース公開
- Ollama 等でローカル実行も可能
''',
  'mistral': '''
## Mistral AI

フランス発。効率的なオープンウェイトモデルで欧州AI界をリード。

### 主要モデル
- **Mistral Large** — 最高精度
- **Mistral Nemo** — 128Kコンテキスト・軽量
- **Codestral** — コーディング特化

### 特徴
- 欧州発・GDPRコンプライアンス重視
- オープンウェイト版あり (自由デプロイ)
- Function Calling・JSON モード対応
''',
  'perplexity': '''
## Perplexity AI

検索エンジンとLLMを融合したAI検索サービス。

### 特徴
- リアルタイム検索 + 引用付き回答
- 情報ソースの透明性が高い
- Pro Search: 深い分析・比較が可能
- API 提供あり (OpenAI互換)
''',
  'cohere': '''
# Cohere — エンタープライズ RAG 特化

Cohere は企業向け RAG (検索拡張生成) パイプラインに特化した AI プラットフォームです。
Embed + Rerank + Command R+ の組み合わせが業界最高水準のRAGを実現します。

## 主要モデル
- Command R+ (128K, RAG・エージェント特化)
- Command A (256K, フラッグシップ)
- Embed v4.0 (多言語セマンティック検索)
- Rerank v3.5 (検索精度向上)
- Aya Expanse (130言語対応オープンウェイト)

## 特徴
- エンタープライズ向け GDPR/HIPAA/SOC2 対応
- プライベートデプロイ (AWS / Azure / GCP / オンプレ)
- 無料トライアル枠あり

[Cohere Dashboard](https://dashboard.cohere.com/)
''',
  'core': '''
# Core (CoreWeave) — GPU インフラ AI コンピュート

Core は分散型 GPU クラスタを活用した LLM 推論・ファインチューニングに特化したクラウドプロバイダーです。
超低レイテンシーと価格競争力で、スタートアップから大企業まで対応します。

## 主要コンピュートエンジン
- vLLM (高スループット推論・<10ms)
- TensorRT-LLM (超低レイテンシー・<5ms)
- SGLang (複雑クエリ・フロー制御)
- Llama.cpp (軽量実行)

## 対応 GPU
- NVIDIA H200 / H100 (最高性能)
- L40S (推論最適化)
- AMD MI300X (ROCm対応)

## 特徴
- API シンプル (OpenAI互換)
- 従量課金・短期契約対応
- 複数リージョン・24/7 SLA
- 日本サポート対応中

[CoreWeave 公式](https://www.coreweave.com/)
''',
  'amazon': '''
# Amazon Bedrock / Nova — マルチモデル AI プラットフォーム

Amazon Bedrock は 50+ モデルを単一 API で利用できる AWS のマネージドサービスです。
Amazon Nova は AWS 独自の大規模言語モデルシリーズです。

## Amazon Nova シリーズ
- Nova Micro (テキスト特化・超低コスト)
- Nova Lite (マルチモーダル・低コスト)
- Nova Pro (高精度マルチモーダル)
- Nova Premier (1M コンテキスト・最高精度)
- Nova Canvas (画像生成)
- Nova Reel (動画生成・最大2分)

## 特徴
- AWS VPC/IAM/CloudTrail との完全統合
- エンタープライズ SLA (HIPAA/SOC2/GDPR)
- Converse API で全モデルを統一インターフェースで利用可能

[AWS Console](https://console.aws.amazon.com/bedrock/)
''',
  'groq': '''
# Groq — LPU 超高速推論

Groq は LPU (Language Processing Unit) という独自チップで
業界最速クラスの AI 推論を提供します。

## 主要モデル
- Llama 4 Scout / Maverick
- Llama 3.3 70B
- Mixtral 8x7B
- Whisper Large v3 (音声認識)

## 特徴
- OpenAI 互換 API — 既存コードをほぼ変更なしで移行可能
- 無料枠あり

[Groq Console](https://console.groq.com/)
''',
  'stability': '''
# Stability AI — 画像・動画生成のパイオニア

Stable Diffusion の開発元。テキストから画像・動画・音楽・3Dモデルを生成する
オープンなAIモデルを提供しています。

## 主要モデル
- Stable Diffusion 3.5 Large/Medium (最高品質画像生成)
- SDXL 1.0 (定番・エコシステム最大)
- Stable Video Diffusion (画像→動画)
- Stable Audio 2.0 (テキスト→音楽/SE)

## 特徴
- OSS: 商用利用可能なオープンウェイトモデル
- ローカル実行対応 (VRAM 8GB+)
- ComfyUI / Automatic1111 エコシステム

[Stability AI Platform](https://platform.stability.ai/)
''',
  'huggingface': '''
# Hugging Face — OSS AI モデルの GitHub

100万以上の AI モデルをホスティングする世界最大のモデルハブ。
LLaMA / Mistral / FLUX / Whisper など主要 OSS モデルが全て入手可能。

## 主要機能
- Hub: 100万+ モデル・50万+ データセット (多くは商用可)
- Transformers: BERT/GPT/LLaMA を統一 API で利用
- Inference API: クラウドでモデルを即利用 (無料枠あり)
- Spaces: Gradio/Streamlit でデモアプリ公開
- 日本語モデル: rinna / ELYZA / CyberAgent / llm-jp など

[Hugging Face Hub](https://huggingface.co/)
''',
  'nvidia': '''
# Nvidia — GPU AI インフラの世界標準

ChatGPT / Gemini / Claude など主要 AI の大半が Nvidia GPU で動いています。
NIM (Inference Microservices) で OpenAI 互換の高速推論 API を提供。

## 主要機能
- NVIDIA NIM: 100+モデルを OpenAI 互換 API で利用
- TensorRT-LLM: 同 GPU で最大 5 倍高速化
- ローカルデプロイ: Docker コンテナで完全オンプレ運用可
- Nemotron-70B: Meta LLaMA3.1 を Nvidia がチューニング

[build.nvidia.com](https://build.nvidia.com/) で無料体験可能
''',
  'ibm': '''
# IBM watsonx — エンタープライズ AI の老舗

金融・医療・公共機関での導入実績が豊富な企業向け AI プラットフォーム。
Granite LLM は Apache 2.0 で OSS 公開されており、商用利用・ファインチューニング可能。

## 主要コンポーネント
- watsonx.ai: モデル構築・デプロイ・推論
- watsonx.data: ガバナンス付きデータレイク
- watsonx.governance: AI 監査・バイアス検出
- Granite: IBM 独自 OSS モデル (テキスト・コード生成)

## 特徴
- 東京リージョン対応・データ主権要件に対応
- HIPAA/GDPR/ISO27001 準拠
- OpenAI 互換 API で移行容易

[watsonx.ai](https://cloud.ibm.com/watsonx)
''',
  'sakana': '''
# Sakana AI — 東京発・日本語 AI の最前線

Transformer 論文著者の一人 Llion Jones が共同創業した東京の AI 研究スタートアップ。
「進化的モデルマージング」で少ない計算コストで高性能日本語モデルを実現。

## 主要モデル (Hugging Face で無料公開)
- EvoLLM-JP-A-v1-7B: 日本語特化 LLM
- EvoVLM-JP-v1-7B: 日本語マルチモーダル
- Tanuki-8B / Tanuki-8x8B: 実用日本語モデル

## 注目プロジェクト
- AI Scientist: AI が論文を完全自動生成 (世界初)
- Continuous Thought Machines: 新推論アーキテクチャ

[Sakana AI Hub](https://huggingface.co/SakanaAI)
''',
  'ai21': '''
# AI21 Labs — 256K コンテキストの Jamba モデル

AI21 Labs はイスラエル発の AI 企業。Jamba シリーズは SSM (Mamba) と Transformer を
融合した革新的なアーキテクチャで、256K という業界最長クラスのコンテキストを実現しています。

## モデルラインナップ
- Jamba 1.5 Large (256K, 398B params / active 94B, 最高精度)
- Jamba 1.5 Mini (256K, 52B params / active 12B, 高速・低コスト)

## 特徴
- 256K コンテキスト: 法律文書・財務報告書 100ページ超を一括処理
- MoE (Mixture of Experts): 活性化パラメータ数を抑えつつ高い表現力

[AI21 Docs](https://docs.ai21.com/)
''',
  'aleph_alpha': '''
# Aleph Alpha — 欧州AI主権のリーダー

Aleph Alpha は2020年にドイツで創業。ドイツ政府・EU機関が採用する
GDPR完全準拠のエンタープライズAIプラットフォームです。

## モデルラインナップ
- Pharia-1-LLM-7B (OpenAI互換・次世代)
- Luminous Supreme 70B (最高精度)
- Luminous Extended 30B (バランス型)

## 特徴
- AtMan技術でモデルの推論根拠をトークン単位で可視化 (説明可能AI)
- データはドイツ国内のみで処理 — EU外への転送なし

[Aleph Alpha Docs](https://docs.aleph-alpha.com/)
''',
  'baidu': '''
# Baidu ERNIE — 中国最大の AI プラットフォーム

中国版 ChatGPT として数千万ユーザーを獲得した ERNIE Bot の API。
中国語処理において世界最高水準の精度を誇ります。

## 主要モデル
- ERNIE 4.0 Ultra: 最高精度・128K コンテキスト
- ERNIE 4.0 Turbo: 高速バランス型
- ERNIE Speed: 低コスト大量処理
- ERNIE Lite: 完全無料

[Baidu AI Cloud](https://cloud.baidu.com/)
''',
  'elevenlabs': '''
# ElevenLabs — 音声AI最大手のTTS・音声クローンサービス

ElevenLabs は2022年創業の音声AI企業。テキスト読み上げ・音声クローン・
リアルタイム音声変換を提供し、100万人以上の開発者が利用しています。

## モデルラインナップ
- Eleven Multilingual v2 (32言語・最高品質)
- Eleven Turbo v2.5 (低レイテンシ <250ms / AIエージェント向け)
- Eleven Flash v2.5 (超高速 <75ms / バッチ処理向け)

## 主要ユースケース
- YouTubeナレーション・ポッドキャスト・有声本
- AI音声会話Bot (Claude + ElevenLabs)

[ElevenLabs Docs](https://elevenlabs.io/docs)
''',
  'fireworks_ai': '''
# Fireworks AI — 最速オープンソースAI推論

Fireworks AI はオープンソースモデルの高速推論に特化したAIインフラ企業です。
LLaMA 3.3 70B で業界最高水準の 150+ tokens/秒を実現します。

## 対応カテゴリ
- テキスト生成: LLaMA / Mixtral / Qwen / DeepSeek
- 画像生成: FLUX.1 [dev/schnell] / Stable Diffusion XL
- 音声認識: Whisper v3

## 特徴
- OpenAI 互換 API (base_url 変更のみ)
- サーバーレス課金 + 専有エンドポイントの2モード

[Fireworks AI Docs](https://docs.fireworks.ai/)
''',
  'ideogram': '''
# Ideogram AI — 画像内テキスト生成が業界最高精度

Ideogram AIは「画像の中の文字が正確に読める」という他の画像生成AIが
苦手な領域で圧倒的な精度を誇る画像生成サービスです。

## 特徴
- テキスト精度: ポスター・バナーの文字が正確に読める
- Ideogram 2.0: フォトリアル品質・最大2048×2048px
- Magic Prompt: 短いプロンプトを自動で詳細化

[Ideogram API](https://developer.ideogram.ai/)
''',
  'ollama': '''
# Ollama — プライバシー完全保護のローカルLLM実行ツール

Ollamaは自分のPC/サーバー上でLLaMA・Gemma・Mistral・DeepSeekなどの
オープンソースLLMをローカル実行するツールです。

## 特徴
- データが外部に一切送信されない (完全プライバシー)
- OpenAI SDK互換API (localhost:11434/v1)
- ワンコマンド起動: ollama run llama3.2
- 無料・無制限 (API料金ゼロ)

## 主要モデル
- llama3.3 (70B) / qwen2.5 (7B) / gemma2 (9B)

[Ollama 公式](https://ollama.com/)
''',
  'openrouter': '''
# OpenRouter — 200+モデルをひとつのAPIで

OpenRouter は単一のOpenAI互換エンドポイントで
Claude・GPT・Gemini・LLaMA・DeepSeekなど200以上のLLMにアクセスできるAPIルーターです。

## 主な機能
- OpenAI SDK互換 (base_url変更のみ)
- 自動フォールバック: メインモデル失敗時に代替へ
- 無料モデル: LLaMA 3.2 3B / Mistral 7Bなど

[OpenRouter Docs](https://openrouter.ai/docs)
''',
  'oracle': '''
# Oracle OCI Generative AI — エンタープライズ AI プラットフォーム

Oracle は OCI を通じて Generative AI サービスを提供しています。
Oracle Database 23ai に AI Vector Search を内蔵しているため、
外部ベクトルDBなしで RAG を構築できます。

## 主要モデル
- meta.llama-3.3-70b-instruct (128K, 汎用・高精度)
- cohere.command-r-plus (128K, RAG特化)
- xai.grok-2 (131K, リアルタイム推論)

[Oracle AI](https://www.oracle.com/artificial-intelligence/)
''',
  'reka': '''
# Reka AI — マルチモーダル AI (動画理解対応)

Reka は DeepMind・Google Brain 出身のチームが2022年に設立したAIスタートアップです。
テキスト・画像・動画・音声をすべて統一モデルで処理できます。

## モデルラインナップ
- Reka Core (128K, テキスト+画像+動画+音声, 最高精度)
- Reka Flash (128K, テキスト+画像+動画, バランス型)
- Reka Edge (32K, テキスト+画像, 軽量・エッジ向け)

[Reka API](https://docs.reka.ai/quick-start)
''',
  'replicate': '''
# Replicate — 画像・動画・音声AIのモデルホスティング

Replicate は数千のオープンソースAIモデルをAPIで提供するプラットフォームです。

## 主要モデルカテゴリ
- 画像生成: FLUX.1 Pro/dev/schnell / Stable Diffusion 3
- 動画生成: Stable Video Diffusion / AnimateDiff
- 音声: Whisper / MusicGen / Bark

## 特徴
- 秒課金の完全従量制 — アイドル時コストゼロ
- cog ツールで自分のモデルをデプロイして公開可能

[Replicate Docs](https://replicate.com/docs)
''',
  'runway': '''
# Runway — 動画生成AI最大手 (Gen-3 Alpha)

Runwayはテキスト・画像から高品質な動画を生成するAI企業。
ハリウッド映画のVFXにも採用されています。

## 主要機能
- Text-to-Video: テキストから最大10秒・4K動画を生成
- Image-to-Video: 静止画に動きを付けてアニメーション化
- Gen-3 Alpha Turbo: 高速・低コスト版

[Runway Docs](https://docs.runwayml.com/)
''',
  'suno': '''
# Suno AI — テキストから完全楽曲を生成する音楽AI

Suno AIはテキストのプロンプトから、ボーカル・伴奏・ミックスが完成した
楽曲を数十秒で生成します。月間100万人以上が利用しています。

## 特徴
- テキスト→完全楽曲 (ボーカル+伴奏+ミックス)
- 日本語歌詞の楽曲生成に対応
- ポップ・ロック・EDM・ジャズ・演歌など多ジャンル

[Suno AI](https://suno.com/)
''',
  'together_ai': '''
# Together AI — オープンソースAIの統合プラットフォーム

Together AI は 200+ のオープンソースAIモデルをひとつのAPIで提供するインフラ企業です。
OpenAI SDK と互換性があり、base_url を変更するだけで既存コードが動作します。

## 代表モデル
- meta-llama/Meta-Llama-3.3-70B-Instruct-Turbo (高精度・高速)
- deepseek-ai/DeepSeek-V3 (コーディング特化)
- Qwen/Qwen2.5-72B-Instruct-Turbo (多言語対応)

[Together AI Docs](https://docs.together.ai/)
''',
  'udio': '''
# Udio — 音楽理論に忠実な高品質音楽生成AI

UdioはSunoと並ぶ音楽生成AIの双璧。元Google DeepMindのメンバーが創業し、
音楽的精度を重視した設計が特徴です。

## Sunoとの違い
- インストゥルメンタル品質: Udio > Suno
- 音楽理論精度: Udio > Suno
- ボーカル自然さ: Suno > Udio

## Extend機能
生成した32秒の楽曲を前後に自然延長 → 10分以上のBGMも作成可能

[Udio](https://www.udio.com/)
''',
  'voyage': '''
# Voyage AI — RAG精度を最大化するEmbedding専門企業

Voyage AI は2023年創業のEmbedding専門企業。MTEB で
最上位クラスのスコアを達成しており、RAG構築に特化したモデル群を提供しています。

## モデルラインナップ
- voyage-3-large (1024次元, 32K, MTEB上位・最高精度)
- voyage-multilingual-2 (日本語含む多言語対応)
- rerank-2 (2段階RAG用Reranker)

## RAGへの活用
voyage-3-large でベクトル検索 → rerank-2 で精密再ランキング

[Voyage AI Docs](https://docs.voyageai.com/)
''',
  'writer': '''
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
  'qwen': '''
## Qwen (Alibaba Cloud)
Alibaba製多言語LLM。Qwen2.5-72BはオープンソースLLM最強クラス。
DashScope APIはOpenAI互換。日本語・中国語・英語29言語対応。無料枠あり。

## 主要モデル
- **Qwen2.5-72B** — HuggingFace公開・OSS最強クラス
- **Qwen2.5-Coder** — コーディング特化
- **Qwen-VL** — ビジョン言語モデル
- **QwQ-32B** — 推論特化 (DeepSeek-R1対抗)

## 特徴
- DashScope API: OpenAI SDK互換で移行コスト最小
- 29言語ネイティブ対応 (日本語強い)
- 商用利用可能なApache 2.0ライセンス
- Alibaba Cloud上での完全マネージドサービス

[DashScope API](https://dashscope.aliyuncs.com)
''',
  'moonshot': '''
## Moonshot AI (Kimi)
超長文処理特化。Kimi v1-128kは128Kトークン対応でコスト最安値クラス。
OpenAI SDK互換。PDF/Wordファイルを直接アップロードして処理可能。

## 主要モデル
- **moonshot-v1-128k** — 128Kコンテキスト・標準
- **moonshot-v1-32k** — 32Kコンテキスト・低コスト
- **moonshot-v1-8k** — 8Kコンテキスト・高速

## 特徴
- 超長文書処理: PDF・Word・テキストファイル直接対応
- OpenAI API完全互換 (base_url切り替えのみで移行可)
- 中国本土からも利用可能なAPIサービス
- 研究版: Kimi-VL (ビジョン対応版も公開)

[Moonshot AI API](https://www.moonshot.cn)
''',
  'pika': '''
## Pika Labs
消費者向け動画生成AI。Pika 2.2で1080p・最大10秒の動画生成が可能。
\$0.03/生成の低コストが強み。動画AI 4強 (Runway/Luma/Kling/Pika) の一つ。

## 主要機能
- **テキスト→動画**: プロンプトから即座に動画生成
- **画像→動画**: 静止画に動きを付与するアニメーション化
- **リップシンク**: 音声に合わせた口の動き生成
- **SFX**: 動画に合わせたサウンドエフェクト自動生成

[公式サイト](https://pika.art)
''',
  'assemblyai': '''
## AssemblyAI
音声認識・転写・音声理解のリーディングAPI。Universal-2モデルで99言語対応。
Claude (Anthropic) をデフォルトで採用したLeMURで音声×LLM連携が可能。

## 主要機能
- **Universal-2**: 高精度音声認識・転写モデル
- **LeMUR**: 音声コンテンツに対してLLMで質問・要約・分析
- **Auto Chapters**: 動画・音声を自動チャプター分割
- **Sentiment Analysis**: 話者の感情分析
- **PII Redaction**: 個人情報の自動マスキング

[公式サイト](https://www.assemblyai.com)
''',
  'twelve_labs': '''
## Twelve Labs
動画理解・検索に特化したAI。Marengo埋め込み+Pegasus生成の2モデル構成。
動画Q&A・セマンティック検索・要約・ハイライト抽出が可能。

## 主要モデル
- **Marengo 2.7**: 動画埋め込み・セマンティック検索
- **Pegasus 1.2**: 動画理解・テキスト生成・要約

## 主要機能
- **Video Search**: 動画内容をテキストでセマンティック検索
- **Video Q&A**: 動画に対する自然言語での質問応答
- **Highlight Detection**: 重要シーンの自動検出・抽出
- **Video Summary**: 動画全体の自動要約生成

[公式サイト](https://twelvelabs.io)
''',
  'midjourney': '''
## Midjourney
画像生成AIの代名詞。Discordボット/Web版でテキストから高品質画像を生成。
1,600万人超の有料ユーザーを持つ。

## 主要モデル
- **V7**: 最新フラッグシップモデル・高品質
- **V6.1**: 安定版・フォトリアルな画像生成
- **Niji 6**: アニメ・マンガ・イラスト特化

## 主要機能
- **テキスト→画像**: 自然言語プロンプトから高品質画像
- **Vary (Subtle/Strong)**: バリエーション生成
- **Zoom Out**: 画像を拡張・キャンバス拡大
- **Omni Reference**: キャラクター・スタイル参照生成

[公式サイト](https://www.midjourney.com)
''',
  'hailuo': '''
## Hailuo AI (MiniMax)
MiniMaxが開発するマルチモーダルAI。動画・音声・テキストをAPI提供。
Director Model (カメラワーク制御) と Subject Reference (キャラクター維持) が特徴。

## 主要モデル
- **MiniMax-Text-01**: 100万トークンコンテキスト対応LLM
- **Video-01**: 動画生成モデル (Director Model搭載)
- **Speech-02**: 音声合成・多言語TTS

## 主要機能
- **動画生成**: Subject Referenceでキャラクター一貫性を維持
- **Director Model**: カメラズーム・パン・回転などの映像制作技法を制御
- **音声合成**: 自然な多言語TTSと音声クローン

[公式サイト](https://hailuoai.com)
''',
  'adobe_firefly': '''
## Adobe Firefly
Adobeが開発するクリエイター向け生成AI。商業利用安全な学習データで差別化。
Photoshop・Illustratorと深く統合。Creative Cloud 1億人ユーザー基盤。

## 主要機能
- **Generative Fill**: 選択範囲をプロンプトで自動生成・置換
- **Generative Expand**: 画像の外側をAIで自動拡張
- **Text to Image**: テキストプロンプトから画像生成
- **Text Effects**: テキストにスタイリッシュな素材テクスチャを適用

## 特徴
- Adobe Stockのライセンス取得コンテンツで学習 → 商業利用が安全
- Photoshop/Illustrator/Expressへの深い統合
- Firefly API: 開発者向けAPI提供済み

[公式サイト](https://firefly.adobe.com)
''',
  '01ai': '''
## 01.AI (Yi)
李開復 (Kai-Fu Lee) が率いる中国AIスタートアップ。
Yi-LightningはGPT-4o同等の性能を激安で提供。OpenAI互換APIで移行が容易。

## 主要モデル
- **Yi-Lightning**: GPT-4o同等・\$0.14/100万token (超低コスト)
- **Yi-Large**: 高性能フラッグシップモデル
- **Yi-34B/6B**: Apache 2.0ライセンスのオープンソースモデル

## 特徴
- OpenAI API完全互換 (base_url変更のみで移行可)
- Yi-34BはHugging Faceで公開・商用利用可
- 中国語・英語の双語処理に強み
- 元Google中国社長・李開復が2023年創業

[公式サイト](https://www.01.ai)
''',
  'coze': '''
## Coze (ByteDance)
ByteDanceが開発するAIエージェントプラットフォーム。
ノーコードでAIボット・ワークフロー・プラグインを構築できる。

## 主要機能
- **ボット作成**: ノーコードでAIエージェントを設計・公開
- **600+プラグイン**: Web検索・画像生成・コード実行など
- **ワークフロー**: 複数ステップのタスク自動化フロー構築
- **マルチモデル**: GPT-4o/Claude/Geminiなど複数LLMを切り替え

## 特徴
- LINE/Discord/Slack等への多チャンネルデプロイ
- Knowledge Base: ドキュメントをRAG検索
- Coze Studio: ビジュアルなエージェント設計UI

[公式サイト](https://www.coze.com)
''',
  'apple': '''
## Apple Intelligence
Appleが開発するオンデバイスAI。iPhone/iPad/MacのA17 Pro/M1以降で動作。
プライバシー最優先設計でデバイス内処理とPrivate Cloud Computeを使い分ける。

## 主要機能
- **Writing Tools**: 文章の書き直し・要約・校正
- **Image Playground**: テキストからの画像生成 (オンデバイス)
- **Genmoji**: カスタム絵文字のAI生成
- **Siri強化**: 画面コンテキスト理解・アプリ間連携
- **Clean Up**: 写真の不要物を自動除去

## 特徴
- **Private Cloud Compute**: 高度な処理はAppleサーバーで安全処理
- 20億台以上のAppleデバイスに展開予定
- ChatGPT統合: Siriからオプトイン連携

[公式サイト](https://apple.com/apple-intelligence)
''',
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
  'databricks': '''
## Databricks
データ+AI統合プラットフォーム。DBRX (MoE LLM) はオープンソース最高性能を達成。
MLflow・Delta Lake・レイクハウスアーキテクチャで企業AIを加速。

## 主要モデル
- **DBRX**: MoE アーキテクチャ・Mixture of 16 Experts・オープンソース
- **DBRX Instruct**: チャット・指示チューニング版
- **MPT-7B/30B**: 初期オープンソースLLM (Databricks製)

## 主要機能
- MLflow: MLライフサイクル管理 (実験追跡・モデル管理・デプロイ)
- Delta Lake: トランザクション対応データレイク
- Unity Catalog: AIガバナンス・データリネージ管理
- Mosaic AI: LLMファインチューニング・RAG構築

[公式サイト](https://www.databricks.com)
''',
  'samsung': '''
## Samsung Galaxy AI
Samsungが開発するオンデバイスAI。Galaxy S24シリーズ以降に搭載。
Gemini Nanoをデバイス内で動かし、プライバシーを保護しながらAI機能を提供。

## 主要機能
- **リアルタイム通訳**: 通話中に双方向同時通訳
- **テキスト要約**: メール・メッセージの自動要約
- **Circle to Search**: 画面上の任意箇所をGoogleで検索
- **生成型編集**: 写真内オブジェクトの削除・移動・拡張

## 特徴
- 2億台以上のGalaxyデバイスに展開
- Gemini Nano (オンデバイス) + Gemini Pro (クラウド) のハイブリッド
- 個人情報はデバイス内で処理 (プライバシー保護)

[公式サイト](https://www.samsung.com/ai)
''',
  'zhipu': '''
## Zhipu AI (GLM)
清華大学発のAIスタートアップ。中国AI御三家の一つ。
GLM-4は128Kコンテキスト対応・GPT-4クラスの性能を持つ。

## 主要モデル
- **GLM-4-Plus**: フラッグシップ・128K・マルチモーダル
- **GLM-4-Air**: 高速・低コスト・日常タスク向け
- **CogVideo X**: 動画生成モデル
- **CogView-3-Plus**: 画像生成モデル (FLUX品質)

## 特徴
- 中国語処理で最高水準 (清華大学の言語研究基盤)
- 128K超長文コンテキスト
- コード生成・数学推論に強み
- CogSeriesでビジョン系も展開

[公式サイト](https://www.zhipuai.cn)
''',
  'character_ai': '''
## Character.AI
ロールプレイ・キャラクター会話に特化したAI。1.5億MAU・1,800万キャラクター以上。
Alphabet (Google) の元DeepMindチームが創業。

## 主要機能
- **キャラクター会話**: 有名人・アニメ・オリジナルキャラとの対話
- **キャラクター作成**: 誰でも自分のAIキャラクターを公開可能
- **グループチャット**: 複数AIキャラクターとの同時会話
- **Character Voices**: 音声付きキャラクター会話

## 特徴
- Z世代に圧倒的人気 (1日平均2時間以上利用)
- 1,800万以上のコミュニティ作成キャラクター
- ウェルビーイング機能: 長時間利用への気づき促進
- Googleとの提携・独自モデル (c1.3) を使用

[公式サイト](https://character.ai)
''',
  'inflection': '''
## Inflection AI (Pi)
Reidほか LinkedIn 創業者が設立。感情的知性に特化したAIアシスタント Pi を提供。
Microsoft に主要チームが移籍後も Pi は独立サービスとして継続。

## 主要機能
- **Pi**: 共感的・感情的知性に特化した会話AI
- **Inflection-3**: GPT-4クラスの基盤モデル
- **音声会話**: 自然な音声での長時間対話

## 特徴
- 感情サポート・コーチング・一般相談に特化
- 「AIの親友」というコンセプト
- 判断より傾聴・共感を重視するアーキテクチャ設計
- Microsoftとの提携 (Copilot for Enterprises に技術提供)

[公式サイト](https://pi.ai)
''',
  'adept': '''
## Adept AI
ブラウザや業務SaaSを自然言語で実際に操作する実行型AI。Fuyu-8B のOSS公開でも知られる。

## 主要機能
- **ACT-1 / ACT-2**: ブラウザ・業務SaaSの操作自動化
- **Fuyu-8B**: 画像理解を含むマルチモーダルOSSモデル
- **Adept Agent Platform**: エンタープライズ向け業務自動化基盤

## 特徴
- クリック・入力・検索まで含めて「実際に操作するAI」
- ブラウザと業務SaaSをまたぐ反復作業の自動化に強い
- Amazon連携を含む企業向けエージェント展開
- 「回答するAI」より「実行するAI」に重心がある

[公式サイト](https://www.adept.ai/)
''',
  'prover': '''
## Prover — 定理証明・形式検証特化型 AI

Prover は定理証明（Theorem Proving）と形式検証（Formal Verification）に特化した AI エンジンです。
数学や科学領域で最先端の正確性を求められるタスクに対応し、
汎用 LLM では到達できない SOTA（最先端技術）を達成しています。

## 主要機能

- **Theorem Prover**: Lean / Coq などの証明言語で定理の正確性を機械的に検証
- **Formal Verification**: スマートコントラクト・組み込みシステムの形式的安全性証明
- **Mathematical AI Assistant**: 複雑な数学問題の段階的解法とその正確性保証
- **Logic Analysis Engine**: 論理的矛盾の検出と形式システムの正当性検証

## 特徴

- **数学領域での高精度**: GPT-4 や Claude を遥かに上回る定理証明成功率
- **検証可能性**: AI の出力が機械的に検証可能な形で提示される
- **業界標準ツール統合**: Lean 4、Coq、Isabelle など標準形式言語に対応
- **形式検証による安全性**: ブロックチェーン・航空宇宙など安全性クリティカルな業界に対応

## 対応言語・形式

- Lean 4 / Lean 3 — 依存型言語・定理証明
- Coq — 構成的証明支援
- Isabelle — HOL 系形式言語
- SMT-LIB 2.0 — SMT ソルバー連携

## ユースケース

- **大学数学**: 複雑な定理の自動証明・学習支援
- **スマートコントラクト監査**: 形式検証による安全性保証
- **暗号プロトコル検証**: 意図通りの暗号安全性を機械的に検証
- **飛行制御システム**: FAA等による形式検証対応

[公式サイト](https://www.prover.io/)
''',
  'lmsys': '''
## LMSYS / Chatbot Arena — AIモデル公正評価の世界標準

LMSYS Org (UC Berkeley) は Chatbot Arena を運営する学術研究グループ。
人間によるブラインド比較で GPT / Claude / Gemini を公平に評価し、Elo レーティングを公開。
AI業界で最も信頼される独立ベンチマークとして機能している。

## 主要成果
- **Chatbot Arena**: 人間ブラインド比較で Elo 評価（世界標準ランキング）
- **Vicuna**: LLaMA ベースの高性能オープンソースチャットモデル
- **SGLang**: 構造化生成のための高速推論フレームワーク

[公式サイト](https://lmsys.org/)
''',
  'falcon_tii': '''
## Falcon LLM (TII) — UAE発のオープンウェイトLLM

Technology Innovation Institute (TII, UAE) が開発した完全オープンウェイト LLM。
Apache 2.0 ライセンスで商用利用可能。RefinedWeb（厳選 Web データ）で学習し、
2023年公開当初はオープンソース最高峰の Elo スコアを達成した。

## モデルラインアップ
- **Falcon 180B**: 最大フラッグシップモデル
- **Falcon 40B / 7B**: 推論効率重視モデル
- **Falcon 3**: 最新世代（Mamba アーキテクチャ対応）

[公式サイト](https://falconllm.tii.ae/)
''',
  'black_forest_labs': '''
## Black Forest Labs (FLUX) — ドイツ発の画像生成革命

Stability AI 元コアチームが2024年に創業。FLUX シリーズは DALL-E 3 / Midjourney に
匹敵する品質を実現し、設立数ヶ月で開発者コミュニティから絶大な支持を獲得。

## FLUX モデル
- **FLUX.1 [pro]**: 最高品質・商用 API 提供
- **FLUX.1 [dev]**: 研究・非商用オープンウェイト
- **FLUX.1 [schnell]**: 高速生成（Apache 2.0）

[公式サイト](https://blackforestlabs.ai/)
''',
  'liquid_ai': '''
## Liquid AI — MIT発の次世代アーキテクチャ LFM

MIT 研究室発のボストンスタートアップ（2023年設立）。Transformer に依存しない
液体状態機械（Liquid State Machine）ベースの LFM を開発。長文脈・時系列処理で
Transformer より高い計算効率を実現。\$250M 調達済み。

## モデルラインアップ
- **LFM-40B**: フラッグシップモデル
- **LFM-7B / 3B / 1B**: エッジ向け軽量モデル群

[公式サイト](https://liquid.ai/)
''',
  'snowflake': '''
## Snowflake AI — エンタープライズデータAIのリーダー

クラウドデータプラットフォームにAIを深く統合した Snowflake。SQL・Python・
データウェアハウスと密接に連携し、ガバナンスを保ちながら AI を活用できる点が最大の特徴。

## 主要サービス
- **Cortex AI**: データウェアハウス内でのネイティブ AI 実行
- **Arctic**: Snowflake 独自の Enterprise 特化 LLM
- **Cortex Search / Analyst**: RAG・自然言語 SQL クエリ

[公式サイト](https://www.snowflake.com/en/data-cloud/cortex/)
''',
  'cognition': '''
## Cognition AI (Devin) — 世界初の自律AIソフトウェアエンジニア

2023年創業のサンフランシスコスタートアップ。代表製品 **Devin** は
GitHub Issue・Jira チケットから PR まで自律的に完結させる世界初の AI エンジニア。
SWE-bench で前世代を大幅に上回るスコアを達成し、\$175M を調達。

## 主な能力
- バグ修正・機能実装・テスト作成を自律実行
- ターミナル・ブラウザ・エディタを横断して作業
- Slack / GitHub と直接連携

[公式サイト](https://cognition.ai/)
''',
  'scale_ai': '''
## Scale AI — AI業界の「縁の下の力持ち」

GPT-4 / Claude / Gemini など主要 LLM のトレーニングデータを手掛ける
AI データインフラ企業。高品質なアノテーション・RLHF データで現代 AI の基盤を支える。

## 主要サービス
- **Generative AI Platform**: LLM トレーニング用データ生成・評価
- **RLHF データ**: 人間フィードバック強化学習用データ
- **Scale Donovan**: 国防・政府向け AI 意思決定プラットフォーム

[公式サイト](https://scale.com/)
''',
  'poolside': '''
## Poolside AI — ソフトウェア開発専用の次世代LLM

コーディング能力に特化したフロンティアモデルを開発するスタートアップ。
Devin (Cognition) と並ぶ「AI ソフトウェアエンジニア」分野のパイオニア。
独自アーキテクチャにより汎用 LLM を超えるコーディング精度を実現。

## モデルラインアップ
- **Malibu**: フラッグシップコーディングモデル
- **Point**: 高速・軽量コーディングモデル

[公式サイト](https://poolside.ai/)
''',
  'harvey': '''
## Harvey AI — 法律・プロフェッショナルサービス特化AI

世界トップ法律事務所が採用するリーガルAIプラットフォーム。評価額 \$11B (2026年)。

## 主要機能
- **契約レビュー**: 大量契約書の自動審査・リスク抽出
- **法的リサーチ**: 判例・法令の高精度検索
- **デューデリジェンス**: M&A時の大量文書処理自動化

## 実績
- Am Law 100 の 50%+ が採用
- A&O Shearman・PwC・EY が導入済み

[公式サイト](https://www.harvey.ai/)
''',
  'manus': '''
## Manus AI — 汎用AIエージェント

世界初の真の汎用AIエージェント。タスクを計画・分解・並列実行する。

## 特徴
- **自律実行**: Webブラウジング・コード実行・ファイル操作を自律的にこなす
- **並列処理**: 複数サブタスクを同時進行
- **Meta買収**: \$2-3B で買収済み (2026年)

[公式サイト](https://manus.im/)
''',
  'hedra': '''
## Hedra AI — リアルタイム会話型アバター動画

Character-3 (オムニモーダルモデル) で業界最高精度の口唇同期を実現。

## 特徴
- **Character-3**: 音声・画像・テキストを1モデルで同時処理するオムニモーダルAI
- **低価格**: \$0.05/分
- **実績**: a16z \$44M調達・3M+ ユーザー

[公式サイト](https://www.hedra.com/)
''',
  'heygen': '''
## HeyGen — ビジネス向けAIアバター動画

15秒録画でスタジオ品質動画を生成。175言語のリップシンク翻訳対応。

## 主要機能
- **AIアバター**: 自分の分身を作成して繰り返し利用
- **多言語翻訳**: 175言語でリップシンク
- **MCP統合**: Claude Code との連携対応

## 実績
- G2 2025年最速成長製品賞 #1
- 100K+ 企業採用

[公式サイト](https://www.heygen.com/)
''',
  'recraft': '''
## Recraft AI — プロ向けベクター画像生成

世界唯一レベルのSVGベクター生成に特化。V4でMidjourney・DALL·Eを超えた。

## モデルラインアップ
- **V4 / V4 Pro**: ラスター画像 (1MP / 4MP)
- **V4 Vector / Vector Pro**: 編集可能なSVGベクター

[公式サイト](https://www.recraft.ai/)
''',
  'krea': '''
## Krea AI — リアルタイム画像・動画生成

50ms以下のリアルタイム生成 + 40以上のモデル集約プラットフォーム。

## 主要機能
- **Krea Realtime 14B**: オープンソース動画モデル
- **Node Editor**: 生成チェーンをGUIで構築
- **リアルタイム**: 描画・入力に即応する50ms以下の応答

[公式サイト](https://www.krea.ai/)
''',
  'tencent': '''
## Tencent Hunyuan — テキスト・画像・動画・3D 全モダリティ OSS

中国 Tencent の AI 基盤モデルブランド。OSS 最大級のモデルを全モダリティで公開。

## モデルラインアップ
- **Hunyuan-Large**: 389B MoE LLM / 256K context
- **Hunyuan Image 3.0**: 80B 世界最大OSS画像モデル
- **HunyuanVideo**: 13B+ OSS動画モデル
- **Hunyuan 3D 2.0**: 1枚画像→3D生成

[公式サイト](https://hunyuan.tencent.com/)
''',
  'bytedance': '''
## ByteDance Doubao — TikTok運営の次世代AIエージェント

TikTok運営 ByteDance の AI ブランド。Doubao 2.0 は「Agent Era」特化の次世代モデル。

## モデルラインアップ
- **Seed 2.0 Pro/Lite/Mini/Code**: 4種類の基盤モデル
- **Seedance 2.0**: TikTok統合動画生成
- 業界最安値級 API (GPT-5.2比 3.7倍安)

[公式サイト](https://www.doubao.com/)
''',
  'inception_labs': '''
## Inception Labs (Mercury) — 世界初の商用拡散LLM

世界初の商用 **拡散 LLM (dLLM)**。トークン並列生成で従来 LLM より 5〜10倍高速。

## モデルラインアップ
- **Mercury 2** (2026/02): 史上最速の Reasoning LLM
- 128K context / OpenAI互換API
- Free tier: 10M tokens/月 / Azure AI Foundry 提供

[公式サイト](https://www.inceptionlabs.ai/)
''',
  'world_labs': '''
## World Labs — Fei-Fei Li 創業の空間知能AI

「AIの母」Fei-Fei Li 創業。**Large World Models (LWM)** で 3D 世界を生成する空間知能 AI。

## 主要機能
- **World API** (2026/01): テキスト/画像/動画→3D 世界生成
- USD / glTF など業界標準フォーマット出力
- \$1B 調達・Embodied AI/ロボット訓練支援

[公式サイト](https://www.worldlabs.ai/)
''',
  'runware': '''
# Runware (Sonic Inference Engine)

**「One API for all AI」** 推論統合基盤。画像・動画・音声・3Dを単一APIで扱う。

- **Sonic Inference Engine®**: 既存比30-40%高速・5-10倍低コスト
- 400,000+ モデル対応 (FLUX / DALL-E / Kling / Veo / Hailuo / Seedance等)
- \$50M Series A (2025/12 Dawn Capital/Comcast)
- 従量課金: 画像 \$0.0006〜 / 動画 \$0.14〜 (サブスク不要)
- 公式: https://runware.ai/
''',
  'sambanova': '''
# SambaNova

RDU (Reconfigurable Dataflow Unit) 型 AI 推論チップで、GPU 比 5倍高速・3倍コスト効率を実現する米国スタートアップ。

## 主要技術
- **SN50 チップ** (2026-02 リリース)
- SambaNova Cloud (OpenAI 互換 API)
- Llama 405B を 200+ tokens/sec で提供

## 強み
- 開発者 Free Tier \$5 credit
- Meta / AWS / Intel 戦略提携
- \$350M追加調達・オンプレミス SambaNova Suite
''',
  'lightricks': '''
# Lightricks LTX-2

イスラエル発クリエイティブAI企業。2026年1月に **LTX-2 (22B)** を4K音声+映像同期生成できるOSSモデルとして公開。

## 主要技術
- **音声+映像同期生成** (業界唯一のネイティブ対応 OSS)
- **4K 解像度**・60秒超の長尺動画
- **30倍高速**推論 (民生 GPU で動作)

## 強み
- セルフサーブAPI (ltx.io) + Fal / Replicate / ComfyUI 連携
- OpenRAIL-M ライセンス (ARR \$10M 未満は商用無料)
- HuggingFace `Lightricks/LTX-2` で全ウェイト公開
- LoRA 公式トレーナー同梱
''',
  'arcee_ai': '''
# Arcee AI Trinity

米国フロリダ発の **完全オープンソース・ファンデーションモデル** 企業。2026年4月に **Trinity-Large-Thinking (399B sparse MoE)** を Apache 2.0 で公開。

## ラインナップ
- **Trinity Nano** (6B A1B MoE) — エッジ / オフライン
- **Trinity Mini** (26B A3B MoE) — エージェント / ツール呼び出し
- **Trinity Large** (400B A13B MoE) — フロンティア級
- **Trinity-Large-Thinking** (399B) — Chain-of-Thought 推論特化

## 強み
- **Apache 2.0** / OpenAI 互換 API
- Mini \$0.045/\$0.15 per 1M tokens・OpenRouter 無料枠あり
- MergeKit (50k+ stars) 公式サポート
- 米国発 → 政府 / 金融 / 医療での採用容易
''',
  'minimax': '''
# MiniMax (Hailuo)

中国・上海発のマルチモーダル AI 企業。2026年1月に **香港証券取引所に上場**。

## 最新モデル (2026)
- **MiniMax-M2.7** (Mar 2026) — 256K context / フラッグシップ
- **MiniMax-M2.5** (Feb 2026) — 汎用モデル
- **MiniMax-M2.5-Lightning** — 超高速・低コスト (\$0.10/1M input)

## マルチモーダル統合
- **Hailuo Video** — テキスト→1080p動画 (\$0.10/秒)
- **Hailuo Voice** — TTS + Voice Cloning (50+ 声質)
- **Music API** — 歌詞+BGM 同時生成

## 強み
- OpenAI 互換 API + **MCP 公式サーバー**
- 超長コンテキスト 200K+ tokens
- 日中英 ネイティブ対応
- Free Tier: M2.5-Lightning 月 100万 tokens
''',
  'moondream': '''
# Moondream VLM

軽量・高性能 Vision-Language Model 専業スタートアップ。**Apache 2.0 OSS** + Cloud API の両対応。

## モデル
- **Moondream 3 Preview** (2025/10 リリース) — 9B MoE / 2B active
- **Moondream 2** (1.8B) — エッジ / 組込み向け OSS
- **Detect** — 精密バウンディングボックス物体検出

## 機能
- **VQA** (画像質問応答・日本語対応)
- **OCR** (手書き・印刷・多言語)
- **Object Detection** (商用可)
- **Captioning** (自動タイトル生成)

## 料金
- \$0.30 / 1M input · \$2.50 / 1M output
- 画像 1枚 = **729 tokens** 固定
- Free Tier \$5 / 月 (約 20,000 画像)
- OSS ローカル実行は完全無料 (Apache 2.0)
''',
  'rakuten_ai': '''
# Rakuten AI 3.0

楽天グループが **GENIAC (METI + NEDO)** プロジェクトの一環として開発した、**日本国内最大級 700B MoE** ファウンデーションモデル。2026/3/17 に **Apache 2.0** で公開。

## モデル
- **Rakuten AI 3.0** — 700B MoE / 日本語特化 / Apache 2.0
- **Rakuten AI 2.0** — 8x7B MoE (前世代)
- **Rakuten AI 7B-Instruct** — 軽量 SFT 版

## 強み
- 日本最大級の国産 MoE
- **GENIAC 選定** で政府お墨付き
- **Apache 2.0** で商用無制限
- 関西弁・敬語・業界用語に強い
- 楽天 1.5億ユーザー基盤の実戦投入

## 入手
- HuggingFace `Rakuten/*` で全ウェイト無料公開
- Rakuten AI Gateway API はエンタープライズ商談
''',
  'pfn': '''
# Preferred Networks (PLaMo)

東京発の日本 AI・ML リーディングカンパニー (2014設立)。Chainer 開発元として知られ、**100% 日本製 foundation model「PLaMo™」** を展開。

## モデル
- **PLaMo Prime** — 100B+ 日本語フラッグシップ
- **PLaMo 2** (8B/13B) — 中規模汎用
- **PLaMo Translate** — 日↔英/中 翻訳特化 (SOTA)
- **PLaMo Lite** (2B) — エッジ・モバイル

## 独自インフラ
- **MN-Core** — PFN 自社設計 AI チップ (PLaMo 推論用)
- GPU非依存で推論コスト削減

## 強み
- **100% 日本語スクラッチ学習** (fine-tune ではない)
- 金融・医療・製造・自動車の業界特化版あり
- 東大・京大との共同研究出力
- GENIAC 金融ベンチマーク SOTA

## 入手
- PLaMo API (エンタープライズ商談)
- PLaMo Chat (B2B assistant)
- 研究者無料枠 (大学・NPO)
''',
  'siliconflow': '''
# SiliconFlow

中国・上海発の AI Infrastructure クラウド。**OpenAI 互換 API** で 100+ オープンソースモデルをワンエンドポイントで提供。

## 主要モデル
- Qwen / DeepSeek / Llama / Mistral 系の最新版
- FLUX / Stable Diffusion 系画像生成
- 音声 (Whisper / 各種 TTS)

## 強み
- **OpenAI 互換** — 既存 SDK そのまま使える
- 中国・東南アジアの低遅延ノード
- GPU 不要・トークン課金

## API
- `https://api.siliconflow.cn/v1/chat/completions`
- 無料枠あり (登録時クレジット)
''',
  'novita_ai': '''
# Novita AI

シンガポール・米国発の **GPU 推論クラウド**。テキスト + 画像 + 動画 + 音声のマルチモーダル API を 1 つで提供。

## 主要モデル
- Llama / Qwen / DeepSeek (OpenAI 互換 LLM)
- Stable Video Diffusion / 各種画像生成
- Whisper / 音声合成
- カスタム LoRA 追加可能

## 強み
- **マルチモーダル統合** — 1 アカウントで全モダリティ
- A100/H100 GPU を時間貸し / トークン貸し選択可
- LoRA + ファインチューニング即時デプロイ

## API
- `https://api.novita.ai/v3/openai/chat/completions`
- 画像/動画 endpoint は別パス
''',
  'deepinfra': '''
# DeepInfra

**200+ オープンモデルを業界最安水準で提供する推論インフラ**。Llama・Mistral・Qwen など主要モデルを OpenAI 互換 API で利用可能。

## 主要モデル
- `meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo` (デフォルト)
- `meta-llama/Meta-Llama-3.1-8B-Instruct` (超高速・低コスト)
- `Qwen2.5-72B-Instruct` (日本語強化)
- `deepseek-r1` (推論特化 MoE)

## 強み
- GPT-4o 比で最大 10 分の 1 のコスト
- 200+ モデルを 1 つの API キーで利用
- バッチ推論・並列リクエスト最適化

## API
- `https://api.deepinfra.com/v1/openai/chat/completions`
- 自分株式会社では **Budget Tier** に分類
''',
  'nebius': '''
# Nebius AI Studio

**旧 Yandex グループが欧州で展開する高性能 AI クラウド**。GDPR 準拠の欧州データセンターで最新オープンモデルを提供。

## 主要モデル
- `meta-llama/Llama-3.3-70B-Instruct` (デフォルト・Llama 3.1 後継)
- `meta-llama/Llama-3.1-405B-Instruct` (最高品質)
- `Qwen/Qwen2.5-72B-Instruct` (多言語)
- `deepseek-ai/DeepSeek-V3` (最新 MoE)

## 強み
- 欧州 GDPR 準拠データ処理
- Yandex 技術チームによる運営
- 高スループット・エンタープライズ対応

## API
- `https://api.studio.nebius.com/v1/chat/completions`
- 自分株式会社では **Performance Tier** に分類
''',
  'fal_ai': '''
# fal.ai

米国発の **生成メディア統合 API**。1,000+ モデル (画像/動画/音声/3D) を 1 キーで呼べる低遅延 GPU クラウド。

## 主要モデル
- **Seedance 2.0** — 1080p 高品質動画生成
- **FLUX.1 [dev]** — Black Forest Labs SOTA 画像
- **Nano Banana** — Gemini 2.5 Flash Image (高速)
- **Stable Audio** — テキスト → 楽曲
- **TripoSR** — 単一画像 → 3Dメッシュ

## 強み
- 専用最適化エンジンで他社比 4倍高速
- WebSocket リアルタイムストリーミング
- LoRA 即時デプロイ (HF から数分)

## API
- `pip install fal-client` → API key で 3 行コード
- 詳細: https://fal.ai/docs/documentation
''',
  'fish_audio': '''
# Fish Audio

中国発の **音声 AI 専業プラットフォーム**。70+ 言語 / 1,000+ プリビルド音声 / 即時ボイスクローン。

## 主要モデル
- **Fish Speech S1** — フラッグシップ TTS (OSS)
- **Fish Speech S1-Mini** — エッジ向け軽量版
- **Voice Clone v2** — 5 秒サンプルで即時クローン
- **Real-time Stream** — WebSocket フレーム単位返却

## 強み
- 200ms 以内で最初のフレーム返却 (会話 AI 向け)
- CJK (中国語/日本語/英語) 高品質
- OSS Fish Speech S1 は GitHub で無料公開

## API
- `https://api.fish.audio/v1/tts`
- OSS: https://github.com/fishaudio/fish-speech
''',
  'atlas_cloud': '''
# Atlas Cloud

世界初の **フルモーダル inference platform**。チャット・推論・画像・音声・動画を **OpenAI 互換 API 1 本** で呼び出せる。

## 主要モデルコレクション
- **OpenAI** — gpt-5.4 / gpt-5 / gpt-4o
- **DeepSeek** — V3 / R1 (推論特化)
- **Qwen** — Qwen3-235B / Qwen2.5-72B
- **GLM** — 智譜 AI 中国 LLM
- **MiniMax** — m2.1 動画/音声統合
- **Flux** — FLUX.1 [dev] / [schnell] 画像生成

## 強み
- 唯一のフルモーダル統合 (chat + image + video + audio in 1 API)
- 300+ モデルを 1 アカウントで利用
- 透過的 per-token 課金 + 無料クレジット
- production 向け SLA 低遅延

## API
- `https://api.atlascloud.ai/v1/chat/completions`
- OpenAI SDK の base URL を変えるだけで動く
''',
  'mira_network': '''
# Mira Network

AI 出力を **暗号学的に検証可能** にする decentralized blockchain protocol。AI の幻覚問題を「複数ノードによる分散検証」で解決する trust layer。

## 主要モデル
- **mira/llama3.1** — Mira 検証最適化 Llama
- **GPT-4o** — 検証付き OpenAI フラッグシップ
- **Llama 3.1 405B** — 検証付き OSS 最大級

## 強み
- AI 出力の信頼性を暗号学的に保証
- 分散ノードによる majority consensus
- 主要 LLM に検証 layer を被せて使える
- 500K+ users / 200K daily inferences

## API
- Python SDK: `pip install mira-sdk`
- **Verified Generate**: 1 コール で生成 + 検証
- **Verify only**: 既存出力の検証
- 利用には \$MIRA トークン (crypto) 必須
''',
  'gmi_cloud': '''
# GMI Cloud

NVIDIA **TensorRT-LLM** バックエンドの低遅延 inference platform。100+ オープンモデルを OpenAI 互換 API で提供。

## 主要モデル
- **DeepSeek-V3.2** — \$0.28/\$0.40 per 1M tokens (推論コスパ最強)
- **GLM-5** — Zhipu AI フラッグシップ
- **Llama-3.1-8B/70B/405B** — OSS 標準
- **Qwen2.5-72B** — 中国語強い

## 強み
- TensorRT-LLM + vLLM + FP8 で 2026 最低レイテンシ級
- H100 GPU 約 \$2.10/hr 即時プロビジョン
- Free Tier ありで試用容易
- 100+ モデル 1 アカウント

## API
- `https://api.gmicloud.ai/v1/chat/completions`
- OpenAI SDK の base URL 切替で動く
''',
  'inworld': '''
# Inworld AI

AI エージェント・キャラクター・音声システム構築プラットフォーム。**Inworld Router** で hundreds of models を OpenAI 互換 API 統合。

## 主要サービス
- **Router**: cost / latency / quality 動的ルーティング・自動フォールバック
- **Agent Runtime**: C++ orchestration core (LLM + TTS + STT + tools・無料)
- **Realtime API**: speech-to-speech (OpenAI Realtime protocol 互換)
- **Inworld TTS**: 高品質低遅延 voice synthesis

## 強み
- 単一 API で OpenAI / Anthropic / Google etc 統合
- live experiments + KPI 計測標準装備
- ゲーム業界 NPC dialogue で老舗実績

## 料金 (例)
- **GPT 4o Mini**: \$0.15/M入力・\$0.60/M出力
- **GPT 5 Mini**: \$0.25/M入力・\$2.00/M出力
- Router 利用料: 無料 (モデル消費料のみ)

## API
- `https://api.inworld.ai/v1/chat/completions`
- OpenAI SDK そのまま drop-in
''',
  'coreweave': '''
# CoreWeave

AI ネイティブ企業向け **GPU クラウド**。OpenAI / Meta / Perplexity 等の本番推論インフラを支える Tier 1 NVIDIA GPU プロバイダー。

## 主要サービス
- **GPU クラウド**: H100 / B200 / B300 / Vera Rubin NVL72 (2026 H2)
- **AI Inference platform**: 大規模・低遅延・predictable cost
- **Kubernetes ネイティブ**: K8s + InfiniBand multi-node
- **Inworld Router 経由**: hundreds of models 利用可

## 強み
- NVIDIA 最新 GPU 業界最速展開 (B300, Vera Rubin NVL72)
- InfiniBand 8 NIC/node で大規模並列推論
- Reserved pricing で月額固定運用
- SOC 2 / HIPAA / FedRAMP-ready

## 料金 (例)
- **H100**: \$2.39/hr (on-demand) — 業界平均より低価格
- **B200**: \$3.49/hr
- Reserved 1〜3 年で大幅 discount

## アクセス
- K8s + vLLM/SGLang デプロイ
- Inworld Router 経由 OpenAI 互換 chat
''',
  'lambda_labs': '''
# Lambda Labs

AI/ML 特化 **GPU クラウド** 老舗 (2012〜)。元々は研究者向けに NVIDIA GPU 時間貸しで有名。**業界最安値級** H100 \$2.89/hr。

## 主要サービス
- **Lambda Cloud (GPU)**: H100 \$2.89/hr / B200 \$3.49/hr
- **Lambda Inference API** (廃止予定 — 2025 wind-down 方針)
- **1-Click Clusters**: H100 マルチノードを 1 クリック
- **Lambda Stack**: PyTorch + CUDA bundled

## 強み
- **業界最安 GPU レンタル**: cheapest on-demand H100
- AI 研究者御用達 (大学・スタートアップ実績多数)
- Lambda Stack で NVIDIA ドライバ問題から解放

## 料金
- **H100 on-demand**: \$2.89/hr (最安)
- **B200 on-demand**: \$3.49/hr
- **A100 80GB**: \$1.79/hr
- Reserved 1yr で 30〜50% discount

## 注意
- **Inference API は wind-down 中** — 新規プロジェクトは Inworld Router / DeepInfra 推奨
- GPU 直接賃貸は引き続き継続
''',
  'hyperbolic': '''
# Hyperbolic Labs

**分散 GPU クラウド + 検証可能 AI 推論**プラットフォーム。世界中の遊休 GPU を blockchain ベースで集約し AWS/GCP より圧倒的に低コスト。

## 主要サービス
- **GPU レンタル**: RTX 4090 \$0.50/hr / A100 \$1.80/hr / H100 \$3.20/hr
- **Inference API**: Llama / DeepSeek / Qwen を OpenAI 互換で
- **Verifiable AI**: zk-snarks で推論結果改竄検知
- **Hyper-dOS**: 分散 GPU 統一管理

## 強み
- AWS/GCP の 1/2 〜 1/4 価格
- zk proof による verifiability
- データプライバシー (推論データ残らない)
- 単一障害点なし

## API
- `https://api.hyperbolic.xyz/v1/chat/completions`
- OpenAI SDK base_url 切替で動く
''',
  'anyscale': '''
# Anyscale

**Ray.io** (UC Berkeley RISELab 発・OSS 分散コンピューティング) の商用版。Anyscale Endpoints で OSS LLM を OpenAI 互換 serverless API として提供。

## 主要サービス
- **Endpoints**: Llama 3.1 / Mistral / Mixtral 等の serverless LLM
- **Ray Serve**: 自前 LLM デプロイ・fine-tuning
- **Jobs**: 分散学習・バッチ推論
- **Workspaces**: notebook 環境

## 強み
- Ray ベース ML 特化分散
- OpenAI 互換 drop-in
- LoRA fine-tuning サービス
- AWS Partner

## 料金
- **Llama 3.1 70B**: \$1.00/M token

## API
- `https://api.endpoints.anyscale.com/v1/chat/completions`
''',
  'cerebrium': '''
# Cerebrium

**serverless GPU/CPU プラットフォーム**。"Vercel for AI" 的位置付け。すべての endpoint が **OpenAI 互換** で sub-second cold start。

## 主要サービス
- **Serverless GPU/CPU**: H100 / A100 / RTX 4090 / CPU
- **OpenAI 互換 endpoints**: `/chat/completions` + `/embedding`
- **Voice Agents**: real-time speech-to-speech
- **Video Models**: stable-diffusion-video 等

## 強み
- sub-second cold start
- OpenAI 互換 (drop-in)
- instant autoscaling (0→1000 RPS)
- multi-region 低レイテンシ

## 料金
- **H100**: \$0.001167/sec (= \$4.20/hr)
- **A100**: \$0.000556/sec (= \$2.00/hr)
- cold start fee: なし
''',
  'magic_ai': '''
# Magic AI

ソフトウェア開発特化の AI 研究企業。**LTM-2-mini = 100M token context** モデル (Llama 3.1 405B 比 1000x 効率) で業界に衝撃。Google Cloud G4/G5 supercomputer 提携。

## 100M token とは
- ≈ 10,000,000 行のコード
- ≈ 750 冊の小説
- Llama 比 attention cost 1000x 安い

## 主要サービス
- **LTM-2-mini**: 100M token context モデル (research preview)
- **コード補完**: 全 codebase + docs + libraries を context で生成
- **HashHop benchmark**: 長文 context 内検索性能 SOTA

## 強み
- 業界最大 context (次点 Gemini 2M)
- Llama 比超効率
- Google Cloud G4 (H100) / G5 (Grace Blackwell) 提携
- コード AI 特化

## 注意
- production API は未公開 (research preview のみ)
- 累計調達 \$320M / 公開待機状態
''',
  'jina_ai': '''
# Jina AI

ベルリン発の**検索基盤（Search Foundation）**特化 AI スタートアップ。RAG パイプラインに必須の embeddings・reranking・web reader API を提供。

## 主要モデル
- **jina-embeddings-v3**: \$0.02 / 1M tokens、8192 token context、100言語以上対応
- **jina-reranker-v3**: 0.6B パラメータ、多言語高精度リランキング
- **jina-reader**: URL → Markdown 変換 API（無料）

## 料金
- Free: 100 RPM / 100K TPM（即試用可能）
- Paid: \$0.02 / 1M tokens

## 活用
- RAG の精度向上（embed + rerank の組み合わせ）
- ベクトル DB（Pinecone / Weaviate / Qdrant）連携
- 同一 API キーで全サービス利用可能
''',
  'modular': '''
# Modular

「kernel から cloud まで」の AI inference stack を 1 platform で提供。**MAX** (serving) + **Mojo** (言語) + **BentoML** (2026-02 買収) の統合企業。

## 主要プロダクト
- **Mojo**: Python 互換の systems 言語 (CUDA カーネルを Python で記述可能)
- **MAX**: vLLM/SGLang 競合の高性能 inference serving
- **BentoML 統合**: packaging + adaptive batching + K8s オーケストレーション

## 特徴
- multi-hardware (GPU / ASIC / CPU) を統一 API
- MAX core は OSS / Enterprise 機能は商用
- Llama 3.3 70B / Mistral / Qwen 対応

## API
```bash
max serve --model llama3-70b
# OpenAI 互換エンドポイントで即利用
```
''',
  'baseten': '''
# Baseten

エンタープライズ向け **AI モデルデプロイメント基盤**。カスタムモデル・OSS モデルを本番 GPU インフラで安定稼働させる MLOps プラットフォーム。

## 特徴
- **Serverless API**: トークン課金、変動負荷に最適
- **Dedicated GPU**: T4 \$0.63〜B200 \$9.98/hr、分単位課金
- **99.99% SLA**: エンタープライズ SLA 保証
- **Gen AI 最適化**: LLM / Diffusion / 音声 各推論スタック
- **Google Cloud パートナー**: 225% コストパフォーマンス改善実績

## 対応モデル
Llama 3.3 70B / Mistral / Qwen / Whisper / SDXL / FLUX.1

## カスタムモデルデプロイ
```bash
pip install truss
truss init my-model && truss push
```
''',
  'lepton': '''
# Lepton AI (NVIDIA DGX Cloud Lepton)

元 Alibaba VP・PyTorch/Caffe 開発者 Yangqing Jia 創業。2025年4月 **NVIDIA が買収**し、現在は NVIDIA DGX Cloud Lepton として提供。

## Tuna 推論エンジン
- **600+ tokens/sec** — 業界最速水準
- 20B tokens/day 処理実績
- 1M+ images/day

## 対応モデル
Llama 3.3 / Mistral / Qwen / DeepSeek / FLUX.1 / SDXL

## Python SDK
```python
from leptonai.photon import Photon
# 数行で AI サービスをデプロイ
```

## OpenAI 互換
```python
client = OpenAI(
    api_key="YOUR_KEY",
    base_url="https://llama3-3-70b.lepton.run/api/v1/"
)
```
''',
  'krutrim': '''
# Krutrim AI

Ola 創業者設立のインド発 AI スタートアップ。2024年1月**インド初 AI ユニコーン**（\$1B 評価額）達成。22+ インド言語 × 2 兆トークン訓練。

## 特徴
- **22+ インド言語理解** / 10 言語生成
- 25,000+ 開発者、2,500 億 API コール実績
- 翻訳 / 音声 / 動画ローカライズ API
- インド AI チップ計画（Bodhi / Sarv / Ojas）

## API
```python
client = OpenAI(
    api_key="YOUR_KEY",
    base_url="https://cloud.olakrutrim.com/v1"
)
# ヒンディー語・タミル語などで直接呼び出し
```

## 活用
- インド市場アプリ / 農業 AI / 教育 / 多言語 CS ボット
''',
  'deepgram': '''
# Deepgram

音声 AI 専門企業。NASA・Twilio・NVIDIA が採用する業界最速 STT。

## モデル
- **Nova-3** — 最高精度・多言語・\$0.0052/min
- **Nova-2** — 安定版・\$0.0043/min
- **Aura-2 TTS** — 自然音声合成・\$0.0150/1K chars
- **Voice Agent API** — LLM + STT + TTS 統合

## API
```python
from deepgram import DeepgramClient, PrerecordedOptions
client = DeepgramClient("API_KEY")
response = client.listen.rest.v("1").transcribe_file(
    {"buffer": audio},
    PrerecordedOptions(model="nova-2", language="ja")
)
```

## 特徴
- \$200 無料クレジット（クレカ不要）
- リアルタイム WebSocket STT 対応
- スピーカー分離（Diarization）対応
''',
  'did': '''
# D-ID

静止画から**話すアバター動画**を生成する AI プラットフォーム。

## 主な API
- **Talks API** — 画像 + 音声 → リップシンク動画
- **Clips API** — テキスト → アバター動画（TTS 統合）
- **Agents API** — LLM + WebRTC リアルタイムアバター

## API
```python
import requests, base64
headers = {"Authorization": f"Basic {base64.b64encode(b'KEY:').decode()}"}
r = requests.post("https://api.d-id.com/clips", headers=headers, json={
    "presenter_id": "amy-jcwCkr1grs",
    "script": {"type": "text", "input": "こんにちは！"}
})
```

## 料金
- Lite: \$5.99/月（10分）
- Pro: \$49.99/月（15分・API 含む）
- Advanced: \$299/月（65分）
''',
  'cartesia': '''
# Cartesia AI

**状態空間モデル (SSM)** 「Sonic」で業界最速クラス 135ms 以下の超低遅延 TTS。

## 特徴
- **Sonic-2**: 135ms 以下・自然な感情表現
- WebSocket ストリーミング対応
- 感情制御（速度・ポジティブ感・驚きなど）
- 音声クローニング（数秒サンプルから複製）

## API
```python
import cartesia
client = cartesia.Cartesia(api_key="KEY")
audio = client.tts.bytes(
    model_id="sonic-2",
    transcript="こんにちは",
    voice={"mode": "id", "id": "VOICE_ID"},
    language="ja"
)
```

## 料金
- Free: 月 100 万文字
- Growth: \$19/月〜（従量）
''',
  'tavus': '''
# Tavus

1本の動画から無数の個人化動画を生成。**CVI** (会話型ビデオ AI) でリアルタイム対話も実現。

## 機能
- **Phoenix-3**: 最高品質リップシンク
- **Personal Replica**: 自分の顔・声でアバター化
- **CVI API**: LLM + WebRTC リアルタイム会話動画

## API
```python
import requests
r = requests.post("https://tavusapi.com/v2/videos",
    headers={"x-api-key": "KEY"},
    json={
        "replica_id": "r9340814e4",
        "script": "こんにちは {name} さん！",
        "variables": {"name": "田中"}
    }
)
```

## 料金
- Developer: 無料（25分/月）
- Starter: \$99/月（100分）
''',
  'synthesia': '''
# Synthesia

50,000+ 企業が使う**エンタープライズ AI 動画プラットフォーム**。評価額 \$1B ユニコーン。

## 特徴
- **230+ アバター**: 多様な人種・スタイル
- **140 言語**: 自動翻訳 + リップシンク同期
- **Personal Avatar**: 5 分録画でアバター化
- **API**: スクリプト → 動画 URL を自動生成

## API
```python
import requests
r = requests.post("https://api.synthesia.io/v2/videos",
    headers={"Authorization": "Bearer KEY"},
    json={
        "slides": [{
            "script": "AI大学へようこそ！",
            "avatar": "anna_costume1_cameraA",
            "avatarSettings": {"voice": "ja-JP-NanamiNeural"}
        }]
    }
)
```

## 料金
- Free: 3本/月（透かし付き）
- Starter: \$29/月（10本）
''',
  'play_ht': '''
# PlayHT

900+ ボイス × 音声クローニングの老舗 TTS プラットフォーム。**Turbo v2** で 75ms の超低遅延。

## モデル
- **PlayHT 3.0 Ultra** — 最高品質・感情制御
- **Turbo v2** — 75ms 超低遅延・エージェント向け
- **Instant Clone** — 数秒サンプルで声複製

## API
```python
from pyht import Client, TTSOptions, Format
client = Client(user_id="UID", api_key="KEY")
options = TTSOptions(voice="VOICE_ID", format=Format.FORMAT_MP3)
for chunk in client.tts("こんにちは！", options):
    f.write(chunk)
```

## 料金
- Free: \$0（月 12,500 文字）
- Creator: \$31.2/月（100 万文字）
''',
  'descript': '''
# Descript

「**テキスト編集で動画を切る**」革新的 AI 動画・音声編集ツール。

## 主な AI 機能
- **Overdub** — 自分の声クローンで言い間違い後修正
- **Underlord** — テキスト削除 → 映像自動削除
- **Studio Sound** — AI ノイズ除去で自宅録音をスタジオ品質に
- **Eye Contact** — 目線を自動補正

## API
```python
import requests
headers = {"Authorization": "Bearer KEY"}
r = requests.post("https://api.descript.com/v2/transcriptions",
    headers=headers,
    json={"upload_id": upload_id, "language": "ja"}
)
print(r.json()["transcript"])
```

## 料金
- Free: \$0（1時間/月）
- Creator: \$40/月（30時間・全 AI 機能）
''',
  'wandb': '''
# Weights & Biases (W&B)

ML 実験管理・LLMOps の**業界標準**。OpenAI・Anthropic・NVIDIA が利用。200 万人の ML エンジニアに支持。

## 製品
- **W&B Runs** — 実験メトリクス・GPU をリアルタイム追跡
- **W&B Sweeps** — ベイズ最適化でハイパラ自動チューニング
- **W&B Weave** — LLM トレーシング・コスト・評価
- **W&B Artifacts** — モデル・データのバージョン管理

## API
```python
import wandb, weave
weave.init("my-llm-app")

@weave.op()
def call_llm(prompt: str) -> str:
    return client.messages.create(...)

wandb.log({"val_loss": 0.12, "accuracy": 0.95})
```

## 料金
- Free: \$0（個人利用）
- Team: \$50/ユーザー/月
''',
  'modal': '''
# Modal Labs

Python デコレータ**1行**でローカル関数をクラウド GPU で実行するサーバーレス基盤。

## 特徴
- `@app.function(gpu=modal.GPU.A100())` — GPU 選択即デプロイ
- `.map()` で 1000 並列ジョブを数行で起動
- 無料枠 \$30/月クレジット（継続）
- アイドル時ゼロ課金

## API
```python
import modal
app = modal.App("inference")

@app.function(gpu=modal.GPU.A10G())
def run(prompt: str) -> str:
    from transformers import pipeline
    return pipeline("text-generation", model="gpt2")(prompt)[0]["generated_text"]

# ローカルから即呼び出し
with app.run():
    print(run.remote("Hello, Modal!"))
```
''',
  'pinecone': '''
# Pinecone

**RAG・セマンティック検索**のデファクト ベクターデータベース。数億ベクターをミリ秒で検索。

## 特徴
- フルマネージド・サーバーレス対応
- ハイブリッド検索（密 + スパース）
- メタデータフィルタリングで精密な絞り込み
- Free プラン: 2GB ストレージ

## API
```python
from pinecone import Pinecone, ServerlessSpec
pc = Pinecone(api_key="KEY")
pc.create_index("ai-university", dimension=1536, metric="cosine",
    spec=ServerlessSpec(cloud="aws", region="us-east-1"))
index = pc.Index("ai-university")
index.upsert(vectors=[{"id": "1", "values": embedding, "metadata": {"text": "..."}}}])
results = index.query(vector=query_emb, top_k=3, include_metadata=True)
```
''',
  'langchain': '''
# LangChain

LLM アプリ構築の**事実上の標準フレームワーク**。GitHub スター 8 万超。Python / JS 両対応。

## 主な機能
- **Chains** — LLM 呼び出しを連結するパイプライン
- **Agents** — ツールを自律選択する ReAct エージェント
- **RAG** — Loader→Splitter→Embeddings→VectorStore→Retriever 標準フロー
- **LangSmith** — 本番 LLM のデバッグ・評価・トレース

## API
```python
from langchain_anthropic import ChatAnthropic
from langchain.chains import RetrievalQA

llm = ChatAnthropic(model="claude-sonnet-4-6")
qa = RetrievalQA.from_chain_type(llm=llm, retriever=vectorstore.as_retriever())
answer = qa.invoke("AI大学の特徴は？")
```

## 料金
- LangChain: OSS 無料
- LangSmith: 月 1 万トレース無料 → \$39/月〜
''',
  'llamaindex': '''
# LlamaIndex

LLM アプリ向け**データフレームワーク**。RAG のデータ取り込み・インデックス構築に特化。600+ 統合。

## 特徴
- **SimpleDirectoryReader** — フォルダ全体を1行で読み込み
- **高度な検索** — HyDE/SubQuestion/Reranker
- **LlamaParse** — PDF・PPT を高精度テキスト化 (1,000ページ/日 無料)
- **LlamaHub** — 600+ ローダー・ツール・エージェント集

## API
```python
from llama_index.core import VectorStoreIndex, SimpleDirectoryReader
from llama_index.llms.anthropic import Anthropic
from llama_index.core import Settings

Settings.llm = Anthropic(model="claude-sonnet-4-6")
docs = SimpleDirectoryReader("./data").load_data()
index = VectorStoreIndex.from_documents(docs)
response = index.as_query_engine().query("AI大学の特徴は？")
```

## 料金
- LlamaIndex OSS: 無料
- LlamaParse: 1,000ページ/日無料 → \$0.003/ページ
''',
  'qdrant': '''
# Qdrant

**Rust 実装のオープンソース・ベクターデータベース**。セルフホスト可能で Pinecone の有力代替。

## 特徴
- Docker 1行でセルフホスト (完全無料)
- ペイロードフィルタリング (任意 JSON メタデータ)
- 名前付きベクター (テキスト+画像マルチモーダル)
- 量子化でメモリ最大 97% 削減

## API
```python
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct

client = QdrantClient(host="localhost", port=6333)
client.recreate_collection("docs", vectors_config=VectorParams(size=1536, distance=Distance.COSINE))
client.upsert("docs", points=[PointStruct(id=1, vector=emb, payload={"text": "..."})])
results = client.search("docs", query_vector=query_emb, limit=5)
```

## 料金
- セルフホスト: 完全無料
- Qdrant Cloud 無料枠: 1GB RAM 永久無料
''',
  'roboflow': '''
# Roboflow

**コンピュータビジョン AI** の構築・デプロイ統合プラットフォーム。YOLO/SAM/Grounding DINO 統合。

## 特徴
- アノテーション → データ拡張 → 学習 → デプロイを一気通貫
- Roboflow Universe: 100,000+ 公開 CV データセット
- Supervision ライブラリで推論結果を可視化
- iOS/Android/Edge デバイスへのエクスポート対応

## API
```python
from roboflow import Roboflow
from ultralytics import YOLO

rf = Roboflow(api_key="KEY")
dataset = rf.workspace("ws").project("proj").version(1).download("yolov8")
model = YOLO("yolov8n.pt")
model.train(data=f"{dataset.location}/data.yaml", epochs=100)
```

## 料金
- Free: 3プロジェクト・1,000枚/月
- Starter: \$249/月
''',
  'lightning_ai': '''
# Lightning AI

**PyTorch Lightning** 開発チームが作るクラウド AI 開発プラットフォーム。ローカル↔クラウドをシームレスに。

## 特徴
- GPU/TPU 学習のボイラープレートを完全排除
- Lightning Fabric: 既存 PyTorch コードを2行でマルチGPU化
- Lightning Studios: クラウド VS Code + GPU を1クリック起動
- Lit-GPT: LLM ファインチューニングのリファレンス実装

## API
```python
import lightning as L

class LitModel(L.LightningModule):
    def training_step(self, batch, batch_idx):
        loss = self.model(batch)
        self.log("train_loss", loss)
        return loss

trainer = L.Trainer(max_epochs=10, accelerator="auto", devices="auto")
trainer.fit(model, dataloader)
```

## 料金
- Free: CPU Studio 無料・GPU 10時間/月
- Pro: \$39/月 (GPU 100時間)
''',
  'weave': '''
# W&B Weave

W&B の**LLM オブザーバビリティ**ツール。LLM チェーン・エージェントの動作を完全可視化。

## 特徴
- @weave.op() デコレータで任意関数を自動トレース
- Evaluations: カスタムスコアラーでモデル出力品質を数値化
- LangChain/LlamaIndex/Anthropic/OpenAI すべて対応
- W&B ダッシュボードと統合 (実験管理との連携)

## API
```python
import weave
from anthropic import Anthropic

weave.init("ai-university")
client = Anthropic()

@weave.op()
def ask_claude(question: str) -> str:
    response = client.messages.create(
        model="claude-sonnet-4-6", max_tokens=1024,
        messages=[{"role": "user", "content": question}]
    )
    return response.content[0].text

answer = ask_claude("RAGとは？")
# → Weave ダッシュボードでトレース確認
```

## 料金
- Free: 月 100GB・チーム3人
- Pro: \$50/人/月〜
''',
  'oxen_ai': '''
# Oxen AI

**ML データの Git**。画像/CSV/Parquet など大容量 ML データセットをバージョン管理。

## 特徴
- Git 同様のコマンド (clone/push/pull/branch/merge)
- 部分クローン: 必要ファイルのみ取得
- CSV/Parquet の行レベル diff 可視化
- Oxen Hub: 100,000+ 公開データセット

## API
```bash
oxen init && oxen remote add origin https://hub.oxen.ai/org/dataset
oxen add train.csv images/
oxen commit -m "v1.0 initial dataset"
oxen push origin main
oxen diff train.csv  # 行レベルの変更差分を確認
```

## 料金
- OSS CLI: 完全無料
- Oxen Hub 無料: 10GB
- Pro: \$15/月 (100GB)
''',
  'predibase': '''
# Predibase

**LoRA ファインチューニング特化**プラットフォーム。LoRAX で 1 GPU に 1000+ カスタムモデルを同時サーブ。

## 特徴
- LoRAX: 1 GPU でマルチ LoRA アダプターを動的切り替え
- Ludwig 統合: 設定ファイルベースで ML パイプライン構築
- OpenAI 互換 API でカスタムモデルを公開
- Serverless LoRA: 使用時のみ課金

## API
```python
from predibase import Predibase

pb = Predibase(api_token="TOKEN")
adapter = pb.adapters.create(
    config={"base_model": "meta-llama/Llama-3.1-8B-Instruct", "fine_tuning_type": "lora"},
    dataset=dataset, name="ai-univ-expert"
)
adapter.wait_for_completion()
```

## 料金
- Developer: 無料
- Pro: \$499/月 (LoRAX 本番)
''',
  'argilla': '''
# Argilla

**LLM アノテーション・フィードバック収集** OSS。RLHF/SFT データ構築に特化。

## 特徴
- FeedbackDataset: LLM 出力の A/B 比較・評価フォーム
- Hugging Face 統合: HF Hub への直接プッシュ
- チームアノテーション: Inter-annotator Agreement 計測
- Docker 1行でセルフホスト

## API
```python
import argilla as rg
rg.init(api_url="http://localhost:6900", api_key="admin.apikey")

dataset = rg.FeedbackDataset(fields=[rg.TextField(name="question"),
    rg.TextField(name="answer")],
    questions=[rg.RatingQuestion(name="accuracy", values=[1,2,3,4,5])])
dataset.push_to_argilla(name="claude-eval", workspace="default")
```

## 料金
- OSS セルフホスト: 完全無料
- Cloud 無料枠あり
''',
  'dify': '''
# Dify

**ノーコード LLM ワークフロービルダー** OSS。GitHub スター 80,000+。非エンジニアも AI アプリを構築可能。

## 特徴
- ビジュアル GUI でドラッグ&ドロップ RAG 構築
- Knowledge Base: PDF/Web/CSV アップロードで即 RAG
- 全主要 LLM 対応 (Claude/GPT/Gemini/Llama)
- Docker Compose で 5 分セルフホスト

## API
```python
from dify_client import ChatClient

client = ChatClient(api_key="YOUR_KEY")
response = client.create_chat_message(
    query="AI大学のベクターDBを比較してください",
    user="user123", conversation_id="", response_mode="blocking"
)
print(response["answer"])
```

## 料金
- OSS セルフホスト: 完全無料
- Cloud 無料: 200 メッセージ/月
- Professional: \$59/月
''',
  'baichuan': '''
# Baichuan AI (百川智能)

元 Sogou CEO 創業の中国 AI スタートアップ。汎用 LLM から**医療 AI に特化**し、Baichuan-M3 (235B) で **HealthBench Hard #1** を達成。

## Baichuan-M3（医療特化・最新）
- 235B パラメータ (Qwen3 アーキテクチャ)
- 医療ドメイン特化 RL で訓練
- HealthBench Hard #1（2026年）
- Apache 2.0 / HuggingFace 公開

## アクセス方法
- **Dr7.ai API**: Baichuan-M3 医療エンドポイント
- **HuggingFace**: 自己ホスト（W4 量子化対応）
- **公式 API**: Baichuan4 汎用モデル

## 活用
- 医療 QA / 症状説明 / 薬剤情報
- 中国語医療コンテンツ生成
- 臨床文書の下書き
''',
  'radixark': '''
# RadixArk (SGLang)

**SGLang** (LLM 推論エンジン) のメンテナンス企業。Berkeley Sky Computing Lab 発 OSS からのスピンアウト。

## RadixAttention
- KV キャッシュを会話ターン間で共有
- マルチターン会話で **5–10x スループット改善**
- xAI (Grok 4) / DeepSeek / Cursor などが本番採用

## 採用実績
GitHub 16k+ stars。Tier 1 AI 企業多数。

## API
```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:30000/v1", api_key="EMPTY")
response = client.chat.completions.create(
    model="meta-llama/Llama-3.3-70B",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

## 資金調達
- Series A: \$400M valuation (2026-01, Accel リード)
- CEO: Ying Sheng (元 xAI research scientist)
''',
  'stepfun': '''
# StepFun (阶跃星辰)

元 Microsoft VP 創業の上海発スタートアップ。**Sparse MoE (196B / 11B 活性化)** × **256K context** × **OpenAI 互換 API** の組み合わせで高性能・低コストを実現。

## Step 3.5 Flash（推奨）
- MoE: 196B 総パラメータ、11B のみ活性化
- コンテキスト: 256K tokens
- 料金: \$0.10 / 1M input、\$0.30 / 1M output
- Tool Calling ネイティブ対応
- リリース: 2026年1月29日

## OpenAI 互換
```python
client = OpenAI(
  api_key="YOUR_KEY",
  base_url="https://api.stepfun.com/v1"
)
```

## 強み
- コーディング・数学・推論でフロンティア水準
- OpenAI からの移行コストがほぼゼロ
- マルチモーダル（テキスト・画像・動画・音楽）
''',
  'decart': '''
# Decart — リアルタイム生成動画 AI (\$3.1B 評価額)

イスラエル発スタートアップ。世界初のリアルタイム動画生成モデル
**Oasis** (AI Minecraft) と **MirageLSD** (ライブ動画スタイル変換) を提供。
2025-08 Series B で \$100M 調達 (累計 \$153M+ / 評価額 \$3.1B)。

## 主力モデル
- **Oasis** (2024-11): playable な AI 生成 Minecraft 風ゲーム。3 日で 100 万ユーザー
- **MirageLSD** (2025-夏): <40ms レイテンシでライブ動画を別スタイルに変換

## 既存動画 AI との違い
| 観点 | Decart | Runway/Luma 等 |
|------|--------|----------------|
| 生成方式 | 連続リアルタイム | 5〜10 秒バッチ |
| レイテンシ | <40ms | 10 秒〜数分 |
| 入力 | ライブ動画 | テキスト・画像 |

## 試す
- Mirage デモ: https://mirage.decart.ai/
- Oasis デモ: https://oasis.decart.ai/welcome
- Mirage API は 2026 年内公開予定 (waitlist 受付中)
''',
  'goodfire': '''
# Goodfire — AI Interpretability の最前線 (\$1.25B 評価額)

サンフランシスコ拠点。AI モデル内部のニューロンを直接読み解き編集可能にする
**Ember** プラットフォームを開発。Anthropic が Series A に出資した AI 安全性研究の最前線。
2026-02 に Series B \$150M 調達 (累計 \$207M / 評価額 \$1.25B 🦄)。

## 既存 129 社との差別化
| 観点 | Goodfire | LLM/動画/音声 プロバイダー |
|------|----------|---------------------------|
| カテゴリ | Interpretability (解釈可能性) | 生成・推論 |
| 対象 | 既存モデルの「内部」を解読 | 新モデルを「外部」呼出 |
| 出力 | ニューロン活性化マップ・特徴量 | テキスト/画像/動画/音声 |

## 主要技術
- **Sparse Autoencoders (SAE)**: LLM 隠れ層の重ね合わせを単一概念に分離
- **Feature Steering**: ファインチューニング不要で特徴を直接 ON/OFF
- **OSS SAE 重み**: Llama 3.1 8B 全層が HuggingFace で無償公開

## 最新成果 (2026-02)
**Alzheimer's biomarker 発見** — 基盤モデル逆解析による自然科学領域での
重大発見の最初の例 (Prima Mente との共同研究)。

## 試す
- HuggingFace OSS: https://huggingface.co/goodfire
- Blog: https://www.goodfire.ai/blog
- Ember API は 2026-02 から partner-only (個別審査)
''',
  'nous_research': '''
# Nous Research — 分散学習 Psyche × オープン Hermes (\$65M Paradigm)

サンフランシスコ拠点のオープン AI 研究組織。
**Hermes** ファミリー (Llama 系 fine-tune) を OSS で公開。
2025 年に Paradigm リードで \$65M 調達。

## 主力モデル
- **Hermes 4 405B**: Llama 3.1 405B base / reasoning 強化 / OpenRouter \$0.80-2.00/M
- **Hermes 4.3 Seed 36B**: 🌐 **Psyche 分散学習で訓練された最初の生産モデル**
- **Hermes 3 Llama 3.1 70B/8B**: OSS 重み HuggingFace 公開

## 既存 130 社との差別化
| 観点 | Nous | 既存大手 |
|------|------|----------|
| 学習方式 | 🌐 Psyche 分散 (blockchain) | 中央集権 GPU クラスタ |
| アライメント | ユーザー側で steering | RLHF 固定 |
| 検閲 | 最小限 (uncensored) | 強い content filter |

## Psyche Network
- インターネット越しに GPU を協調させる学習プロトコル
- 巨大企業独占の基盤モデル訓練を打破するインフラ
- GPU 提供者は報酬獲得可

## 試す
- OpenRouter: https://openrouter.ai/nousresearch
- HuggingFace OSS: https://huggingface.co/NousResearch
- Discord (30,000+ 名): https://discord.gg/jqVphNsB4H
- Hermes 4 Tech Report: https://arxiv.org/pdf/2508.18255
''',
  'prime_intellect': '''
# Prime Intellect — 分散 RL で 106B MoE を訓練 (INTELLECT-3 / AIME 90.8%)

2024 年設立、**「Open Superintelligence Stack」** を掲げる AI インフラ企業。
GPU マーケットプレイス・分散 RL 基盤 (prime-rl)・INTELLECT 系列オープンモデルを垂直統合。

## 主力モデル (2025-12 リリース)
- **INTELLECT-3**: 106B MoE (12B active) / 131K ctx / **AIME 2024 90.8%**
- **INTELLECT-2**: 32B / 初の分散 RL permissionless GPU 訓練
- **INTELLECT-1**: 10B / 初の分散 SFT 実証

## 既存 131 社との差別化
| 観点 | Prime Intellect | Nous Research | 既存大手 |
|------|----------------|---------------|---------|
| 学習方式 | 🌐 グローバル分散 RL | Psyche 分散 SFT | 中央集権 GPU |
| 価格 | 💰 \$0.20/1M in (INTELLECT-3) | \$0.20-2.00/M | \$5-15/M |
| GPU マーケット | 🖥️ H200 \$3.99/hr pay-as-you-go | なし | なし |

## Why？
- RL スケーリング則の frontier-class 実証 (512×H200 で訓練)
- 「Too cheap to meter」ビジョン — AI 計算のコモディティ化
- prime-rl は fault-tolerant async RL を OSS 化

## 試す
- OpenRouter: https://openrouter.ai/primeintellect
- HuggingFace OSS: https://huggingface.co/PrimeIntellect
- prime-rl GitHub: https://github.com/PrimeIntellect-ai/prime-rl
- Tech Report: https://arxiv.org/abs/2512.16144
- GPU マーケット: https://www.primeintellect.ai/dashboard/
''',
};

// ─────────────────────────────────────────────────────────────────────────────
// ページ本体
// ─────────────────────────────────────────────────────────────────────────────

class AiUniversityPage extends StatefulWidget {
  const AiUniversityPage({super.key});

  @override
  State<AiUniversityPage> createState() => _AiUniversityPageState();
}

class _AiUniversityPageState extends State<AiUniversityPage>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  List<String> _providers = [];
  Map<String, List<Map<String, dynamic>>> _content = {};
  bool _loading = true;
  String? _error;
  TabController? _tabController;
  final Set<String> _answeredQuizzes = {};
  static const String _prefsKey = 'ai_univ_answered_quizzes';
  final _shareCardKey = GlobalKey();
  final _fsrsService = AiFsrsService();
  final _learnerProfileService = AiLearnerProfileService();
  final Map<String, DateTime> _fsrsNextDue = {};
  final Map<String, String> _quizExplanations = {};
  final Map<String, bool> _quizEvaluating = {};
  final Map<String, List<FsrsCard>> _fsrsDue = {};
  final Set<String> _fsrsDueRequested = {};

  @override
  void initState() {
    super.initState();
    _fetchContent();
    _loadAnsweredQuizzes();
  }

  Future<void> _loadAnsweredQuizzes() async {
    // ローカル (SharedPreferences) から読み込み
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey) ?? '';
    final localSet = saved.isNotEmpty ? saved.split(',').toSet() : <String>{};

    // Supabase からクロスデバイス記録を取得してマージ
    final user = _supabase.auth.currentUser;
    Set<String> remoteSet = {};
    if (user != null) {
      try {
        final rows = await _supabase
            .from('ai_university_scores')
            .select('provider_id')
            .eq('user_id', user.id)
            .eq('quiz_correct', true)
            .timeout(const Duration(seconds: 5));
        remoteSet = (rows as List)
            .cast<Map<String, dynamic>>()
            .map((r) => r['provider_id'] as String)
            .toSet();
        final localOnly = localSet.difference(remoteSet);
        if (localOnly.isNotEmpty) {
          final synced = await _syncLocalScoresToSupabase(localOnly);
          remoteSet = remoteSet.union(synced);
        }
      } catch (_) {
        // Supabase 取得失敗はサイレント — ローカルデータを使用
      }
    }

    final merged = localSet.union(remoteSet);
    if (mounted && merged.isNotEmpty) {
      setState(() => _answeredQuizzes.addAll(merged));
      // ローカルにも同期して次回起動時のオフライン対応
      if (merged.length > localSet.length) {
        await prefs.setString(_prefsKey, merged.join(','));
      }
    }
  }

  void _loadFsrsDue(String provider) {
    if (_fsrsDueRequested.contains(provider)) return;
    _fsrsDueRequested.add(provider);
    _fsrsService.getNextCards(provider, limit: 5).then((cards) {
      if (mounted && cards.isNotEmpty) {
        setState(() => _fsrsDue[provider] = cards);
      }
    });
  }

  Future<void> _saveAnsweredQuizzes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _answeredQuizzes.join(','));
  }

  Future<Set<String>> _syncLocalScoresToSupabase(
    Set<String> providerIds,
  ) async {
    final synced = <String>{};
    for (final providerId in providerIds) {
      final ok = await _recordQuizScoreToSupabase(providerId);
      if (ok) synced.add(providerId);
    }
    return synced;
  }

  Future<bool> _recordQuizScoreToSupabase(String providerId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      await _supabase.functions.invoke(
        'ai-hub',
        body: {
          'action': 'university.record_score',
          'provider_id': providerId,
          'quiz_correct': true,
        },
      );
      await _supabase.rpc(
        'update_ai_university_streak',
        params: {'p_user_id': user.id},
      );
      return true;
    } catch (_) {
      try {
        await _supabase.from('ai_university_scores').upsert(
          {
            'user_id': user.id,
            'provider_id': providerId,
            'quiz_correct': true,
            'studied_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id,provider_id',
        );
        await _supabase.rpc(
          'update_ai_university_streak',
          params: {'p_user_id': user.id},
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<void> _shareProgress() async {
    final count = _answeredQuizzes.length;
    final total = _quizzes.length;
    const url = 'https://my-web-app-b67f4.web.app/ai-university';

    // A/B/C テスト: 3バリエーションをランダム選択
    final variant = Random().nextInt(3);
    final String text;
    switch (variant) {
      case 0:
        // A: 正解数フォーカス
        text = '🎓 AI 大学でクイズ $count/$total 問正解！\n'
            'Google・OpenAI・Anthropic など主要AIを体系的に学習中。\n'
            '$url';
      case 1:
        // B: プロバイダー制覇フォーカス
        text = '🏆 AI 大学で $count 社のAIプロバイダーを制覇中！\n'
            'Google・OpenAI・DeepSeek・Mistral など $total 社を比較学習できます。\n'
            '$url';
      default:
        // C: ランキング/競争フォーカス
        text = '📊 AI 大学ランキングに挑戦中！正解 $count 問達成 🎯\n'
            '複数のAIを使い比べながら正しく理解。ランキングで競おう！\n'
            '$url';
    }

    // Web: OS native share sheet omits X on Windows/desktop → open X intent
    // directly. Native platforms keep the familiar SharePlus flow.
    if (kIsWeb) {
      final intent = Uri.parse(
        'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}',
      );
      await launchUrl(intent, mode: LaunchMode.externalApplication);
      return;
    }
    await SharePlus.instance.share(ShareParams(text: text));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SNS シェアカード — OGP スタイル画像プレビュー + ダウンロード
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _showShareCardDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // カードプレビュー — FittedBox でモバイル幅に収める (キャプチャは360px維持)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: RepaintBoundary(
                  key: _shareCardKey,
                  child: _buildShareCard(),
                ),
              ),
              // ボタン行
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('画像を保存'),
                        onPressed: _captureAndDownload,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text('テキストでシェア'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _shareProgress();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareCard() {
    final count = _answeredQuizzes.length;
    final total = _providers.isNotEmpty ? _providers.length : _quizzes.length;

    return Container(
      width: 360,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF1E1E1E)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ヘッダー
          Row(
            children: [
              const Text(
                '🎓',
                style: TextStyle(
                  fontSize: 32,
                  height: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI 大学',
                    style: TextStyle(
                      color: Color(0xFFE5E7EB),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    '自分株式会社',
                    style: TextStyle(
                      color: const Color(0xFFE5E7EB).withValues(alpha: 0.6),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: const Color(0xFFE5E7EB).withValues(alpha: 0.24)),
          const SizedBox(height: 16),
          // 達成数メッセージ
          Text(
            '$count 社のAIを\n学習しました！',
            style: const TextStyle(
              color: Color(0xFFE5E7EB),
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 16),
          // プロバイダーバッジ行
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _providers.map((id) {
              final m = _meta(id);
              final learned = _answeredQuizzes.contains(id);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: learned
                      ? m.color.withValues(alpha: 0.71)
                      : const Color(0xFFE5E7EB).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${m.emoji} ${m.name}',
                  style: TextStyle(
                    fontSize: 11,
                    color: learned
                        ? const Color(0xFFE5E7EB)
                        : const Color(0xFFE5E7EB).withValues(alpha: 0.38),
                    fontWeight: learned ? FontWeight.bold : FontWeight.normal,
                    height: 1.5,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // クイズ達成バー
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFFFC107).withValues(alpha: 0.31),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  '📊',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'クイズ正解: $count / $total 問',
                  style: const TextStyle(
                    color: Color(0xFFFFC107),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'my-web-app-b67f4.web.app',
            style: TextStyle(
              color: Color(0xFFB0B0B0),
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureAndDownload() async {
    try {
      final boundary = _shareCardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();
      final b64 = base64Encode(pngBytes);
      final a = web_api.HTMLAnchorElement()
        ..href = 'data:image/png;base64,$b64'
        ..download = 'ai-university-card.png';
      web_api.document.body?.append(a);
      a.click();
      a.remove();
    } catch (_) {
      // キャプチャ失敗はサイレント
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchContent() async {
    try {
      final rows = await _supabase
          .from('ai_university_content')
          .select()
          .eq('is_active', true)
          .order('sort_order')
          .timeout(const Duration(seconds: 10));

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final provider = row['provider'] as String;
        (grouped[provider] ??= []).add(row);
      }

      // DB が空なら _providerMeta の全キーをフォールバックで表示
      final providers =
          grouped.isEmpty ? _providerMeta.keys.toList() : grouped.keys.toList();

      _tabController?.dispose();
      final tc = TabController(length: providers.length, vsync: this);
      tc.addListener(() {
        if (!tc.indexIsChanging && tc.index < providers.length) {
          _loadFsrsDue(providers[tc.index]);
        }
      });
      if (providers.isNotEmpty) _loadFsrsDue(providers[0]);
      if (mounted) {
        setState(() {
          _providers = providers;
          _content = grouped;
          _loading = false;
          _error = null;
          _tabController = tc;
        });
      }
    } catch (e) {
      if (mounted) {
        final providers = _providerMeta.keys.toList();
        _tabController?.dispose();
        setState(() {
          _loading = false;
          _error = e.toString();
          _providers = providers;
          _tabController = TabController(length: providers.length, vsync: this);
        });
      }
    }
  }

  _ProviderMeta _meta(String id) => _providerMeta[id] ?? _unknownMeta;

  Future<void> _awardQuizPoints(String providerId) async {
    if (_answeredQuizzes.contains(providerId)) return;
    setState(() => _answeredQuizzes.add(providerId));
    _saveAnsweredQuizzes();
    context
        .read<GamificationService>()
        .awardPoints(50, reason: 'AI大学クイズ正解: ${_meta(providerId).name}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 正解！ +50pt — ${_meta(providerId).name}'),
        duration: const Duration(seconds: 2),
      ),
    );
    // Supabase にスコアを記録 (RLS: users_own_scores で直接書き込み可)
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('この端末には保存しました。共有ランキングへの反映はログイン後です。'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    if (!await _recordQuizScoreToSupabase(providerId)) {
      try {
        await _supabase.from('ai_university_scores').upsert(
          {
            'user_id': user.id,
            'provider_id': providerId,
            'quiz_correct': true,
            'studied_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id,provider_id',
        );
        // ストリーク更新 (DB関数で連続学習日数を計算)
        await _supabase.rpc(
          'update_ai_university_streak',
          params: {'p_user_id': user.id},
        );
      } catch (_) {
        // スコア保存失敗はサイレント — ローカルの SharedPreferences は保持済み
      }
    }
    // FSRS grade=3 (Good) で次回出題日を記録
    final result = await _fsrsService.gradeCard(
      provider: providerId,
      questionId: providerId,
      grade: 3,
    );
    if (mounted) {
      setState(() => _fsrsNextDue[providerId] = result.nextDue);
    }
    // Memory Agent プロファイル更新 (バックグラウンド)
    _learnerProfileService.updateProfile(
      sessionSummary: 'クイズ正解: $providerId',
      scores: [
        {'provider': providerId, 'correct': true},
      ],
    ).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final tc = _tabController;

    if (_loading || tc == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI 大学')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 大学'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: const Color(0xFFE5E7EB),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'ランキング',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AiUniversityRankingPage(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.science),
            tooltip: 'API実験室',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ApiPlaygroundPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: '実装ステータス一覧',
            onPressed: () =>
                Navigator.pushNamed(context, '/ai-provider-status'),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'シェアカード',
            onPressed: _showShareCardDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'コンテンツを更新',
            onPressed: () {
              setState(() => _loading = true);
              _fetchContent();
            },
          ),
        ],
        bottom: TabBar(
          controller: tc,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: const Color(0xFFE5E7EB),
          labelColor: const Color(0xFFE5E7EB),
          unselectedLabelColor: const Color(0xFFB0B0B0),
          tabs: _providers.map((id) {
            final m = _meta(id);
            return Tab(text: '${m.emoji} ${m.name}');
          }).toList(),
        ),
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              color: const Color(0xFFFFC107).withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: Color(0xFFFFC107),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'DBから取得できませんでした。フォールバック表示中。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _loading = true);
                      _fetchContent();
                    },
                    child: const Text('再試行'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: tc,
              children: _providers
                  .map((id) => _buildProviderTab(id, isDark))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderTab(String providerId, bool isDark) {
    final m = _meta(providerId);
    final rows = _content[providerId];
    final surface = isDark ? const Color(0xFF1E1E1E) : const Color(0xFF1E1E1E);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildProviderHeader(providerId, m, rows),
        const SizedBox(height: 12),
        if (rows != null && rows.isNotEmpty)
          ...rows.map((row) => _buildContentCard(row, isDark, surface))
        else
          _buildFallbackCard(providerId, surface),
        const SizedBox(height: 16),
        _buildQuizCard(providerId, m),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildProviderHeader(
    String id,
    _ProviderMeta m,
    List<Map<String, dynamic>>? rows,
  ) {
    String? updatedAt;
    if (rows != null && rows.isNotEmpty) {
      final ts = rows.first['updated_at'];
      if (ts != null) {
        try {
          final dt = DateTime.parse(ts.toString()).toLocal();
          updatedAt =
              '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} 更新';
        } catch (_) {}
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            m.color.withValues(alpha: 0.20),
            m.color.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            m.emoji,
            style: const TextStyle(
              fontSize: 32,
              height: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  style: const TextStyle(
                    color: Color(0xFFE5E7EB),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
                if (updatedAt != null)
                  Text(
                    updatedAt,
                    style: TextStyle(
                      color: const Color(0xFFE5E7EB).withValues(alpha: 0.7),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                if (rows == null || rows.isEmpty)
                  const Text(
                    'フォールバック表示',
                    style: TextStyle(
                      color: Color(0xFFB0B0B0),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
          if (m.officialUrl.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_new, color: Color(0xFFE5E7EB)),
              tooltip: '公式サイト',
              onPressed: () => _launchUrl(m.officialUrl),
            ),
        ],
      ),
    );
  }

  // MarkdownBody 共通スタイル (ダーク専用)
  static final MarkdownStyleSheet _mdStyle = MarkdownStyleSheet(
    p: const TextStyle(color: Color(0xFFE5E7EB), height: 1.7),
    h1: const TextStyle(
      color: Color(0xFFE5E7EB),
      fontSize: 20,
      fontWeight: FontWeight.bold,
      height: 1.4,
    ),
    h2: const TextStyle(
      color: Color(0xFFB0B0B0),
      fontSize: 17,
      fontWeight: FontWeight.bold,
      height: 1.4,
    ),
    h3: const TextStyle(
      color: Color(0xFF707070),
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    strong: const TextStyle(
      color: Color(0xFFE5E7EB),
      fontWeight: FontWeight.bold,
      height: 1.5,
    ),
    em: const TextStyle(
      color: Color(0xFFB0B0B0),
      fontStyle: FontStyle.italic,
      height: 1.5,
    ),
    listBullet: const TextStyle(
      color: Color(0xFFB0B0B0),
      height: 1.5,
    ),
    code: const TextStyle(
      color: Color(0xFF81C784),
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.5,
    ),
    blockquote: const TextStyle(
      color: Color(0xFFB0B0B0),
      height: 1.5,
    ),
  );

  Widget _buildContentCard(
    Map<String, dynamic> row,
    bool isDark,
    Color surface,
  ) {
    final category = row['category'] as String? ?? '';
    final title = row['title'] as String? ?? '';
    final content = row['content'] as String? ?? '';
    final sourceUrl = row['source_url'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: surface,
      child: ExpansionTile(
        backgroundColor: surface,
        collapsedBackgroundColor: surface,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFFE5E7EB),
            height: 1.5,
          ),
        ),
        subtitle: Text(
          _categoryLabel(category),
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFFB0B0B0),
            height: 1.5,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarkdownBody(
                  data: content,
                  styleSheet: _mdStyle,
                  onTapLink: (_, href, __) {
                    if (href != null) _launchUrl(href);
                  },
                ),
                if (sourceUrl != null && sourceUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('出典を開く'),
                    onPressed: () => _launchUrl(sourceUrl),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackCard(String providerId, Color surface) {
    final markdown = _fallback[providerId] ??
        '## ${_meta(providerId).name}\n\nコンテンツは準備中です。\n\n毎週月曜の AI 大学更新タスクで DB が自動更新されます。';
    return Card(
      color: surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: MarkdownBody(
          data: markdown,
          styleSheet: _mdStyle,
          onTapLink: (_, href, __) {
            if (href != null) _launchUrl(href);
          },
        ),
      ),
    );
  }

  Widget _buildQuizCard(String providerId, _ProviderMeta m) {
    final quiz = _quizzes[providerId];
    if (quiz == null) return const SizedBox.shrink();

    final answered = _answeredQuizzes.contains(providerId);
    final dueCards = _fsrsDue[providerId] ?? [];

    return Card(
      color: m.color.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: m.color.withValues(alpha: 0.31)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dueCards.isNotEmpty) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.refresh,
                      color: Color(0xFFFF6B35),
                      size: 15,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '今日の復習 ${dueCards.length}件',
                      style: const TextStyle(
                        color: Color(0xFFFF6B35),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Icon(Icons.quiz, color: m.color),
                const SizedBox(width: 8),
                Text(
                  '${m.name} クイズ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: m.color,
                    height: 1.5,
                  ),
                ),
                if (answered) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF4CAF50),
                    size: 18,
                  ),
                  const Text(
                    ' +50pt',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              quiz.question,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(quiz.options.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: m.color.withValues(alpha: 0.39)),
                    minimumSize: const Size(double.infinity, 44),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: answered
                      ? null
                      : () async {
                          if (i == quiz.correct) {
                            await _awardQuizPoints(providerId);
                          } else {
                            final result = await _fsrsService.gradeCard(
                              provider: providerId,
                              questionId: providerId,
                              grade: 1,
                            );
                            if (mounted) {
                              setState(() {
                                _fsrsNextDue[providerId] = result.nextDue;
                                _quizEvaluating[providerId] = true;
                              });
                            }
                            try {
                              final resp = await _supabase.functions.invoke(
                                'ai-hub',
                                body: {
                                  'action': 'quiz.explain',
                                  'question': quiz.question,
                                  'user_answer': quiz.options[i],
                                  'correct_answer': quiz.options[quiz.correct],
                                  'provider': providerId,
                                },
                              );
                              final data = resp.data as Map<String, dynamic>?;
                              final explanation =
                                  data?['explanation'] as String? ?? '';
                              if (mounted) {
                                setState(() {
                                  _quizExplanations[providerId] = explanation;
                                  _quizEvaluating[providerId] = false;
                                });
                              }
                            } catch (_) {
                              if (mounted) {
                                setState(
                                  () => _quizEvaluating[providerId] = false,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('不正解。もう一度試してください。'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: Text('${_optionLabel(i)}  ${quiz.options[i]}'),
                ),
              );
            }),
            // FSRS 次回出題バッジ
            if (_fsrsNextDue.containsKey(providerId)) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D5AFE).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF3D5AFE).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '次回: ${AiFsrsService.nextDueLabel(_fsrsNextDue[providerId]!)}',
                  style: const TextStyle(
                    color: Color(0xFF3D5AFE),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            // Claude 解説カード
            if (_quizEvaluating[providerId] == true) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '解説を生成中...',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ] else if (_quizExplanations.containsKey(providerId)) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Color(0xFFFF6B35),
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '解説',
                          style: TextStyle(
                            color: Color(0xFFFF6B35),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _quizExplanations[providerId]!,
                      style: const TextStyle(fontSize: 13, height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _categoryLabel(String category) {
    const labels = {
      'overview': '概要',
      'models': 'モデル一覧',
      'api': 'API / SDK',
      'pricing': '料金',
      'news': '最新ニュース',
      'tutorial': 'チュートリアル',
    };
    return labels[category] ?? category;
  }

  String _optionLabel(int i) {
    const labels = ['A', 'B', 'C', 'D'];
    return i < labels.length ? labels[i] : '${i + 1}';
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
