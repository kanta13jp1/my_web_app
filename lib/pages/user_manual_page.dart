import 'package:flutter/material.dart';

class UserManualPage extends StatelessWidget {
  const UserManualPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('自分株式会社 ユーザーマニュアル'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          _buildSectionTitle('はじめに', textColor),
          _buildContent(
            '「自分株式会社」は、メモやタスク、資産、習慣をすべて一元管理し、AIの力であなたの自己実現をサポートする統合プラットフォームです。'
            'NotionやEvernoteなどの既存ツールから移行し、より高度な知的生産を実現するための操作方法をご案内します。',
            subColor,
          ),
          const SizedBox(height: 32),

          _buildSectionTitle('1. ホーム画面（経営コックピット）の使い方', textColor),
          _buildContent(
            'ログイン後に表示される「経営コックピット」がホーム画面です。\n\n'
            '【画面上部の固定エリア】\n'
            '・GROWTH ROADMAP カード: 短期・中期・長期計画と競合13社への進捗バーをリアルタイム表示。\n'
            '・競合機能比較カード: 競合13製品（Notion/EverNote/MoneyForward/X/Animaworks/Claude Code/Codex/netkeiba/OpenClaw/Claude Cowork/Chatwork/Slack/ジョブカン）との機能対比をタブで確認できます。\n'
            '・開発・成長実績カード: 右上のドロップダウンで期間を選択すると、その期間の開発実績一覧を表示します（今日・今週・今月など）。\n\n'
            '【スクロールすると表示されるセクション（上から順）】\n'
            '1. 今月のキャッシュフロー確認ウィジェット\n'
            '2. 次の最優先アクション提案（AIナッジ）\n'
            '3. 必須タスク＆ロック解除ガイド\n'
            '4. 前日超え目標進捗\n'
            '5. 禁欲ガード状態\n'
            '6. CEO OFFICE（役員会議・モーニングブリーフィング）\n'
            '7. OFFICE KPI SNAPSHOT（CFO / CMO / CHO / CHRO の部門KPI）\n'
            '8. KPI SUMMARY（資産グラフ・マーケティング指標）\n'
            '9. OPERATIONS CALENDAR（月次カレンダー・日次ステータス）\n'
            '10. SPECIAL PROJECT（選挙戦略室など）\n'
            '11. CSO OFFICE（禁欲ガード・断捨離・暗記ドリルなど）\n'
            '12. CFO/CHO/CHRO OFFICE（財務管理・健康管理・人事厚生）\n'
            '13. CMO/CKO OFFICE（市場分析・AI組織OS・メモ一覧・マインドマップなど）\n'
            '14. GROWTH / 成長導線（インポート・成長ミッション・公開メモ一覧）\n\n'
            '・右上の ⚙️ アイコンから設定ページへ、🌙/☀️ アイコンでダーク/ライトテーマを切り替えられます。\n'
            '・下に引っ張るとデータを最新状態に更新できます（Pull-to-Refresh）。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('2. ノート・メモの作成と管理', textColor),
          _buildContent(
            '・ノート作成: ホーム画面の「CMO/CKO OFFICE」セクション→「新規事業起案」をタップするとエディタが開きます。\n'
            '・メモ一覧: 同セクションの「メモ一覧 (CKO)」からすべてのメモを確認・検索できます。\n'
            '・Markdown記法に対応しており、# 見出し・** 太字・``` コードブロックなどが使えます。\n'
            '・カテゴリとタグ: エディタ内でカテゴリを指定してメモを整理できます。\n'
            '・AI文章補助: エディタ内のAIボタンを押すと、文章の要約・改善案・次アクションを自動生成します。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('3. 競合13製品を上回る独自機能', textColor),
          _buildContent(
            '・AIエグゼクティブ組織 (AI組織OS): ホーム画面「CMO/CKO OFFICE」セクション→「AI組織OS」をタップすると、CEO/CFO/CMO/CHROなどのAIペルソナが多角的にアドバイスします。\n\n'
            '・記憶ドリル（スペーシング反復）: 「CSO OFFICE」セクション→「暗記ドリル (日課)」をタップ。忘却曲線に基づいた最適タイミングで復習を促します。メモエディタの「記憶ドリルに追加」ボタンで教材を登録できます。\n\n'
            '・経営コックピット（KPI管理）: ホーム画面自体が経営コックピットです。「CFO/CHO/CHRO OFFICE」セクション→「財務管理 (CFO)」から収支・資産を記録し、「KPI SUMMARY」セクションで推移グラフを確認できます。\n\n'
            '・マインドマップ: 「CMO/CKO OFFICE」セクション→「マインドマップ (思考整理)」をタップ。\n\n'
            '・禁欲ガード: 「CSO OFFICE」セクション→「禁欲ガード」をタップ。習慣の逸脱を記録・防止します。\n\n'
            '・断捨離ツール: 「CSO OFFICE」セクション→「断捨離 (デジタル)」または「断捨離 (リアル)」をタップ。デジタルファイルの整理やリアル物品の写真撮影から断捨離を進めます。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('4. 外部アプリからの移行（インポート）', textColor),
          _buildContent(
            '・Notion / Evernote / Markdown からのインポートに対応しています。\n'
            '・ホーム画面最下部「GROWTH / 成長導線」セクション→「インポート」をタップします。\n'
            '・または、未ログイン時のランディングページの「インポート」ボタンからも利用できます。\n'
            '・ファイルを選択すると、Supabase Edge Function を用いた高速処理でデータが移行されます。\n'
            '・インポート後はホーム画面でデータを確認できます。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('5. 公開メモと共有', textColor),
          _buildContent(
            '・作成したノートは、エディタ内の「公開」ボタンでワンクリックで公開リンクを生成できます。\n'
            '・ホーム画面「GROWTH / 成長導線」セクション→「公開メモ一覧」で公開中のメモを一覧表示します。\n'
            '・公開ページはSEO最適化されており、X(Twitter)などのSNSで共有すると、タイトルと要約がカードとして表示されます（OGP対応）。\n'
            '・URLは /public-memo?id=XXX の形式で、SNSシェア時にメモの内容がプレビュー表示されます。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('6. タイマー機能と集中力管理', textColor),
          _buildContent(
            '・ポモドーロテクニックを活用できるフローティングタイマーを搭載しています。\n'
            '・ノート作成画面（新規事業起案）の右上にあるタイマーアイコンから起動できます。\n'
            '・作業時間を正確にトラッキングします。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('7. 成長ロードマップ・開発実績の確認', textColor),
          _buildContent(
            '・ホーム画面最上部の「GROWTH ROADMAP」カードで、短期・中期・長期計画および競合13社（Notion / EverNote / MoneyForward / X / Animaworks / Claude Code / Codex / netkeiba / OpenClaw / Claude Cowork / Chatwork / Slack / ジョブカン）に対する登録者数の進捗をリアルタイムで確認できます。\n\n'
            '・「競合機能比較」カードをタップすると競合各社の機能一覧と本サービスの実装状況が表示されます。タブで競合を切り替えられます（実装済み・部分実装・開発中・未実装・独自機能の5段階）。\n\n'
            '・「開発・成長実績」カードの右上のドロップダウンで期間を選択し（今日・今週・今月など）、その期間の開発実績を確認できます。「＋」ボタンから新しい実績を手動追加することもできます。\n\n'
            '・「GROWTH / 成長導線」セクション→「成長ミッション」から、KPI・獲得チャネル・週次ダイジェストを確認できます。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('8. AI・モーニングブリーフィング', textColor),
          _buildContent(
            '・毎日の朝、ホーム画面「CEO OFFICE」セクションの「モーニングブリーフィング」をタップして今日の優先事項を確認します。\n'
            '・「AI緊急役員会議」ボタンから AI が今日取り組むべき最重要課題を提示します。\n'
            '・Gemini大学（CMO/CKO OFFICE セクション→「Gemini大学」）では AI による学習支援を受けられます。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('9. 財務管理・資産管理 (CFO)', textColor),
          _buildContent(
            '・ホーム画面「CFO/CHO/CHRO OFFICE」セクション→「財務管理 (CFO)」をタップ。\n'
            '・収入・支出・資産を記録すると、「KPI SUMMARY」セクションの総資産グラフに自動反映されます。\n'
            '・毎月の cashflow レビューをホーム画面の最優先カードとして表示します。',
            subColor,
          ),
          const SizedBox(height: 32),

          Center(
            child: Text(
              'マニュアルは開発・実装に合わせて随時更新されます。',
              style: TextStyle(fontSize: 12, color: subColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.only(bottom: 4.0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildContent(String content, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Text(
        content,
        style: TextStyle(
          fontSize: 14,
          height: 1.8,
          color: color,
        ),
      ),
    );
  }
}
