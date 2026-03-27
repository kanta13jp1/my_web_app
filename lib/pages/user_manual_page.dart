import 'package:flutter/material.dart';

class UserManualPage extends StatelessWidget {
  const UserManualPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final accentColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF3949AB);

    return Scaffold(
      appBar: AppBar(
        title: const Text('自分株式会社 ユーザーマニュアル'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          _buildIntroCard(accentColor),
          const SizedBox(height: 24),

          _buildSectionTitle('1. ホーム画面の使い方', textColor),
          _buildContent(
            'ログイン後に「ホーム画面（経営コックピット）」が表示されます。\n\n'
            '【画面上部（スクロール不要）】\n'
            '・プロフィール未設定の場合は「プロフィールを完成させましょう」バナーが表示されます。'
            '「設定する」をタップするとプロフィール設定画面へ移動します。\n'
            '・「GROWTH ROADMAP」カード: 短期・中期・長期計画と競合21社'
            '（Notion/EverNote/MoneyForward/X/Animaworks/Claude Code/Codex/netkeiba'
            '/OpenClaw/Claude Cowork/Chatwork/Slack/ジョブカン/Amazon/Google/Microsoft/Discord/LINE/Facebook/Liven/GitHub）'
            'への進捗バーをリアルタイム表示。\n'
            '・「競合機能比較」カード: 競合21製品との機能対比をタブで確認できます（実装済み✅ / 未実装❌）。\n'
            '・「開発・成長実績」カード: 右上のドロップダウンで「今日・今週・今月・直近3ヶ月」などを選択すると開発実績一覧を表示します。\n'
            '・「今日の名言」カード: 哲学者の名言が毎日更新されます。X へのシェアや画像URLのコピーが可能です。\n\n'
            '【スクロールすると表示されるセクション（主なもの）】\n'
            '・CEO OFFICE — 緊急役員会議・朝のブリーフィング\n'
            '・CFO/CHO/CHRO OFFICE — 財務管理・健康管理・人事厚生\n'
            '・CMO/CKO OFFICE — メモ一覧・AI組織OS・Gemini大学・行動・発言レビュー\n'
            '・CSO OFFICE — 禁欲ガード・断捨離・暗記ドリル・思考アンカー\n'
            '・GROWTH / 成長導線 — インポート・成長ミッション・公開メモ一覧・ブログ投稿管理\n\n'
            '※ 各セクション内のグリッドボタン（例: 「財務管理 (CFO)」「新規事業起案」）をタップして各機能を開きます。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('2. ノート・メモの作成と管理', textColor),
          _buildContent(
            '【新規ノート作成】\n'
            'ホーム画面を下にスクロール →「CMO/CKO OFFICE」セクション →「新規事業起案」ボタンをタップ。\n'
            'エディタが開いたら、タイトルと本文を入力してください。\n\n'
            '【メモ一覧の確認】\n'
            '「CMO/CKO OFFICE」セクション →「メモ一覧 (CKO)」をタップ。\n\n'
            '【Markdown 対応】\n'
            '# 見出し1 / ## 見出し2 / **太字** / *斜体* / ``` コードブロック ``` が使えます。\n\n'
            '【AI 文章補助】\n'
            'エディタ右上の「AI」ボタンをタップ。文章の要約・改善案・次アクションを自動生成します。\n\n'
            '【公開メモへの変換】\n'
            'エディタ内の「公開」スイッチをオンにすると公開リンクを生成。'
            'X(Twitter)などで共有するとタイトルと要約がカードで表示されます（OGP対応）。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('3. 外部アプリからのデータ移行（インポート）', textColor),
          _buildContent(
            '自分株式会社は Notion / Evernote / Markdown ファイルからのインポートに対応しています。\n\n'
            '【インポート画面の開き方】\n'
            'ホーム画面を下にスクロール →「GROWTH / 成長導線」セクション →「インポート」ボタンをタップ。\n'
            '（または、アドレスバーに /import を入力してアクセス）\n\n'
            '━━━━━━━━━━━━━━━━━━━\n'
            '【Notion からのエクスポート手順】\n'
            '━━━━━━━━━━━━━━━━━━━\n'
            '1. Notion を開き（Web版: notion.so / デスクトップアプリ）、エクスポートしたいページを開く\n'
            '2. ページ右上の「…（その他のオプション）」ボタンをクリック\n'
            '3. 表示されたメニューから「エクスポート」を選択\n'
            '4. エクスポート形式:「Markdown & CSV」を選択し、「サブページを含める」をオン\n'
            '5.「エクスポート」ボタンをクリック → ZIP ファイルがダウンロードされます\n'
            '6. 自分株式会社のインポート画面で「ファイルを選択」→ダウンロードした ZIP を選択\n'
            '7.「インポート開始」をタップ → AI が自動整理して変換します\n\n'
            '━━━━━━━━━━━━━━━━━━━\n'
            '【Evernote からのエクスポート手順】\n'
            '━━━━━━━━━━━━━━━━━━━\n'
            '1. Evernote デスクトップアプリを開く（Web 版はエクスポート非対応）\n'
            '2. エクスポートしたいノートをすべて選択（Ctrl+A または Cmd+A で全選択）\n'
            '3.「ファイル」メニュー →「ノートをエクスポート」を選択\n'
            '4. 保存形式:「ENEX 形式（.enex）」を選択し「保存」\n'
            '5. 自分株式会社のインポート画面で「ファイルを選択」→ .enex ファイルを選択\n'
            '6.「インポート開始」をタップ → メモ・添付ファイルを自動インポートします\n\n'
            '━━━━━━━━━━━━━━━━━━━\n'
            '【LINE Keep / LINEメモからのデータ移行】\n'
            '━━━━━━━━━━━━━━━━━━━\n'
            '1. LINEアプリ →「Keep」または「メモ」を開く\n'
            '2. メモのテキストをコピー（長押し → コピー）\n'
            '3. 自分株式会社のメモエディタに貼り付けて保存\n\n'
            '━━━━━━━━━━━━━━━━━━━\n'
            '【Google Keep / Docs からのデータ移行】\n'
            '━━━━━━━━━━━━━━━━━━━\n'
            '1. Google Keep: keep.google.com を開く →「その他のオプション（⋮）」→「コピー」または本文をコピー\n'
            '2. Google Docs: ドキュメントを開き →「ファイル」→「ダウンロード」→「Markdown (.md)」を選択\n'
            '3. 自分株式会社のインポート画面で .md ファイルを選択 →「インポート開始」\n\n'
            '━━━━━━━━━━━━━━━━━━━\n'
            '【Microsoft OneNote からのデータ移行】\n'
            '━━━━━━━━━━━━━━━━━━━\n'
            '1. OneNote デスクトップアプリを開く\n'
            '2. エクスポートしたいページを右クリック →「ページのエクスポート」→「Word (.docx)」\n'
            '3. 保存したファイルのテキストをコピーして自分株式会社のメモエディタに貼り付け\n\n'
            '━━━━━━━━━━━━━━━━━━━\n'
            '【Markdown ファイルの直接インポート】\n'
            '━━━━━━━━━━━━━━━━━━━\n'
            '1. .md ファイルまたは .txt ファイルを用意\n'
            '2. インポート画面で「ファイルを選択」→ファイルを選択\n'
            '3.「インポート開始」をタップ\n\n'
            '※ インポート後は「CMO/CKO OFFICE」→「メモ一覧 (CKO)」でデータを確認できます。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('4. 競合21製品を上回る独自機能', textColor),
          _buildContent(
            '【AI エグゼクティブ組織 (AI組織OS)】\n'
            'ホーム画面「CMO/CKO OFFICE」セクション →「AI組織OS」をタップ。\n'
            'CEO/CFO/CMO/CHROなどのAIペルソナが多角的にアドバイスします。\n\n'
            '【記憶ドリル（スペーシング反復）】\n'
            'ホーム画面「CSO OFFICE」セクション →「暗記ドリル (日課)」をタップ。\n'
            '忘却曲線に基づいた最適タイミングで復習を促します。\n'
            'メモエディタの「記憶ドリルに追加」ボタンで教材を登録できます。\n\n'
            '【財務管理・資産管理 (CFO)】\n'
            'ホーム画面「CFO/CHO/CHRO OFFICE」セクション →「財務管理 (CFO)」をタップ。\n'
            '収入・支出・資産を記録すると資産グラフに自動反映されます。\n\n'
            '【禁欲ガード】\n'
            'ホーム画面「CSO OFFICE」セクション →「禁欲ガード」をタップ。\n\n'
            '【断捨離ツール】\n'
            'ホーム画面「CSO OFFICE」セクション →「断捨離 (デジタル)」または「断捨離 (リアル)」をタップ。\n\n'
            '【行動・発言レビュー】\n'
            'ホーム画面「CMO/CKO OFFICE」セクション →「行動・発言レビュー」をタップ。\n\n'
            '【思考アンカー】\n'
            'ホーム画面「CSO OFFICE」セクション →「思考アンカー」をタップ。\n\n'
            '【今日の名言・SNSシェア】\n'
            'ホーム画面上部の「今日の名言」カード → X でシェア / リンクコピーボタンをタップ。\n'
            '哲学者の名言を毎日1件表示し、画像付きでSNSにシェアできます。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('5. 公開メモと共有', textColor),
          _buildContent(
            '【公開メモの作成】\n'
            '1. 「CMO/CKO OFFICE」セクション →「新規事業起案」をタップしてエディタを開く\n'
            '2. メモを書いたら、エディタ内の「公開」スイッチをオンにする\n'
            '3. 保存すると公開リンク（/public-memo?id=XXX）が生成されます\n\n'
            '【公開メモの一覧】\n'
            'ホーム画面「GROWTH / 成長導線」セクション →「公開メモ一覧」をタップ。\n'
            'またはアドレスバーに /public-memos を入力。\n\n'
            '【SNS シェア時の表示】\n'
            '公開リンクを X(Twitter) などで共有すると、メモのタイトルと要約がカードで表示されます（OGP対応）。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('6. 成長ロードマップ・開発実績の確認', textColor),
          _buildContent(
            '【GROWTH ROADMAP カード（ホーム画面上部）】\n'
            '短期・中期・長期計画と競合21社に対する登録者数の進捗をリアルタイム確認できます。\n\n'
            '【開発・成長実績カード】\n'
            'ホーム画面上部の「開発・成長実績」カード右上のドロップダウンで期間を選択（今日・今週・今月・直近3ヶ月など）。\n'
            '「＋」ボタンから新しい実績を手動追加することもできます。\n\n'
            '【成長ミッション（KPI ダッシュボード）】\n'
            'ホーム画面「GROWTH / 成長導線」セクション →「成長ミッション」をタップ。\n'
            'KPI・獲得チャネル・週次ダイジェストを確認できます。\n\n'
            '【競合機能比較カード】\n'
            'ホーム画面「競合機能比較」カードをタップするとタブが展開します。\n'
            '競合21社（Notion〜GitHub）の機能一覧と本サービスの実装状況を確認できます。\n\n'
            '【競合比較ページ（SEO対応）】\n'
            'アドレスバーに /vs-notion, /vs-line, /vs-liven, /vs-github など21社分の比較ページが用意されています。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('7. AI・モーニングブリーフィング', textColor),
          _buildContent(
            '【モーニングブリーフィング】\n'
            'ホーム画面「CEO OFFICE」セクション →「モーニング・ブリーフィング」カードをタップ。\n'
            '今日の優先事項・天気・スケジュールを AI がまとめて提示します。\n\n'
            '【緊急役員会議】\n'
            '「CEO OFFICE」セクション →「緊急役員会議」カードをタップ。\n'
            'AI が今日取り組むべき最重要課題を提示します。\n\n'
            '【Gemini 大学】\n'
            'ホーム画面「CMO/CKO OFFICE」セクション →「Gemini大学」をタップ。\n'
            'AI による学習支援・質問回答を受けられます。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('8. プロフィール設定', textColor),
          _buildContent(
            '【プロフィール設定画面の開き方】\n'
            '・ホーム画面上部の「プロフィールを完成させましょう」バナー →「設定する」をタップ\n'
            '・または、アドレスバーに /profile-settings を直接入力してアクセス\n\n'
            '【設定できる項目】\n'
            '・表示名（リーダーボードに表示される名前）\n'
            '・生年月日（死生観クロックの残り時間計算に使用）\n'
            '・目標寿命（デフォルト 80 歳）\n'
            '・自己紹介（200文字以内）\n'
            '・ウェブサイト URL\n'
            '・場所\n'
            '・Twitter ハンドル (@username 形式)\n'
            '・GitHub ハンドル\n'
            '・プロフィール画像（PNG/JPG/WebP/GIF、5MB以下）\n'
            '・プロフィール公開設定（他ユーザーからの表示 ON/OFF）\n\n'
            '【保存方法】\n'
            '右上の 💾 アイコンをタップ、または画面下部の「プロフィールを保存」ボタンをタップ。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('9. 技術ブログ投稿管理', textColor),
          _buildContent(
            '毎日の技術ブログ投稿をこのアプリで管理できます。\n\n'
            '【投稿管理画面の開き方】\n'
            '・ホーム画面「GROWTH / 成長導線」セクション →「ブログ投稿管理」をタップ\n'
            '・または、アドレスバーに /tech-blog-tracker を入力\n\n'
            '【対応プラットフォーム（11種類）】\n'
            'Zenn / Qiita / はてなブログ / note / Medium / dev.to / Hashnode / Substack / GitHub Pages / NOTION / X Article\n\n'
            '【使い方】\n'
            '1. 今日投稿したプラットフォームを選択\n'
            '2.「記録する」ボタンをタップ\n'
            '3. 連続投稿ストリーク数と過去30日の投稿履歴が表示されます\n'
            '4. 未投稿の日はリマインダーとして未投稿バッジが表示されます\n\n'
            '【Claude Code Schedule による自動化】\n'
            'blog-draft タスク（毎朝08:00 JST実行）が直近のコミット内容を元に\n'
            'ブログ下書きを docs/blog-drafts/ に自動生成し、blog_posts テーブルに記録します。\n'
            '管理者ダッシュボード（要: 管理者権限）の「ブログ投稿管理」カードから\n'
            'draft → posted へのステータス更新・投稿URLの記録が可能です。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('10. ゲーミフィケーション・チャレンジ・報酬', textColor),
          _buildContent(
            '【ログインストリーク】\n'
            'ホーム画面上部に「連続ログイン日数」カードが表示されます。\n'
            '毎日アクセスすると連続日数が増え、3日・7日・30日・100日・365日でバッジが変わります（✨→⚡→🔥→🏆→👑）。\n\n'
            '【デイリーチャレンジ】\n'
            'ホーム画面の「デイリーチャレンジ」カードで今日のタスクを確認できます。\n'
            '1. チャレンジが未生成の場合は「チャレンジを生成する」ボタンをタップ\n'
            '2. 各チャレンジのプログレスバーで進捗を確認\n'
            '3. 完了したチャレンジの「受け取る」ボタンをタップしてポイントを獲得\n\n'
            '【報酬・実績バッジ】\n'
            'ホーム画面のデイリーチャレンジカード直下の「報酬・実績バッジを確認する」をタップ。\n'
            'または、アドレスバーに /rewards を入力してアクセス。\n'
            '獲得ポイント・レベル・実績バッジを確認できます。\n\n'
            '【アクティビティフィード】\n'
            'ホーム画面「開発・成長実績」カード直下の「アクティビティフィード」をタップ。\n'
            'または、アドレスバーに /activity-feed を入力。\n'
            '自分の行動履歴・他ユーザーの公開アクティビティを確認できます。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('11. 機能リクエスト', textColor),
          _buildContent(
            '欲しい機能をリクエストできます。他のユーザーの投票数が多いものから優先的に実装されます。\n\n'
            '【機能リクエスト画面の開き方】\n'
            '・アドレスバーに /feature-requests を入力\n\n'
            '【使い方】\n'
            '1.「新しいリクエストを追加」フォームにタイトルと詳細を入力\n'
            '2.「送信」をタップ\n'
            '3. 既存のリクエストに👍投票して優先度を上げることができます\n'
            '4. ステータスが「対応中」「実装完了」に変わるとメールで通知が届きます（メールアドレス入力時）',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('12. 友達招待（リファラル）', textColor),
          _buildContent(
            '友達を招待して一緒に使いましょう。\n\n'
            '【招待リンクのコピー方法】\n'
            'ホーム画面上部の「友達を招待する」カード →「リンクコピー」ボタンをタップ。\n'
            '紹介コード付きURLがクリップボードにコピーされます。\n'
            'X(Twitter)・LINE・Slack などでシェアしてください。\n\n'
            '【管理者向け: スケジュールタスク監視】\n'
            'Claude Code Schedule の実行状況は管理者ダッシュボードの\n'
            '「スケジュールタスク監視」カードで確認できます（要: 管理者権限）。\n\n'
            '【管理者ダッシュボードへのアクセス】\n'
            '・アドレスバーに /admin を直接入力（最速）\n'
            '・ホーム画面を下にスクロール →「GROWTH / 成長導線」→「管理者ダッシュボード」\n'
            '・ホーム画面「OFFICE KPI SNAPSHOT」セクション →「分析を見る」をタップ',
            subColor,
          ),
          _buildSectionTitle('13. Edge Functions 実装状況', textColor),
          _buildContent(
            'ホーム画面最下部の「Edge Functions 実装状況」カードで、バックエンド API の UI 連携状況を確認できます。\n\n'
            '【見方】\n'
            '・ヘッダー右の進捗バー: 全 Edge Functions のうち UI 実装済みの割合（%）\n'
            '・カードをタップすると展開:\n'
            '  - 🟠 UI 未実装/未連携: 今後 cs-check Schedule が自動実装します\n'
            '  - ✅ UI 実装済み + 操作手順: どのページから呼び出せるかを表示\n'
            '・「Edge Functions 詳細・テストページ」ボタン → 各 Function を手動テスト可能\n\n'
            '【自動化】\n'
            'cs-check Schedule タスク（毎時実行）が UI 未連携の Function を検出し、\n'
            '自動でページ・ルート・ホームメニューを追加してコミット・プッシュします。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('14. プロフィール完成度', textColor),
          _buildContent(
            'ホーム画面の「プロフィール完成度」カードで、自分のプロフィールの埋まり具合を確認できます。\n\n'
            '【完成度の計算対象（7項目）】\n'
            '表示名 / アイコン画像 / 自己紹介 / 場所 / Twitter / GitHub / Web サイト URL\n\n'
            '【色の意味】\n'
            '・青（0〜49%）: 基本情報を入力しましょう\n'
            '・黄（50〜74%）: もう少し！\n'
            '・緑（75〜100%）: プロフィールが充実しています\n\n'
            '【100% 達成後】\n'
            '「プロフィール完成 🎉」バッジに切り替わります。\n\n'
            '【注意】一部の機能（暗記ドリル・断捨離・AI 組織 OS など）は「ロック」されており、\n'
            'ホーム画面の必須導線（プロフィール設定・メモ作成など）を完了すると開放されます。\n'
            'ロックされた機能は「先に必須導線を完了してください」と表示されます。',
            subColor,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('15. Claude Code Schedule 自動タスク一覧', textColor),
          _buildContent(
            '以下のタスクが定期的に自動実行されています（管理者ダッシュボードで実行状況を確認可能）。\n\n'
            '【毎時実行: cs-check】\n'
            '・CS チケット対応（FAQ 返信 / バグ修正 / エスカレーション）\n'
            '・Edge Function UI 自動連携（UI 未実装の Function に自動でページ追加）\n'
            '・GitHub PR コードレビュー\n'
            '・コード品質問題を GitHub Issue として自動登録\n'
            '・self-heal: flutter analyze エラーを自動修正\n\n'
            '【毎日 08:00 JST 実行: blog-draft】\n'
            '・直近のコミット内容から技術ブログ下書きを自動生成\n'
            '・Zenn / Qiita / note / はてなブログ / Medium / dev.to / Hashnode / Substack / GitHub Pages / NOTION / X Article の 11 プラットフォーム向けにフォーマット変換\n'
            '・投稿管理テーブル（blog_posts）に記録\n\n'
            '【毎日 09:00 JST 実行: daily-report】\n'
            '・日次メトリクス取得・レポート生成\n'
            '・X (@kanta13jp1) への自動投稿\n'
            '・GitHub Issue の自動修復（claude-code-review / bug ラベル付き）\n'
            '・Schedule タスクの実行状況を schedule_task_runs テーブルに記録\n\n'
            '【毎週月曜 09:00 JST 実行: weekly-sns-draft】\n'
            '・週次 SNS 投稿ドラフト生成\n'
            '・依存パッケージの脆弱性チェック\n\n'
            '【管理者ダッシュボードでの確認方法】\n'
            'ホーム → GROWTH / 成長導線 →「管理者ダッシュボード」をタップ\n'
            '→「Schedule タスク実行状況」カードで最終実行日時・ステータスを確認できます。',
            subColor,
          ),
          const SizedBox(height: 32),

          Center(
            child: Column(
              children: [
                Icon(Icons.info_outline, size: 18, color: subColor),
                const SizedBox(height: 6),
                Text(
                  'マニュアルは機能追加・UI変更に合わせて随時更新されます。\n最終更新: 2026-03-28 (session32)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: subColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildIntroCard(Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor.withAlpha(30), accentColor.withAlpha(10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                '自分株式会社へようこそ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'メモ・タスク・資産・習慣をすべて一元管理し、AIの力で自己実現をサポートする統合プラットフォームです。'
            'Notion・Evernote・MoneyForward・LINE・Facebook・Liven・GitHub など21の競合サービスを超える機能を完全無料で提供します。',
            style: TextStyle(fontSize: 13, height: 1.6),
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
