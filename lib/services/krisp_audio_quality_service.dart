enum KrispAudioScenario {
  remoteMeeting,
  podcast,
  investorCall,
  aiCoachSdk,
}

class KrispAudioKpi {
  const KrispAudioKpi({
    required this.label,
    required this.current,
    required this.target,
    required this.unit,
  });

  final String label;
  final num current;
  final num target;
  final String unit;

  double get progress {
    if (target <= 0) return current <= 0 ? 1 : 0;
    return (current / target).clamp(0, 1).toDouble();
  }
}

class KrispAudioPlan {
  const KrispAudioPlan({
    required this.scenario,
    required this.issueNumber,
    required this.title,
    required this.shortTitle,
    required this.kgi,
    required this.csf,
    required this.kpis,
    required this.setupSteps,
    required this.qualityChecks,
    required this.risks,
    required this.sourceUrl,
    required this.sdkMode,
  });

  final KrispAudioScenario scenario;
  final int issueNumber;
  final String title;
  final String shortTitle;
  final String kgi;
  final List<String> csf;
  final List<KrispAudioKpi> kpis;
  final List<String> setupSteps;
  final List<String> qualityChecks;
  final List<String> risks;
  final String sourceUrl;
  final String sdkMode;

  int get readinessScore {
    final kpiScore = kpis.isEmpty
        ? 0
        : (kpis.map((kpi) => kpi.progress).reduce((a, b) => a + b) /
                kpis.length *
                100)
            .round();
    final setupScore = setupSteps.isEmpty ? 0 : 20;
    return (kpiScore * 0.8 + setupScore).round().clamp(0, 100);
  }
}

class KrispSdkGate {
  const KrispSdkGate({
    required this.id,
    required this.label,
    required this.owner,
    required this.satisfied,
    required this.nextAction,
  });

  final String id;
  final String label;
  final String owner;
  final bool satisfied;
  final String nextAction;
}

class KrispAiCoachPipelineStep {
  const KrispAiCoachPipelineStep({
    required this.id,
    required this.label,
    required this.input,
    required this.output,
  });

  final String id;
  final String label;
  final String input;
  final String output;
}

class KrispAiCoachHandoff {
  const KrispAiCoachHandoff({
    required this.issueNumber,
    required this.gates,
    required this.pipeline,
    required this.acceptanceChecks,
  });

  final int issueNumber;
  final List<KrispSdkGate> gates;
  final List<KrispAiCoachPipelineStep> pipeline;
  final List<String> acceptanceChecks;

  Iterable<KrispSdkGate> get blockers => gates.where((gate) => !gate.satisfied);

  bool get readyForSdkSpike => blockers.isEmpty;

  int get satisfiedGateCount => gates.where((gate) => gate.satisfied).length;
}

class KrispAudioQualityService {
  const KrispAudioQualityService();

  static const docsBrowserSdk = 'https://sdk-docs.krisp.ai/docs/introduction';
  static const docsGettingStarted =
      'https://sdk-docs.krisp.ai/docs/getting-started';
  static const docsAppSetup =
      'https://help.krisp.ai/hc/en-us/articles/360017441080-Set-up-any-app-with-Krisp';

  List<KrispAudioPlan> get plans => const [
        KrispAudioPlan(
          scenario: KrispAudioScenario.remoteMeeting,
          issueNumber: 752,
          title: 'Krisp リモートミーティング環境改善',
          shortTitle: '会議',
          kgi: '在宅・カフェでも聞き返しゼロのオンライン会議を安定運用する',
          csf: [
            'Krisp Microphone と Krisp Speaker を会議アプリで選択する',
            '会議前60秒でノイズ、反響、入力レベルを点検する',
            '騒音環境ではヘッドセットとBackground Voice Cancellationを優先する',
          ],
          kpis: [
            KrispAudioKpi(label: '聞き返し', current: 0, target: 0, unit: '回'),
            KrispAudioKpi(label: '会議前点検', current: 1, target: 1, unit: '回'),
            KrispAudioKpi(label: 'Krisp選択', current: 1, target: 1, unit: '設定'),
          ],
          setupSteps: [
            'Krispアプリで物理マイクとスピーカーを選び、Noise Cancellationをオンにする',
            'Zoom / Google Meet / Teams側で入力をKrisp Microphone、出力をKrisp Speakerにする',
            '会議前に10秒録音して、キーボード音・空調音・周辺会話の残り方を確認する',
            'カフェではヘッドセットを使い、ブラウザや会議アプリの自動ノイズ抑制は二重掛けしない',
          ],
          qualityChecks: [
            '相手から聞き返しが出たら、入力レベルを下げてKrispだけを残す',
            '自分の声が細くなる場合はノイズ除去強度を下げる',
            '静かな部屋ではKrispを弱め、声の自然さを優先する',
          ],
          risks: [
            'Web会議アプリ側でKrisp仮想デバイスを選べない場合はブラウザ全体の入力設定で代替する',
            'ノイズ除去を複数アプリで重ねると声が圧縮される',
          ],
          sourceUrl: KrispAudioQualityService.docsAppSetup,
          sdkMode: 'Desktop app / virtual device',
        ),
        KrispAudioPlan(
          scenario: KrispAudioScenario.podcast,
          issueNumber: 753,
          title: 'Krisp AI大学 Tech Talk / Podcast収録',
          shortTitle: '収録',
          kgi: 'AI大学の音声コンテンツを編集負荷の少ないクリアな素材として収録する',
          csf: [
            '収録前に環境音、反響、入力ゲインを固定する',
            'Krispはノイズ除去、DAW側は音量整形に役割を分ける',
            '10秒の無音サンプルと30秒の本番サンプルを毎回保存する',
          ],
          kpis: [
            KrispAudioKpi(label: '再録', current: 0, target: 0, unit: '回'),
            KrispAudioKpi(label: '試し録り', current: 2, target: 2, unit: '本'),
            KrispAudioKpi(label: '編集前ノイズ', current: 1, target: 1, unit: '合格'),
          ],
          setupSteps: [
            '録音ソフトの入力をKrisp Microphoneにして、モニター返しは遅延を確認する',
            '空調やキーボードを鳴らした状態で無音サンプルを10秒録る',
            'AI大学の冒頭トークを30秒だけ試し録りし、声の自然さを確認する',
            '本番前にKrisp以外のノイズゲートや強いコンプレッサーを切る',
          ],
          qualityChecks: [
            '摩擦音や語尾が消える場合はKrisp強度を下げる',
            'BGMや効果音を同時入力しない',
            'リモートゲストがいる場合は相手側にもKrisp設定を依頼する',
          ],
          risks: [
            '収録ではノイズを消しすぎると声が人工的になる',
            '編集済み音源に後から強いノイズ除去をかけると劣化する',
          ],
          sourceUrl: KrispAudioQualityService.docsGettingStarted,
          sdkMode: 'RTC SDK concept / recording workflow',
        ),
        KrispAudioPlan(
          scenario: KrispAudioScenario.investorCall,
          issueNumber: 754,
          title: 'Krisp 投資家面談・クライアントコール品質向上',
          shortTitle: '面談',
          kgi: '重要商談で音声品質を理由に信頼を落とさない',
          csf: [
            '重要コールは固定席、固定マイク、固定設定で実施する',
            '相手の音声もKrisp Speakerで聞き取りやすくする',
            '議事録・録音・文字起こしの前提として音声品質を点検する',
          ],
          kpis: [
            KrispAudioKpi(label: '音声起因中断', current: 0, target: 0, unit: '回'),
            KrispAudioKpi(label: '事前点検', current: 1, target: 1, unit: '回'),
            KrispAudioKpi(label: '代替回線', current: 1, target: 1, unit: '準備'),
          ],
          setupSteps: [
            '開始15分前にKrisp、会議URL、カメラ、バックアップ回線を確認する',
            '会議アプリでKrisp Microphone / Speakerが選択されていることを確認する',
            '重要面談ではPC内蔵マイクではなくヘッドセットを使う',
            '聞き取りづらい場合に備え、電話・別会議URL・チャットを代替経路として用意する',
          ],
          qualityChecks: [
            '相手の声が途切れる場合はKrisp Speakerを一時的に切って比較する',
            '相手の社名・数字・日付は復唱して認識ミスを防ぐ',
            '終了後に音声起因の中断回数を1行で記録する',
          ],
          risks: [
            '商談中に設定変更を始めると会話の主導権を失う',
            'クラウド録音を使う場合は相手の同意と社内ルール確認が必要',
          ],
          sourceUrl: KrispAudioQualityService.docsAppSetup,
          sdkMode: 'Desktop app / operational playbook',
        ),
        KrispAudioPlan(
          scenario: KrispAudioScenario.aiCoachSdk,
          issueNumber: 755,
          title: 'Krisp SDK 将来AIコーチ音声組み込み',
          shortTitle: 'SDK',
          kgi: 'AIコーチとの音声対話で誤認識と割り込みを減らすSDK導入準備を完了する',
          csf: [
            'WebRTC / Web Audioの入力ストリームにKrisp noise filterを差し込む設計にする',
            'VIVA SDKはVoice AI Agent、RTC SDKは人間同士の会議用途に分ける',
            'APIキー、モデルファイル、対応sample rate、device switchingを導入前提条件にする',
          ],
          kpis: [
            KrispAudioKpi(label: 'SDK前提整理', current: 1, target: 1, unit: '完了'),
            KrispAudioKpi(label: '対応ユースケース', current: 4, target: 4, unit: '件'),
            KrispAudioKpi(label: '実装ブロッカー', current: 0, target: 0, unit: '未解消'),
          ],
          setupSteps: [
            'Krisp SDK PortalでBrowser SDKの契約、キー、モデルファイルの配布条件を確認する',
            'AIコーチの録音入力はWeb AudioのMediaStreamを経由する設計に統一する',
            'AudioContext sampleRateがKrisp対応値か確認し、非対応ならユーザーに設定変更を促す',
            'デバイス切替時はnoise filterを作り直す実装タスクとしてWBS化する',
          ],
          qualityChecks: [
            'SDK導入前は仮想デバイス運用、導入後はアプリ内filter運用に切り替える',
            'VADとturn-takingはAIコーチの割り込み抑制KPIとして測定する',
            '音声データを保存する場合は同意、保存期間、削除導線を必須にする',
          ],
          risks: [
            'SDK契約・モデル配布条件が未確定のまま実装するとビルドだけが先行する',
            'WASMモデルはサイズとメモリ負荷を見積もる必要がある',
          ],
          sourceUrl: KrispAudioQualityService.docsBrowserSdk,
          sdkMode: 'Browser SDK readiness',
        ),
      ];

  KrispAudioPlan planFor(KrispAudioScenario scenario) {
    return plans.firstWhere((plan) => plan.scenario == scenario);
  }

  KrispAiCoachHandoff buildAiCoachHandoff() {
    return const KrispAiCoachHandoff(
      issueNumber: 755,
      gates: [
        KrispSdkGate(
          id: 'contract',
          label: 'Krisp Browser SDK contract and API key',
          owner: 'user',
          satisfied: false,
          nextAction:
              'Confirm SDK access, commercial terms, and allowed deployment domain.',
        ),
        KrispSdkGate(
          id: 'model-distribution',
          label: 'Noise model distribution terms',
          owner: 'user',
          satisfied: false,
          nextAction:
              'Confirm whether WASM/model assets can be bundled, cached, or fetched at runtime.',
        ),
        KrispSdkGate(
          id: 'audio-runtime',
          label: 'Web Audio runtime contract',
          owner: 'codex',
          satisfied: true,
          nextAction:
              'Keep the integration behind a feature flag and wire it after getUserMedia.',
        ),
        KrispSdkGate(
          id: 'privacy-consent',
          label: 'Voice privacy and retention policy',
          owner: 'codex',
          satisfied: true,
          nextAction:
              'Require explicit mic consent and default to no raw-audio persistence.',
        ),
        KrispSdkGate(
          id: 'ai-coach-interface',
          label: 'AI coach stream boundary',
          owner: 'codex',
          satisfied: true,
          nextAction:
              'Send only filtered PCM or transcript text into the coach turn pipeline.',
        ),
      ],
      pipeline: [
        KrispAiCoachPipelineStep(
          id: 'capture',
          label: 'Browser mic capture',
          input: 'User media permission',
          output: 'MediaStream',
        ),
        KrispAiCoachPipelineStep(
          id: 'filter',
          label: 'Krisp noise filter',
          input: 'MediaStream audio track',
          output: 'Filtered audio track or AudioWorklet node',
        ),
        KrispAiCoachPipelineStep(
          id: 'turn-taking',
          label: 'VAD and turn boundary',
          input: 'Filtered PCM frames',
          output: 'Stable user utterance segment',
        ),
        KrispAiCoachPipelineStep(
          id: 'stt',
          label: 'Speech-to-text',
          input: 'Utterance segment',
          output: 'Transcript with confidence',
        ),
        KrispAiCoachPipelineStep(
          id: 'coach',
          label: 'AI coach response',
          input: 'Transcript plus session context',
          output: 'Coach reply and next action',
        ),
      ],
      acceptanceChecks: [
        'Fallback to raw microphone input when Krisp SDK is unavailable.',
        'No raw audio is stored unless the user explicitly enables recording.',
        'Device switching rebuilds the filter chain without page reload.',
        'STT and coach latency budgets are measured separately from filtering.',
      ],
    );
  }

  String buildShareText(KrispAudioPlan plan) {
    final kpiText = plan.kpis
        .map((kpi) => '${kpi.label}: ${kpi.current}${kpi.unit}')
        .join(' / ');
    final lines = [
      plan.title,
      'KGI: ${plan.kgi}',
      'CSF: ${plan.csf.take(2).join(' / ')}',
      'KPI: $kpiText',
      'Source: ${plan.sourceUrl}',
    ];
    if (plan.scenario == KrispAudioScenario.aiCoachSdk) {
      final handoff = buildAiCoachHandoff();
      lines.add(
        'SDK gates: ${handoff.satisfiedGateCount}/${handoff.gates.length}',
      );
      lines.add(
        'Blockers: ${handoff.blockers.map((gate) => gate.id).join(', ')}',
      );
    }
    return lines.join('\n');
  }
}
