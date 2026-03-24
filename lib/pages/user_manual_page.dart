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
            '「自分株式会社」は、メモやタスク、資産、習慣をすべて一元管理し、AIの力であなたの自己実現をサポートする統合プラットフォームです。NotionやEvernoteなどの既存ツールから移行し、より高度な知的生産を実現するための操作方法をご案内します。',
            subColor,
          ),
          const SizedBox(height: 32),
          
          _buildSectionTitle('1. ノート・メモの作成と管理', textColor),
          _buildContent(
            '・ノート作成: 画面右下の「+」ボタンから新しいノートを作成できます。Markdown記法に対応しており、リッチテキストでの装飾が可能です。\n'
            '・カテゴリとタグ: ノートを整理するために、カテゴリ分けやタグ付けを活用してください。\n'
            '・AI文章補助: エディタ内のAIボタンを押すと、文章の要約、改善案生成、次アクションの提案を自動生成します。',
            subColor,
          ),
          const SizedBox(height: 24),
          
          _buildSectionTitle('2. 競合13製品を上回る独自機能', textColor),
          _buildContent(
            '・AIエージェント組織 (MAGI System): CEO/CFO/CMO/CHROなどのペルソナを持つAIが、あなたの悩みや課題に対して多角的にアドバイスを提供します。ナビゲーションメニューから「AI役員会議」を開き、相談内容を入力してください。\n'
            '・記憶ドリル (スペーシング反復): 忘却曲線に基づき、最適なタイミングで復習を促す学習機能です。覚えたいノートを「記憶ドリルに追加」し、毎日のルーティンとして復習しましょう。\n'
            '・経営コックピット: 自分自身を「株式会社」と見立て、収支や資産を管理できます。「資産管理」タブから、毎月の収入と支出を入力し、KPIダッシュボードで推移を確認してください。',
            subColor,
          ),
          const SizedBox(height: 24),
          
          _buildSectionTitle('3. 外部アプリからの移行 (インポート)', textColor),
          _buildContent(
            '・Notion / Evernote / Markdown からのインポートに対応しています。\n'
            '・メニューの「インポート」からファイルを選択すると、Edge Functionを用いた高速処理で即座にデータが移行されます。',
            subColor,
          ),
          const SizedBox(height: 24),
          
          _buildSectionTitle('4. 公開メモと共有', textColor),
          _buildContent(
            '・作成したノートは、ワンクリックで「公開リンク」を生成し、X(Twitter)などのSNSで共有できます。\n'
            '・公開ページはSEO最適化されており、知識のシェアを通じた収益化やファン獲得に繋がります。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('5. タイマー機能と集中力管理', textColor),
          _buildContent(
            '・ポモドーロテクニックを活用できるフローティングタイマーを搭載しています。ノート作成画面の右上にあるタイマーアイコンから起動でき、作業時間を正確にトラッキングします。',
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
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF6366F1),
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