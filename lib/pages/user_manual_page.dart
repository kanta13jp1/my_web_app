import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class _ManualSection {
  final String title;
  final IconData icon;
  final Color color;
  final List<_ManualStep> steps;
  final String? note;

  const _ManualSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.steps,
    this.note,
  });
}

class _ManualStep {
  final String heading;
  final String body;

  const _ManualStep({required this.heading, required this.body});
}

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

const _sections = <_ManualSection>[
  // -----------------------------------------------------------------------
  _ManualSection(
    title: 'はじめに — アカウント作成とログイン',
    icon: Icons.person_add_outlined,
    color: Color(0xFF6366F1),
    steps: [
      _ManualStep(
        heading: 'ランディングページへアクセス',
        body:
            'ブラウザで自分株式会社のURLを開くと、ランディングページが表示されます。'
            '「無料で始める」ボタンをタップしてください。',
      ),
      _ManualStep(
        heading: 'メールアドレスとパスワードを入力',
        body: 'メールアドレスと8文字以上のパスワードを入力し、「アカウント作成」をタップします。'
            '確認メールが届いたらリンクをクリックして認証完了です。',
      ),
      _ManualStep(
        heading: 'ログイン',
        body: '以降は同じメールアドレスとパスワードでログインできます。'
            'パスワードを忘れた場合は「パスワードを忘れた」リンクからリセットできます。',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  _ManualSection(
    title: 'ノートを作成・編集する',
    icon: Icons.edit_note,
    color: Color(0xFF22C55E),
    steps: [
      _ManualStep(
        heading: '新規ノートを作成する',
        body: 'ホーム画面右下の「＋」ボタンをタップすると新規ノート作成画面が開きます。'
            'タイトルと本文を入力して保存してください。',
      ),
      _ManualStep(
        heading: 'Markdown で書式を付ける',
        body:
            '本文には Markdown 記法が使えます。\n'
            '• **太字** → **テキスト**\n'
            '• 見出し → # 見出し1 / ## 見出し2\n'
            '• リスト → - 項目\n'
            '• コードブロック → ``` コード ```',
      ),
      _ManualStep(
        heading: 'カテゴリ・タグを設定する',
        body: 'ノート編集画面でカテゴリとタグを設定できます。'
            'カテゴリページからカテゴリ別一覧を確認できます。',
      ),
      _ManualStep(
        heading: 'ノートを編集・削除する',
        body: 'ノート一覧からノートをタップして詳細を開きます。'
            '右上の編集アイコンで編集、削除アイコンで削除できます。',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  _ManualSection(
    title: 'AI アシスタントを使う',
    icon: Icons.auto_awesome,
    color: Color(0xFFA855F7),
    steps: [
      _ManualStep(
        heading: 'AI Secretary を呼び出す',
        body: 'ノート編集画面の右上にある AI アイコンをタップすると'
            'AI Secretary メニューが開きます。',
      ),
      _ManualStep(
        heading: '文章を改善・要約する',
        body: '「改善」を選ぶと選択中のテキストを AI が書き直します。'
            '「要約」を選ぶと長文をコンパクトにまとめます。',
      ),
      _ManualStep(
        heading: '次のアクションを生成する',
        body: '「次のアクション生成」を選ぶと、ノートの内容から'
            '具体的な行動案を AI が提案します。',
      ),
      _ManualStep(
        heading: 'AI モデルを切り替える',
        body: 'ホームメニューの「AI ステータス」から使用する AI モデルを変更できます。'
            'Claude / Gemini / GPT 等の複数モデルに対応しています。',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  _ManualSection(
    title: 'AI エージェント組織 (MAGI System) を使う',
    icon: Icons.groups_outlined,
    color: Color(0xFFF59E0B),
    steps: [
      _ManualStep(
        heading: 'エージェント組織を開く',
        body: 'ホームメニューから「エージェント組織」を選択します。'
            'CEO・CFO・CMO・CHRO の役員 AI が表示されます。',
      ),
      _ManualStep(
        heading: '役員に相談する',
        body: '各役員をタップして質問を入力します。\n'
            '• CEO: 事業戦略・意思決定\n'
            '• CFO: 財務・資金計画\n'
            '• CMO: マーケティング・成長戦略\n'
            '• CHRO: 採用・組織設計',
      ),
      _ManualStep(
        heading: '緊急会議を開く',
        body: '「緊急会議」ボタンをタップすると全役員が一斉に回答します。'
            '重要な意思決定の際に複数の視点を得られます。',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  _ManualSection(
    title: 'ノートを公開する',
    icon: Icons.public,
    color: Color(0xFF3B82F6),
    steps: [
      _ManualStep(
        heading: 'ノートを公開設定にする',
        body: 'ノート編集画面の「公開設定」スイッチをオンにすると、'
            '誰でも閲覧できる公開ノートになります。',
      ),
      _ManualStep(
        heading: '共有リンクをコピーする',
        body: '公開設定後、「リンクをコピー」ボタンが表示されます。'
            'このリンクを SNS や LINE でシェアできます。',
      ),
      _ManualStep(
        heading: '公開メモ一覧を確認する',
        body: 'ホームメニューの「公開メモ」から全ユーザーの公開ノート一覧を閲覧できます。'
            'OGP 対応しているため SNS でシェアするとサムネイルが表示されます。',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  _ManualSection(
    title: 'データをインポートする',
    icon: Icons.upload_file_outlined,
    color: Color(0xFF14B8A6),
    steps: [
      _ManualStep(
        heading: 'インポート画面を開く',
        body: 'ホームメニューの「インポート」またはトップメニューから'
            'インポート画面にアクセスします。',
      ),
      _ManualStep(
        heading: 'Notion からインポートする',
        body: 'Notion で「エクスポート → CSV」を実行してファイルをダウンロードします。'
            'インポート画面で「Notion (CSV)」カードをタップし、'
            'ダウンロードした CSV ファイルを選択します。',
      ),
      _ManualStep(
        heading: 'Evernote からインポートする',
        body: 'Evernote でノートブックを右クリックして「エクスポート → .enex」を保存します。'
            'インポート画面で「Evernote (ENEX)」カードをタップし、'
            '.enex ファイルを選択します。',
      ),
      _ManualStep(
        heading: 'Markdown ファイルをインポートする',
        body: '.md / .txt ファイルをインポートできます。'
            '「Markdown」カードをタップしてファイルを選択してください。',
      ),
      _ManualStep(
        heading: 'プレビューを確認してインポートを確定する',
        body: 'ファイル選択後にプレビューが表示されます。'
            'ノート件数と内容を確認したら「インポートする」ボタンをタップして完了です。',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  _ManualSection(
    title: 'マインドマップを使う',
    icon: Icons.account_tree_outlined,
    color: Color(0xFFEC4899),
    steps: [
      _ManualStep(
        heading: 'マインドマップを開く',
        body: 'ホームメニューから「マインドマップ」を選択します。',
      ),
      _ManualStep(
        heading: 'ノードを追加する',
        body: '中心ノードをタップして「子ノードを追加」を選択します。'
            'テキストを入力して保存すると新しいブランチが作成されます。',
      ),
      _ManualStep(
        heading: 'マインドマップをノートに変換する',
        body: '「ノートに変換」ボタンをタップするとマインドマップの構造が'
            'Markdown のアウトライン形式のノートとして保存されます。',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  _ManualSection(
    title: '記憶ドリルを使う',
    icon: Icons.psychology_outlined,
    color: Color(0xFF8B5CF6),
    steps: [
      _ManualStep(
        heading: '記憶ドリルを開く',
        body: 'ホームメニューの「記憶ドリル」から学習セッションを開始します。',
      ),
      _ManualStep(
        heading: 'フラッシュカードを作成する',
        body: '「カードを追加」ボタンから問題文と解答を入力します。'
            'ノートから自動生成することもできます。',
      ),
      _ManualStep(
        heading: 'スペーシング反復で学習する',
        body: 'ドリルモードでカードが表示されます。'
            '「覚えた / まだ」をタップすると次回の出題タイミングが自動調整されます。'
            '定着率が上がるにつれて出題間隔が広がります。',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  _ManualSection(
    title: '収支・家計を管理する',
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFFF59E0B),
    steps: [
      _ManualStep(
        heading: '収支を入力する',
        body: 'ホーム画面の収支カード、または「収支入力」ボタンから'
            '収入・支出・振替を記録できます。金額・カテゴリ・日付を入力してください。',
      ),
      _ManualStep(
        heading: '月間カレンダーで確認する',
        body: 'ホーム画面の月間カレンダーでは日別の収入・支出が表示されます。'
            '日付をタップすると詳細シートが開き、その日の収支サマリーを確認できます。',
      ),
      _ManualStep(
        heading: '月次収支を分析する',
        body: 'カレンダー上部の月次サマリーで収入合計・支出合計・差額を確認できます。'
            '差額がプラスなら黒字、マイナスなら赤字です。',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  _ManualSection(
    title: '資産を管理する',
    icon: Icons.savings_outlined,
    color: Color(0xFF22C55E),
    steps: [
      _ManualStep(
        heading: '資産管理画面を開く',
        body: 'ホームの収支詳細シートの「資産管理」ボタン、または'
            'ナビゲーションメニューから「資産管理」を選択します。',
      ),
      _ManualStep(
        heading: '資産を登録する',
        body: '銀行口座・証券・現金・その他の資産を手動で入力できます。'
            'カテゴリ別に管理され、総資産が自動集計されます。',
      ),
      _ManualStep(
        heading: '資産推移を確認する',
        body: '月次の資産残高が記録され、グラフで推移を確認できます。'
            'KPI ダッシュボードで目標値と実績を比較できます。',
      ),
    ],
  ),

  // -----------------------------------------------------------------------
  _ManualSection(
    title: '紹介プログラム (Referral) を使う',
    icon: Icons.card_giftcard_outlined,
    color: Color(0xFFEC4899),
    steps: [
      _ManualStep(
        heading: '紹介コードを取得する',
        body: 'ホームメニューの「紹介プログラム」から自分専用の紹介コードを確認できます。'
            '初回アクセス時に自動発行されます。',
      ),
      _ManualStep(
        heading: '友人に紹介する',
        body: '紹介コードまたは紹介リンクを友人に共有します。'
            '友人が登録すると自動的に紹介として記録されます。',
      ),
      _ManualStep(
        heading: '紹介報酬を確認する',
        body: '紹介が成立すると 500 ポイントが付与されます。'
            '「紹介プログラム」画面で紹介人数・成立数・獲得ポイントを確認できます。',
      ),
    ],
    note: '不正利用防止のため、1日あたり5件・登録1時間未満のアカウントへの適用は制限されています。',
  ),

  // -----------------------------------------------------------------------
  _ManualSection(
    title: 'Growth ロードマップを見る',
    icon: Icons.flag_outlined,
    color: Color(0xFF6366F1),
    steps: [
      _ManualStep(
        heading: 'ホーム画面最上部のカードを確認する',
        body: 'ホーム画面の最上部に「GROWTH ROADMAP」カードが表示されています。\n'
            '短期・中期・長期計画の達成率と、各種競合 (Notion / EverNote / MoneyForward / X / Animaworks / Claude code / Codex / netkeiba / OpenClaw / Claude works / Chatwork / Slack / ジョブカン) との'
            '登録者数比較の進捗がリアルタイムで確認できます。',
      ),
      _ManualStep(
        heading: '競合機能比較カードを使う',
        body: 'GROWTH ROADMAP カードの下にある「競合機能比較」カードをタップすると展開します。\n'
            '競合13製品のタブを切り替えて、'
            '各競合との機能カバー率と実装状況を確認できます。',
      ),
      _ManualStep(
        heading: '開発実績カードを確認する',
        body: 'ホーム画面の「開発実績」カードでは、今日〜過去10年、すべての期間をドロップダウンで切り替え、'
            'ユーザー獲得や機能利用の成長シグナルを確認できます。',
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class UserManualPage extends StatelessWidget {
  const UserManualPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final bgColor =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('ユーザーマニュアル'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Intro banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '自分株式会社 — 使い方ガイド',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '実装済み全機能の操作手順をまとめています。'
                  'セクションをタップすると詳細が展開します。',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Section list
          ..._sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SectionCard(section: section, subColor: subColor),
            ),
          ),
          const SizedBox(height: 16),
          // Footer note
          Text(
            'このマニュアルは実装済み機能を対象としています。\n'
            'ロードマップに記載された未実装機能は順次追加されます。',
            style: TextStyle(fontSize: 12, color: subColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section card
// ---------------------------------------------------------------------------

class _SectionCard extends StatefulWidget {
  final _ManualSection section;
  final Color subColor;

  const _SectionCard({required this.section, required this.subColor});

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF1A2233) : const Color(0xFFFFFFFF);
    final borderColor =
        isDark ? const Color(0xFF2A3A55) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final section = widget.section;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: section.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(section.icon, size: 20, color: section.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      section.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: section.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${section.steps.length} ステップ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: section.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: widget.subColor,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (_expanded) ...[
            Divider(height: 1, color: borderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...section.steps.asMap().entries.map(
                    (entry) => _StepRow(
                      index: entry.key + 1,
                      step: entry.value,
                      color: section.color,
                      textColor: textColor,
                      subColor: widget.subColor,
                    ),
                  ),
                  if (section.note != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              section.note!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step row
// ---------------------------------------------------------------------------

class _StepRow extends StatelessWidget {
  final int index;
  final _ManualStep step;
  final Color color;
  final Color textColor;
  final Color subColor;

  const _StepRow({
    required this.index,
    required this.step,
    required this.color,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number badge
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.heading,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  step.body,
                  style: TextStyle(fontSize: 12, color: subColor, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
