import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // MarkdownBodyを使用するために必要
import 'package:my_web_app/pages/api_playground_page.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/gamification_service.dart';
import '../services/theme_service.dart';

class GeminiUniversityV2Page extends StatefulWidget {
  const GeminiUniversityV2Page({super.key});

  @override
  State<GeminiUniversityV2Page> createState() => _GeminiUniversityV2PageState();
}

class _GeminiUniversityV2PageState extends State<GeminiUniversityV2Page>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _completedModuleIds = {};
  final Map<String, double> _readingProgress = {}; // 各モジュールの読了率

  // Curriculum Data
  final List<CourseModule> _modules = [
    CourseModule(
      id: 'ai_overview',
      title: '現代AI 基礎概論',
      description: '主要なAIモデル（GPT, Claude, Gemini等）の基本を学ぶ',
      icon: Icons.auto_awesome,
      content: '現代のAI環境は、複数の強力なモデルが競い合っています。\n\n'
          '【主要なAIモデルファミリー】\n'
          '1. **OpenAI (GPT-4o/o1)**: 高い汎用性と推論能力。業界のスタンダード。\n'
          '2. **Anthropic (Claude 3.5 Sonnet)**: 自然な文章表現と高いコーディング能力、安全性に定評。\n'
          '3. **Google (Gemini 2.5)**: 圧倒的なロングコンテキストとGoogleエコシステムとの連携。\n'
          '4. **DeepSeek (V3/R1)**: 非常に高いコストパフォーマンスと推論特化モデル。\n'
          '5. **xAI (Grok-3)**: リアルタイム情報へのアクセスと自由な表現。\n\n'
          '各モデルには得意分野があり、用途に応じて使い分けることが重要です。',
      quiz: Quiz(
        question: '自然な文章表現やコーディング能力に定評があり、Anthropic社が開発しているモデルは？',
        options: ['GPT-4', 'Claude 3.5', 'Gemini', 'Grok'],
        correctIndex: 1,
      ),
      labContent: '''
### ハンズオン：モデルの使い分け

以下のコードは、Python SDKを使用してモデルを指定する例です。

```python
import google.generativeai as genai

# 速度重視なら Flash
model_flash = genai.GenerativeModel('gemini-2.0-flash')
# 精度重視なら Pro
model_pro = genai.GenerativeModel('gemini-2.5-pro')
```''',
      officialDocs: [
        {
          'title': 'OpenAI Documentation',
          'url': 'https://platform.openai.com/docs/',
        },
        {
          'title': 'Anthropic Claude Docs',
          'url': 'https://docs.anthropic.com/',
        },
      ],
    ),
    CourseModule(
      id: 'gemini_model_specs',
      title: 'モデル仕様スペック',
      description: '各モデルのトークン上限やThinking機能の対応状況',
      icon: Icons.table_chart,
      content: '''
### Gemini モデル仕様一覧 (2026/1/21現在)

主要なモデルのスペック比較です。特に**Gemini 2.5**シリーズの出力トークン上限の大幅な増加と、**Thinking**パラメータへの対応が特徴です。

| モデル名 | バージョン | 説明 | 入力トークン | 出力トークン | Thinking |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Gemini 2.5 Flash** | 1 | 2025年6月リリース。最大100万トークンをサポートする中規模マルチモーダルモデル。 | 1,048,576 | 65,536 | **TRUE** |
| **Gemini 2.5 Pro** | 2.5 | 2025年6月17日リリース。安定版。 | 1,048,576 | 65,536 | **TRUE** |
| **Gemini 2.0 Flash** | 2 | Gemini 2.0 フラッシュ (旧世代)。 | 1,048,576 | 8,192 | - |
| **Embedding Gecko** | 1 | テキストの分散表現を取得する。 | 1,024 | 1 | - |

**用語解説:**
* **Thinking**: モデルが回答を出力する前に「思考プロセス」を経ることで、より論理的で正確な回答を生成する機能です。
''',
      quiz: Quiz(
        question: 'Gemini 2.5 Flash の出力トークン上限（Output Token Limit）は何トークンですか？',
        options: ['4,096', '8,192', '32,768', '65,536'],
        correctIndex: 3,
      ),
      officialDocs: [
        {
          'title': 'Gemini Models',
          'url': 'https://ai.google.dev/models/gemini',
        },
      ],
    ),
    CourseModule(
      id: 'prompt_design',
      title: 'プロンプト設計',
      description: '効果的なプロンプトを作成するためのベストプラクティス',
      icon: Icons.edit_note,
      content: 'AIから最適な回答を引き出すには、プロンプトの設計が極めて重要です。\n\n'
          '【プロンプト設計のヒント】\n'
          '1. **明確な指示**: AIに何をさせたいかを具体的に記述します。\n'
          '2. **役割を与える (Persona)**: 「あなたは熟練のマーケターです」のように、AIの役割を指定します。\n'
          '3. **例を示す (Few-shot)**: 期待する出力形式の例をいくつか提示します。\n'
          '4. **段階的に考えさせる (Chain of Thought)**: 複雑な問題は、ステップバイステップで考えさせると精度が向上します。\n'
          '5. **出力形式を指定する**: JSON、Markdown、箇条書きなど、希望の形式を明確に指示します。',
      quiz: Quiz(
        question: 'AIに役割を与えるプロンプト手法を何と呼びますか？',
        options: ['Few-shot', 'Chain of Thought', 'Persona', 'Format'],
        correctIndex: 2,
      ),
      labContent: '''
### 実践：Chain of Thought プロンプト

```text
以下の数学の問題を、ステップバイステップで解いてください。
最後に必ず【結論】として答えを書いてください。

問題：リンゴが3個あります。2個追加し、その後半分を友達にあげました。
今、リンゴは何個ありますか？
```

このように「ステップバイステップ」と指示するだけで、AIの論理的推論能力が向上します。
''',
      officialDocs: [
        {
          'title': 'Prompt design strategies',
          'url': 'https://ai.google.dev/docs/prompt_best_practices',
        },
        {
          'title': 'Prompt Gallery',
          'url': 'https://ai.google.dev/examples?keywords=prompting',
        },
      ],
    ),
    CourseModule(
      id: 'function_calling',
      title: 'Function Calling',
      description: '外部システムと連携して機能を拡張する',
      icon: Icons.api,
      content:
          'Function Callingは、Geminiが外部のAPIやサービスを呼び出す必要があると判断した際に、特定の関数を呼び出すための構造化されたデータを返す機能です。\n\n'
          '【主な利点】\n'
          '1. **リアルタイム情報アクセス**: 天気予報、株価、ニュースなど、最新の情報を取得できます。\n'
          '2. **外部サービス連携**: 自社のデータベース検索や、Eメール送信などのアクションを実行できます。\n'
          '3. **構造化データ抽出**: 自然言語のテキストから、定義したスキーマに基づいて情報を抽出します。\n\n'
          'これにより、AIは単なるテキスト生成にとどまらず、より動的でインタラクティブなアプリケーションの一部として機能します。',
      quiz: Quiz(
        question: 'Function Callingの主な利点は次のうちどれですか？',
        options: ['モデルの学習', 'リアルタイム情報の取得', '画像の生成', 'テキストの翻訳'],
        correctIndex: 1,
      ),
      officialDocs: [
        {
          'title': 'Function calling',
          'url': 'https://ai.google.dev/docs/function_calling',
        },
        {
          'title': 'Vertex AI - Function calling',
          'url':
              'https://cloud.google.com/vertex-ai/docs/generative-ai/multimodal/function-calling',
        },
      ],
    ),
    CourseModule(
      id: 'multimodality',
      title: 'マルチモーダリティ',
      description: 'テキスト、画像、音声を組み合わせた入力と出力',
      icon: Icons.camera_alt,
      content: 'Geminiは、テキストだけでなく、画像、音声、動画といった複数の種類の情報を同時に理解し、処理することができます。\n\n'
          '【ユースケース例】\n'
          '1. **画像の説明**: 画像をアップロードし、その内容を説明する文章を生成します。\n'
          '2. **動画の要約**: 動画ファイルから主要なシーンを抜き出し、要約を作成します。\n'
          '3. **音声コマンド**: 音声で指示を出し、それに応じたテキストや画像を生成します。\n\n'
          'プロンプトに複数のモダリティ（例：画像とテキスト）を組み合わせることで、より複雑で文脈に沿ったタスクを実行できます。',
      quiz: Quiz(
        question: 'マルチモーダルAIが扱える情報の種類は次のうちどれですか？',
        options: ['テキストのみ', 'テキストと画像のみ', 'テキスト、画像、音声、動画など', '数値データのみ'],
        correctIndex: 2,
      ),
      officialDocs: [
        {
          'title': 'Multimodal concepts',
          'url': 'https://ai.google.dev/docs/concepts#multimodal',
        },
        {'title': 'Media', 'url': 'https://ai.google.dev/docs/media'},
      ],
    ),
    CourseModule(
      id: 'long_context',
      title: 'ロングコンテキストとキャッシュ',
      description: 'Gemini 1.5/2.5の長大なコンテキストウィンドウの活用',
      icon: Icons.memory,
      content: 'Gemini 2.5 Proなどは、最大100万トークン以上の圧倒的なコンテキストウィンドウを持っています。\n\n'
          '【活用例】\n'
          '・数時間の動画や音声を一度に読み込んで分析\n'
          '・数千ページのドキュメント全体から情報を検索\n'
          '・大規模なコードベース全体の理解\n\n'
          '【Context Caching】\n'
          '頻繁に使用する長いコンテキスト（マニュアルや規定など）をキャッシュすることで、コストとレイテンシを削減できます。',
      quiz: Quiz(
        question: '長いプロンプトを再利用してコストを削減する機能は？',
        options: [
          'Context Caching',
          'Vector Search',
          'Distillation',
          'Quantization',
        ],
        correctIndex: 0,
      ),
      officialDocs: [
        {
          'title': 'Context caching',
          'url': 'https://ai.google.dev/docs/context_caching',
        },
        {
          'title': 'Get started with Gemini',
          'url': 'https://ai.google.dev/docs/gemini_api_overview',
        },
      ],
    ),
    CourseModule(
      id: 'json_mode',
      title: 'JSONモード',
      description: '構造化されたJSON出力を保証する',
      icon: Icons.code,
      content: 'JSONモードを有効にすると、モデルの出力が必ず有効なJSON文字列であることが保証されます。\n\n'
          '【利点】\n'
          '- **信頼性**: 出力が常にパース可能であるため、アプリケーションとの連携が安定します。\n'
          '- **効率化**: 出力形式を検証し、リトライするロジックをクライアント側で実装する必要がなくなります。\n\n'
          'API連携や、構造化データを必要とするアプリケーション開発において非常に強力な機能です。',
      quiz: Quiz(
        question: 'JSONモードの主な利点は何ですか？',
        options: ['出力が高速になる', '出力が必ず有効なJSONになる', '出力がカラフルになる', '出力が長くなる'],
        correctIndex: 1,
      ),
      officialDocs: [
        {
          'title': 'JSON mode',
          'url': 'https://ai.google.dev/docs/prompt_best_practices#json-mode',
        },
      ],
    ),
    CourseModule(
      id: 'responsible_ai',
      title: '責任あるAI',
      description: '安全で倫理的なAIアプリケーションを構築する',
      icon: Icons.health_and_safety,
      content: 'Googleは、AIを責任を持って開発するためのツールとガイダンスを提供しています。\n\n'
          '【安全設定 (Safety Settings)】\n'
          'Gemini APIには、有害なコンテンツ（嫌がらせ、ヘイトスピーチなど）をブロックするための安全設定が組み込まれています。閾値を調整することで、ユースケースに応じたカスタマイズが可能です。\n\n'
          '【APIキーの保護】\n'
          'APIキーは、クライアントサイドのコードに直接埋め込むべきではありません。サーバーサイドで管理し、必要に応じて呼び出すなどの対策が推奨されます。',
      quiz: Quiz(
        question: '有害なコンテンツをブロックする機能は何ですか？',
        options: ['APIキー', 'JSONモード', '安全設定', 'Persona'],
        correctIndex: 2,
      ),
      officialDocs: [
        {
          'title': 'Safety settings',
          'url': 'https://ai.google.dev/docs/safety_setting_gemini',
        },
        {
          'title': 'AI principles',
          'url': 'https://ai.google/responsibility/principles/',
        },
      ],
    ),
    CourseModule(
      id: 'api_reference',
      title: 'Gemini API リファレンス',
      description: 'REST APIやSDKの技術仕様を学ぶ',
      icon: Icons.integration_instructions,
      content: '''
### Gemini API Reference
*Last Updated: 2026/1/23*

> We have updated our Terms of Service.
> 利用規約を更新しました。

This API reference describes the standard, streaming, and realtime APIs you can use to interact with the Gemini models.
> このAPIリファレンスは、Geminiモデルとのやり取りに使用できる標準API、ストリーミングAPI、リアルタイムAPIについて説明します。

You can use the REST APIs in any environment that supports HTTP requests.
> HTTPリクエストをサポートする環境であれば、どの環境でもREST APIを利用できます。

Refer to the Quickstart guide for how to get started with your first API call.
> 最初のAPI呼び出しを開始する方法については、クイックスタートガイドを参照してください。

If you're looking for the references for our language-specific libraries and SDKs, go to the link for that language in the left navigation under SDK references.
> 言語固有のライブラリおよびSDKの参照情報をお探しの場合は、左ナビゲーションの「SDKリファレンス」にある該当言語のリンクをご覧ください。

---

### Primary endpoints / 主要評価項目

The Gemini API is organized around the following major endpoints:
> Gemini APIは以下の主要なエンドポイントを中心に構成されています：

**Standard content generation (generateContent):** A standard REST endpoint that processes your request and returns the model's full response in a single package. This is best for non-interactive tasks where you can wait for the entire result.
> **標準コンテンツ生成 (generateContent):** リクエストを処理し、モデルの完全な応答を単一のパッケージで返す標準的なRESTエンドポイントです。結果全体を待機できる非対話型タスクに最適です。

**Streaming content generation (streamGenerateContent):** Uses Server-Sent Events (SSE) to push chunks of the response to you as they are generated. This provides a faster, more interactive experience for applications like chatbots.
> **ストリーミングコンテンツ生成 (streamGenerateContent):** サーバー送信イベント (SSE) を使用して、生成されたレスポンスのチャンクをプッシュ配信します。これにより、チャットボットなどのアプリケーションにおいて、より高速でインタラクティブな体験を提供します。

**Multimodal Live API (BidiGenerateContent):** A stateful WebSocket-based API for bi-directional streaming of audio and video, designed for real-time conversational use cases with sub-second latency.
> **マルチモーダル・ライブAPI (BidiGenerateContent):** 音声とビデオの双方向ストリーミングのためのステートフルなWebSocketベースのAPI。1秒未満の低遅延でリアルタイムな会話ユースケース向けに設計されています。

**Batch mode (batchGenerateContent):** (*Updated: 2026/1/15*) A standard REST endpoint for submitting batches of generateContent requests.
> **バッチモード (batchGenerateContent):** (*2026/1/15 更新*) generateContentリクエストのバッチを送信するための標準的なRESTエンドポイント。

**Embeddings (embedContent):** (*Updated: 2026/1/16*) A standard REST endpoint that generates a text embedding vector from the input Content.
> **埋め込み（embedContent）：**(*2026/1/16 更新*) 入力コンテンツからテキスト埋め込みベクトルを生成する標準的なRESTエンドポイント。

**Semantic Retrieval (AQA):** (*New: 2026/1/20*) Attributed Question Answering (AQA) endpoint for grounding responses in your own data with source citations.
> **セマンティック検索 (AQA):** (*2026/1/20 新機能*) 出典を明記しながら独自のデータに基づいて回答を生成する、根拠付け（Grounding）に特化したエンドポイント。

**Gen Media APIs:** (*Updated: 2026/1/16*) Endpoints for generating media with our specialized models such as Imagen for image generation, and Veo for video generation. Gemini also has these capabilities built in which you can access using the generateContent API.
> **Gen Media API:** (*2026/1/16 更新*) 画像生成用のImagenや動画生成用のVeoなど、当社の専用モデルを用いたメディア生成のためのエンドポイントです。Geminiにも同様の機能が組み込まれており、generateContent APIを使用してアクセスできます。

**Platform APIs:** (*Updated: 2026/1/17*) Utility endpoints that support core capabilities such as uploading files, and counting tokens.
> **プラットフォームAPI:** (*2026/1/17 更新*) ファイルのアップロードやトークンのカウントといった中核機能をサポートするユーティリティエンドポイント。

---

### Authentication / 認証
*Updated: 2026/1/17*

All requests to the Gemini API must include an `x-goog-api-key` header with your API key. Create one with a few clicks in Google AI Studio.
> Gemini APIへのすべてのリクエストには、APIキーを含む`x-goog-api-key`ヘッダーを含める必要があります。Google AI Studioで数クリックで作成できます。

The following is an example request with the API key included in the header: (*Updated: 2026/1/21*)
> 以下は、ヘッダーにAPIキーを含めたリクエストの例です： (*2026/1/21 更新*)
```bash
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" \\
  -H "x-goog-api-key: \$GEMINI_API_KEY" \\
  -H 'Content-Type: application/json' \\
  -X POST \\
  -d '{
    "contents": [
      {
        "parts": [
          {
            "text": "Explain how AI works in a few words"
          }
        ]
      }
    ]
  }'
```

For instructions on how to pass your key to the API using Gemini SDKs, see the Using Gemini API keys guide. (*Updated: 2026/1/21*)
> Gemini SDKを使用してAPIにキーを渡す方法については、「Gemini APIキーの使用」ガイドを参照してください。 (*2026/1/21 更新*)

---

### Content generation / コンテンツ生成
*Updated: 2026/1/21*

This is the central endpoint for sending prompts to the model.
> これはモデルにプロンプトを送信するための中央エンドポイントです。

There are two endpoints for generating content, the key difference is how you receive the response:
> コンテンツ生成には2つのエンドポイントがあり、主な違いはレスポンスの受け取り方です：

**generateContent (REST):** Receives a request and provides a single response after the model has finished its entire generation.
> **generateContent (REST):** リクエストを受け取り、モデルの生成が完全に終了した後に単一のレスポンスを返します。

**streamGenerateContent (SSE):** Receives the exact same request, but the model streams back chunks of the response as they are generated. This provides a better user experience for interactive applications as it lets you display partial results immediately.
> **streamGenerateContent (SSE):** まったく同じリクエストを受け取りますが、モデルが生成されたレスポンスのチャンクをストリーミングで返します。これにより、部分的な結果を即座に表示できるため、インタラクティブなアプリケーションにおいて優れたユーザー体験を提供します。

---

### Request body structure / リクエスト本文の構造
*Updated: 2026/1/23*

The request body is a JSON object that is identical for both standard and streaming modes and is built from a few core objects:
> リクエスト本体は、標準モードとストリーミングモードの両方で同一のJSONオブジェクトであり、以下のコアオブジェクトから構成されます：

**Content object:** Represents a single turn in a conversation.
> **コンテンツオブジェクト：**会話における単一のターンを表す。

**Part object:** A piece of data within a Content turn (like text or an image).
> **部分オブジェクト：**コンテンツターン内のデータの一部（テキストや画像など）。

**inline_data (Blob):** (*Updated: 2026/1/23*) A container for raw media bytes and their MIME type.
> **inline_data (Blob):** (*2026/1/23 更新*) 生メディアバイトとそのMIMEタイプを格納するコンテナ。

---

### Advanced Configuration / 高度な設定

**System Instructions:** Define the behavior and constraints of the model before any user input.
> **システム指示:** ユーザー入力の前に、モデルの振る舞いや制約を定義します。

**Safety Settings:** Configure thresholds for blocking harmful content across categories like harassment and hate speech.
> **安全設定:** 嫌がらせやヘイトスピーチなどのカテゴリごとに、有害なコンテンツをブロックする閾値を設定します。

**Generation Config:** Fine-tune the output using parameters like `temperature`, `topP`, `topK`, and `maxOutputTokens`.
> **生成設定:** `temperature`、`topP`、`topK`、`maxOutputTokens` などのパラメータを使用して出力を微調整します。

**Thinking Config:** (*New*) Enable the model to perform internal reasoning before generating the final response.
> **思考設定 (Thinking Config):** (*新機能*) 最終的な回答を生成する前に、モデルが内部的な推論（思考プロセス）を実行できるようにします。

```json
{
  "contents": [...],
  "generationConfig": {
    "thinking_config": {
      "include_thoughts": true
    }
  }
}
```
''',
      quiz: Quiz(
        question:
            'リアルタイム会話型ユースケース向けに設計された、双方向ストリーミングのためのWebSocketベースのAPIはどれですか？',
        options: [
          'generateContent',
          'streamGenerateContent',
          'BidiGenerateContent',
          'batchGenerateContent',
        ],
        correctIndex: 2,
      ),
      officialDocs: [
        {
          'title': 'Gemini REST API reference',
          'url': 'https://ai.google.dev/api/rest',
        },
        {
          'title': 'SDK Quickstart',
          'url': 'https://ai.google.dev/gemini-api/docs/quickstart',
        },
      ],
    ),
    CourseModule(
      id: 'gemini_code_assist_overview',
      title: 'Gemini Code Assist overview',
      description: 'Gemini Code Assist の概要と活用ガイド',
      icon: Icons.code_sharp,
      content: '''
### ジェミニ・コードアシストの概要
*2026/1/21 更新*

Gemini Code Assistは、**Gemini 2.5モデル**を活用したソフトウェア開発ライフサイクル向けのAI支援を提供します。

#### 主な機能と特徴
1. **AI支援**: 対応するIDEでコード生成、対話型ヘルプの提供、ソース引用などの機能を利用できます。
2. **3つのエディション**:
   - **個人向けGemini Code Assist**: 無料で利用いただけます。
   - **Gemini Code Assist Standard**: Google Cloud ポートフォリオ製品。
   - **Gemini Code Assist Enterprise**: Google Cloud ポートフォリオ製品。
3. **クラウド連携**: Standard版とEnterprise版では、IDE以外の追加機能を提供しており、各種Google Cloudサービスとの連携が含まれます。

#### 注意点
* ユーザーは、Gemini Code Assistの出力を検証する必要があります。これは初期段階の技術であり、誤った情報を生成する場合があるためです。
* **個人開発者向けのヒント**: Google AI ProまたはUltraのサブスクリプションを購入することで、Gemini Code Assist、Gemini CLI、エージェントモードで共有される1日あたりのモデルリクエスト上限を引き上げることができます。
* **対応IDE**: VS Code, IntelliJ IDEA (JetBrains), Android Studio など、多くの主要なIDEで利用可能です。

ビジネス利用の場合、またはチームレベルの特典をさらにご利用になりたい場合は、Gemini Code Assist Standard または Enterprise のご利用をご検討ください。
''',
      quiz: Quiz(
        question: 'Gemini Code Assistの個人開発者が1日のリクエスト上限を引き上げる方法は？',
        options: [
          'Enterprise版を契約する',
          'Google AI Pro/Ultraのサブスクリプションを購入する',
          'Google Cloudのプロジェクトを作成する',
          '設定で制限解除を申請する',
        ],
        correctIndex: 1,
      ),
      officialDocs: [
        {
          'title': 'Gemini Code Assist overview',
          'url':
              'https://developers.google.com/gemini-code-assist/docs/overview',
        },
      ],
    ),
    CourseModule(
      id: 'gemini_quotas_limits',
      title: '割当(Quotas)と制限(Limits)',
      description: 'Gemini Code Assist と CLI のクォータとシステム制限について学ぶ',
      icon: Icons.speed,
      content: '''
### 割当(Quotas)と制限(Limits)
*Last Updated: 2026/1/21*

このドキュメントでは、Gemini Code AssistおよびGemini CLIの使用に関するクォータとシステム制限について説明します。

---

### 基本概念
* **クォータ (Quotas)**: 共有リソースの使用可能量（変動する可能性があります）。
* **システム制限 (System Limits)**: 固定値です。

### 適用範囲
Gemini Code AssistおよびGemini CLIには、以下の単位でリクエスト数のクォータが設定されています。これらはエディションまたはライセンスタイプによって異なります。
* ローカルコードベースの認識
* コードカスタマイズリポジトリ
* ユーザーごとの分単位/日単位のリクエスト数

### プラットフォーム別の仕様

#### GitHub
GitHubにおけるGemini Code Assistの使用には、プルリクエストのレビュー用に別途クォータが設定されています。

#### BigQuery
BigQueryのコードアシスト機能におけるGeminiのクォータは、Gemini Code Assistと同じです。ただし、BigQueryの使用状況に基づく高度な機能については追加のクォータが適用されます。

### 併用時の注意
このドキュメントに記載されているクォータとシステム制限は、Gemini Code AssistとGemini CLIの**併用**に対して適用されます。
''',
      quiz: Quiz(
        question: '「共有リソースの使用可能量であり、変動する可能性がある」と定義されているのはどれですか？',
        options: [
          'システム制限 (System Limits)',
          'クォータ (Quotas)',
          'ライセンスタイプ',
          'エディション',
        ],
        correctIndex: 1,
      ),
      officialDocs: [
        {
          'title': 'Quotas and limits',
          'url':
              'https://developers.google.com/gemini-code-assist/docs/quotas-limits',
        },
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch $urlString'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _completeModule(String id) {
    if (!_completedModuleIds.contains(id)) {
      setState(() {
        _completedModuleIds.add(id);
      });

      // ポイント付与
      context
          .read<GamificationService>()
          .awardPoints(50, reason: 'AI大学講義修了');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正解！単位を取得しました (50pt)'),
          backgroundColor: Colors.green,
        ),
      );

      if (_completedModuleIds.length == _modules.length) {
        _showGraduationDialog();
      }
    }
  }

  void _showGraduationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.school, color: Colors.orange),
            SizedBox(width: 8),
            Text('卒業おめでとうございます！'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('AI大学の全カリキュラムを修了しました。'),
            SizedBox(height: 16),
            Text(
              '学位: AI Master',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('特別ボーナス: 500pt'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              context
                  .read<GamificationService>()
                  .awardPoints(500, reason: 'AI大学卒業');
              Navigator.pop(context);
            },
            child: const Text('学位を受け取る'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final primaryColor = Colors.indigo.shade800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 大学'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // ★ 追加: Embedding実験室への遷移ボタン
          IconButton(
            icon: const Icon(Icons.science),
            tooltip: 'Embedding実験室',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ApiPlaygroundPage(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book), text: 'カリキュラム'),
            Tab(icon: Icon(Icons.card_membership), text: '学位・成績'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCurriculumTab(isDark),
          _buildDegreeTab(isDark),
        ],
      ),
    );
  }

  Widget _buildCurriculumTab(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      cacheExtent: 1000,
      itemCount: _modules.length,
      itemBuilder: (context, index) {
        final module = _modules[index];
        final isCompleted = _completedModuleIds.contains(module.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isCompleted
                ? const BorderSide(color: Colors.green, width: 2)
                : BorderSide.none,
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor:
                  isCompleted ? Colors.green : Colors.indigo.shade100,
              child: Icon(
                isCompleted ? Icons.check : module.icon,
                color: isCompleted ? Colors.white : Colors.indigo,
              ),
            ),
            title: Text(
              module.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(module.description),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 学習進捗インジケーター
                    LinearProgressIndicator(
                      value: isCompleted ? 1.0 : (_readingProgress[module.id] ?? 0.0),
                      backgroundColor: Colors.grey.shade200,
                      color: isCompleted ? Colors.green : Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    MarkdownBody(
                      data: module.content,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(height: 1.6),
                        code: TextStyle(
                          backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    if (module.labContent != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [Icon(Icons.biotech, color: Colors.orange), SizedBox(width: 8), Text('実践ラボ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))]),
                            const SizedBox(height: 8),
                            MarkdownBody(data: module.labContent!),
                          ],
                        ),
                      ),
                    ],
                    _buildOfficialDocs(module),
                    if (!isCompleted)
                      _buildQuiz(module)
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            '単位取得済み',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOfficialDocs(CourseModule module) {
    if (module.officialDocs == null || module.officialDocs!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            '【公式ドキュメント】',
            style:
                TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
        ),
        ...module.officialDocs!.map((doc) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: TextButton.icon(
              onPressed: () => _launchUrl(doc['url']!),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(doc['title']!),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                alignment: Alignment.centerLeft,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildQuiz(CourseModule module) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            '【理解度確認クイズ】',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
        ),
        const SizedBox(height: 8),
        Text(module.quiz.question, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        ...module.quiz.options.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  if (entry.key == module.quiz.correctIndex) {
                    _completeModule(module.id);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('不正解です。もう一度内容を確認しましょう。'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(12),
                ),
                child: Text('${entry.key + 1}. ${entry.value}'),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDegreeTab(bool isDark) {
    final progress = _completedModuleIds.length / _modules.length;
    final isGraduated = progress >= 1.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: Colors.grey.shade200,
                  color: isGraduated ? Colors.orange : Colors.indigo,
                ),
              ),
              Column(
                children: [
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('修了率'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),
          if (isGraduated)
            _buildCertificate()
          else
            const Text(
              'すべての講義を修了して、\nAIマスターの称号を手に入れましょう！',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          const SizedBox(height: 40),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.school),
            title: const Text('取得単位数'),
            trailing: Text(
              '${_completedModuleIds.length} / ${_modules.length}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificate() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.workspace_premium, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            'CERTIFICATE OF COMPLETION',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'AI Master',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontFamily: 'Serif',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'この証書は、AI大学の全課程を修了し、\n生成AIに関する高度な知識を有することを証明します。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          Text(
            'Date: ${DateTime.now().year}.${DateTime.now().month}.${DateTime.now().day}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class CourseModule {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String content;
  final String? labContent; // 実践ラボ用のコンテンツ
  final Quiz quiz;
  final List<Map<String, String>>? officialDocs;

  CourseModule({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.content,
    this.labContent,
    required this.quiz,
    this.officialDocs,
  });
}

class Quiz {
  final String question;
  final List<String> options;
  final int correctIndex;

  Quiz({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}
