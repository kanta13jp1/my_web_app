import 'package:flutter/material.dart';

class LandingFaqSection extends StatelessWidget {
  final bool showAdditionalFaqs;

  const LandingFaqSection({super.key, required this.showAdditionalFaqs});

  @override
  Widget build(BuildContext context) {
    const faqs = [
      (
        q: 'AIが勝手に「やること」を決めるのですか?',
        a: 'いいえ。AIは入力内容を整理して、次に動かす1件の候補と理由を提案します。実行するか、別の行動を選ぶかはユーザーが決めます。',
      ),
      (
        q: '登録する前に試せますか?',
        a: 'はい。いま詰まっていることを1行入力し、AIの提案を1件確認するまでは登録不要です。提案を引き継ぎたい場合だけ無料登録へ進みます。',
      ),
      (
        q: '登録時にカード情報は必要ですか?',
        a: 'いいえ。無料登録の画面ではカード情報を求めません。有料プランは、別の料金画面で内容を確認してから申し込めます。',
      ),
      (
        q: '登録前に試した提案は引き継げますか?',
        a: 'はい。同じブラウザでGoogle認証またはメールのログインリンクから登録すると、今回の入力・AIの提案・提案理由を引き継ぎます。',
      ),
      (
        q: 'LINE・Discord・SNSの代わりになりますか?',
        a: 'LINE・Discordのメッセージ・通話機能の代替ではありませんが、個人のタスク管理・メモ・習慣化・資産管理という日常生活の生産性ツールとしては大きく上回ります。SNSで分散した情報を一元管理したい方に特に適しています。',
      ),
      (
        q: 'AIサービスが障害を起こしたらアプリが使えなくなりませんか?',
        a: 'LINE AIはOpenAI単一依存、一部のAIサービスはAnthropic単一依存のため、障害時に全機能が停止するリスクがあります。自分株式会社はAnthropic・Google Gemini・AWS Novaの3社マルチベンダー構成で、用途ごとに最適なAIを選択し、1社が障害でも他社で継続できる設計です。',
      ),
      (
        q: 'Claude Cowork (Anthropic公式) が出ましたが、何が違うの?',
        a: 'Claude Cowork (Pro \$20/月〜) は仕事のSaaS連携に特化した企業向けAIエージェントです。分離VM内で動作するため、セッションが終わるとデータが消えます。自分株式会社は「財務・健康・習慣・KPI」など人生6部署をSupabaseに永続保存し、昨日の自分と毎日比較できます。仕事だけでなく人生全体を経営したい個人CEOには、無料コアから始めて必要に応じてProへ進める自分株式会社が最適です。',
      ),
      (
        q: 'Perplexity Mac Agentに毎日のタスクを任せればよいのでは?',
        a: 'Perplexity Mac Agentは「PCの操作を代行する」ツールです。自分株式会社は代行ではなく、あなたがCEOとして最終決定権を持つ設計です（原則1）。AIは判断材料を整理し、行動はあなたが選ぶ。デスクトップ操作の自動化と、人生6部署のバランスシート管理は目的が異なります。',
      ),
      (
        q: 'OpenAI Codex DesktopとClaude Codeが競合していますが、自分株式会社はどう違うの?',
        a: 'Claude Code（423 plugins / 2,849 skills）とOpenAI Codex Desktop（Computer Use先行・20+ plugins）はツール選択の問題です。自分株式会社のai-hubは両方を含むClaude・OpenAI・Geminiを束ねる「指揮所」です。どのAIを使うかより「AIを使い分けるハブを持つか」が個人CEOの合理解。単一vendorへの依存は負債、分散が資産（原則7）。基本機能は無料で、Pro/Teamで継続支援できます。',
      ),
      (
        q: 'Notion Custom Agentsが課金されるようになりましたが?',
        a: '2026年5月4日からNotion Custom Agentsは\$10/1,000 creditの従量課金（Business/Enterprise add-on）となりました。credit残高を気にしながらAIを使うより、自分株式会社は無料コアと任意のPro/Teamを分けています。予測可能な基本利用で「KPI＝昨日の自分」を継続観察できます。',
      ),
      (
        q: 'Notion、LINE、Claude Cowork、Perplexity、Codex Desktopと比べる時の差別化軸は何ですか?',
        a: '見るべき軸は、目的の広さ、生活資本との接続、KGI/CSF/KPIの自動化、データ永続化、AIベンダー分散、無料で続けられること、そして日本語で迷わず使えることの7つです。このサイトは単体AIツールではなく、人生全体の浪費を減らす経営OSとして設計しています。',
      ),
      (
        q: 'AIベンダーを分散する意味はありますか?',
        a: 'あります。単一AIへの依存は障害、値上げ、仕様変更、品質劣化の影響をそのまま受けます。このサイトはOpenAI、Anthropic、Geminiなどを役割ごとに使い分ける前提で、継続的なモニタリングと改善を止めない設計にしています。',
      ),
      (
        q: '時間・お金・健康・体力・知能・集中力の浪費はどう減らしますか?',
        a: 'まず現状をAIが棚卸しし、KGIを決め、KGI達成に必要なCSFへ分解します。そのうえでKPIを数値化し、毎日の低ハードル行動と週次レビューに落とします。あれもこれも増やすのではなく、最初の1手を習慣化してから次へ進めます。',
      ),
      (
        q: 'KGI、CSF、KPIは毎回ユーザーが入力する必要がありますか?',
        a: '基本はAIが既存データから候補を作ります。ユーザーは提案されたKGI、CSF、KPIを確認し、必要な時だけ調整します。入力作業よりも、判断と実行に集中できることを優先しています。',
      ),
      (
        q: '継続系タスクが増えすぎて破綻しませんか?',
        a: '破綻しないよう、習慣化前のタスクを増やしすぎない仕組みにしています。未定着の行動は低ハードルの1件に絞り、3日継続や7日達成などの解除条件を満たしてから次の行動候補を開放します。',
      ),
      (
        q: 'サイトの使い方が分からない時はどうすればいいですか?',
        a: 'サイト内チャットに聞けば、画面の意味、どの機能を使うべきか、次に押すべきボタンを案内します。複雑な画面を覚えるのではなく、迷った瞬間に質問できる体験を前提にしています。',
      ),
      (
        q: 'NotebookLMなど外部AIノートとはどう使い分けますか?',
        a: 'NotebookLMは資料理解や要約に強い一方、このサイトは理解した内容をKGI/CSF/KPI、タスク、WBS、定期モニタリングへ接続します。外部AIで得た知見を、実行管理に変換する場所として使います。',
      ),
      (
        q: '法務管理ではHarvey AIをどこに使っていますか?',
        a: '法務・コンプライアンス画面のHarveyタブから、Harvey APIを使った契約レビュー、法務メモ作成、引用付き回答を実行できます。LPでは「法務管理 / Harvey AI」として、専門領域のバックエンドAIを備えていることを明示しています。',
      ),
      (
        q: 'データは安全ですか?',
        a: 'データはSupabase (PostgreSQL) に保存され、行レベルのセキュリティで各ユーザーが自分のデータのみアクセスできます。AIに送信されるのはあなたが入力したテキストのみで、第三者に販売・共有することはありません。',
      ),
      (
        q: 'AIは具体的に何をしてくれますか?',
        a: 'タスク・習慣・資産・状況をもとに「今日の最優先アクション1件」を提案します。なぜそれをすべきかの理由と、48時間以内の次の一手まで整理してくれます。MAGIシステムで3つの視点から意思決定をサポートし、AI組織OSに委任することもできます。',
      ),
      (
        q: 'スマホやタブレットでも使えますか?',
        a: 'Flutter Web製のためブラウザがあればどのデバイスでも動作します。スマホのホーム画面に追加(PWA)すると、アプリのように快適に使えます。',
      ),
      (
        q: 'すでに Notion + Slack を使っています。なぜ自分株式会社が必要ですか?',
        a: 'Notionはチームのナレッジを整理します。Slackはチームとのコミュニケーションを支えます。しかし「あなた自身の意思決定」「昨日の自分との比較」「資産・負債のバランスシート」を管理するツールはどこにも存在しません。自分株式会社はその空白を埋める個人向けライフOSです。Notionが仕事を整理するなら、自分株式会社はあなた自身を経営します。基本機能は無料で始められます。',
      ),
      (
        q: 'Notion Japan DC開設で日本市場が変わりますが、自分株式会社との違いは？',
        a: 'Notion Japan DCはエンタープライズ向けデータ居住要件への対応です。自分株式会社はすでにSupabase東京リージョンでデータを管理しており、Japan DC相当の対応は完了しています。本質的な差別化は、財務管理・AI大学(300社+の学習コンテンツ)・WBS・12インスタンスAI組織という個人CEO向け機能群です。Notionはチーム・企業向けナレッジOS、自分株式会社はあなた1人のライフOSという目的の違いがあります。',
      ),
    ];

    const primaryFaqCount = 4;
    final primaryFaqs = faqs.take(primaryFaqCount);
    final additionalFaqs = faqs.skip(primaryFaqCount);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'よくある質問',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '気になることがあればお気軽にどうぞ。',
              style: TextStyle(color: Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 12),
            for (final faq in primaryFaqs) ...[
              _FaqItem(question: faq.q, answer: faq.a),
            ],
            if (showAdditionalFaqs)
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: const Color(0x143949AB),
                ),
                child: ExpansionTile(
                  key: const Key('landing_faq_more_toggle'),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                  childrenPadding: EdgeInsets.zero,
                  iconColor: const Color(0xFF3949AB),
                  collapsedIconColor: const Color(0xFF64748B),
                  title: Text(
                    'その他の質問を見る（${faqs.length - primaryFaqCount}件）',
                    style: const TextStyle(
                      color: Color(0xFF27364A),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                  subtitle: const Text(
                    '連携・AI構成・セキュリティなどの詳細',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  children: [
                    for (final faq in additionalFaqs)
                      _FaqItem(question: faq.q, answer: faq.a),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              widget.answer,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.6,
              ),
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}
