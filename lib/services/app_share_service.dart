import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ✅ 修正: このインポートした機能を、以下のコード内で実際に使用するように書き換えました
import '../utils/web_image_downloader.dart';
import '../models/philosopher_quote.dart';

/// アプリ自体をSNSでシェアするためのサービス
class AppShareService {
  static const String appUrl = 'https://my-web-app-b67f4.web.app/?v=test2025';
  static const String appName = 'マイメモ';

  /// Netlify FunctionsのベースURL
  static const String netlifyBaseUrl =
      'https://melodic-cannoli-f33eaf.netlify.app';

  /// 魅力的なシェアメッセージのバリエーション
  static final List<String> shareMessages = [
    '''🎮 メモが楽しいゲームに変わる！$appName

「メモが続かない...」そんな悩みを解決！
レベルアップ×アチーブメント×ストリークで
毎日のメモ習慣が楽しく続く📝✨

━━━━━━━━━━━━━━
✨ 3つの魅力的な機能 ✨
━━━━━━━━━━━━━━

🏆 28種類の達成バッジ
   ▸ メモするたびに新しい発見
   ▸ コンプリートする楽しさ

📊 全国ランキング対決
   ▸ 仲間と切磋琢磨
   ▸ リアルタイムで順位更新

🔥 連続記録で習慣化
   ▸ 記録が伸びる喜び
   ▸ 自然と毎日続けたくなる

━━━━━━━━━━━━━━

完全無料で今すぐ体験！👇
$appUrl

#マイメモ #メモアプリ #生産性向上 #ノート術 #デジタルメモ #習慣化アプリ #ゲーミフィケーション #継続は力なり''',
    '''📝 3日坊主のあなたへ！$appName

「メモが続かない」を「毎日が楽しみ」に変える
ゲーミフィケーション型メモアプリ🎮

━━━━━━━━━━━━━━
💡 こんな人におすすめ 💡
━━━━━━━━━━━━━━

✓ メモを書いてもすぐ飽きる
✓ 達成感が欲しい
✓ 楽しく習慣を身につけたい
✓ 仲間と競い合いたい

━━━━━━━━━━━━━━
🎯 選ばれる理由 🎯
━━━━━━━━━━━━━━

🔹 メモでレベルアップ
   → RPGのような成長を実感

🔹 28種類のアチーブメント
   → 達成する喜びを毎日体験

🔹 ストリーク記録
   → 継続が可視化されてモチベUP

🔹 全国ランキング
   → 仲間と一緒に頑張れる

完全無料！今すぐスタート👇
$appUrl

#マイメモ #生産性 #メモ術 #習慣化 #ノートアプリ #三日坊主卒業 #自己成長''',
    '''🚀 新時代のメモ体験！$appName

メモがゲームになる！
「書く→レベルUP→楽しい→また書く」
この好循環で習慣化を実現🎮✨

━━━━━━━━━━━━━━
🌟 ユーザーの声 🌟
━━━━━━━━━━━━━━

「レベルが上がるのが楽しくて
 毎日メモするようになった！」

「アチーブメント集めが
 モチベーションになる！」

「ランキングで友達と競争して
 継続できてる！」

━━━━━━━━━━━━━━
✨ 主な機能 ✨
━━━━━━━━━━━━━━

📊 リアルタイムランキング
   ▸ 全国のユーザーと競争

🏅 28種類のアチーブメント
   ▸ 集める楽しさでモチベUP

🔥 ストリーク機能
   ▸ 連続記録を可視化

🎨 美しい共有カード
   ▸ SNSで自分の実績をシェア

📝 マークダウン対応
   ▸ 見やすく整理されたメモ

━━━━━━━━━━━━━━

完全無料！今すぐ体験👇
$appUrl

#マイメモ #メモアプリ #ゲーミフィケーション #生産性向上 #習慣化 #レベルアップ #継続力''',
    '''🎯 メモ習慣を変える！$appName

もうメモで挫折しない！
ゲーム要素満載の革新的メモアプリ🎮

━━━━━━━━━━━━━━
⚡ 即効性のある3つの仕組み ⚡
━━━━━━━━━━━━━━

1️⃣ 即座にレベルアップ
   メモを書くたびにレベルが上がる
   成長を実感できる喜び

2️⃣ 28種類のバッジコレクション
   様々なチャレンジをクリア
   達成感が継続を後押し

3️⃣ リアルタイムランキング
   全国のユーザーと競い合う
   仲間の存在が力になる

━━━━━━━━━━━━━━
🔥 こんな機能も 🔥
━━━━━━━━━━━━━━

✅ 連続記録（ストリーク）
✅ 美しいUIデザイン
✅ マークダウン対応
✅ 共有カード機能
✅ クラウド同期

━━━━━━━━━━━━━━

完全無料で始められる！👇
$appUrl

#マイメモ #メモアプリ #習慣化 #生産性向上 #ゲーミフィケーション #自己啓発 #継続の力''',
  ];

  /// ランダムにシェアメッセージを取得
  static String getRandomShareMessage() {
    final now = DateTime.now();
    // 日付ベースでメッセージを選択（毎日同じユーザーは同じメッセージ）
    final index = (now.day + now.month) % shareMessages.length;
    return shareMessages[index];
  }

  /// 哲学者の名言を含むシェアメッセージを取得
  static String getPhilosopherQuoteMessage() {
    final quote = PhilosopherQuote.getRandomAlways();

    return '''💭 今日の名言 - ${quote.author}

「${quote.quote}」

━━━━━━━━━━━━━━
✨ 日々の学びを記録しよう ✨
━━━━━━━━━━━━━━

$appNameは、哲学者たちの知恵とともに
あなたの学びをサポートします。

メモを書くことで：
📝 学びを深く定着させる
🎯 思考を整理する
🏆 継続の習慣を身につける

━━━━━━━━━━━━━━
🎮 ゲーム感覚で楽しく継続 🎮
━━━━━━━━━━━━━━

✨ レベルアップシステム
✨ 28種類のアチーブメント
✨ 連続記録の可視化
✨ 全国ランキング

完全無料で今すぐ始める👇
$appUrl

#マイメモ #${quote.author} #名言 #哲学 #学び #メモ習慣 #自己成長 #継続は力なり''';
  }

  /// 哲学者の名言を含むカスタムメッセージ（実績付き）
  static String getPhilosopherQuoteWithStats({
    required int level,
    required int totalPoints,
    required int currentStreak,
    String? levelTitle,
  }) {
    final quote = PhilosopherQuote.getRandomAlways();
    final title = levelTitle ?? _getLevelTitle(level);

    // レベルに応じた追加メッセージ
    String achievement = '';
    if (level >= 20) {
      achievement = '🌟 最高レベル到達！';
    } else if (level >= 15) {
      achievement = '🏆 上級者レベル！';
    } else if (level >= 10) {
      achievement = '📈 成長中！';
    } else if (level >= 5) {
      achievement = '🚀 順調に継続中！';
    } else {
      achievement = '✨ 習慣化への第一歩！';
    }

    return '''💭 今日の名言 - ${quote.author}

「${quote.quote}」

$achievement
継続の力を実感しています！

━━━━━━━━━━━━━━
💎 私の実績 💎
━━━━━━━━━━━━━━

🏆 称号: $title
📊 レベル: Lv.$level
⭐ 総ポイント: ${totalPoints.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} pt
🔥 連続記録: $currentStreak日継続中

━━━━━━━━━━━━━━

$appNameで、哲学者たちの知恵とともに
あなたも学びの習慣を始めませんか？

完全無料で今すぐ体験👇
$appUrl

#マイメモ #${quote.author} #レベル$level #$title #名言 #哲学 #習慣化 #$currentStreak日連続''';
  }

  /// カスタムメッセージでシェア
  static String getCustomShareMessage({
    required int level,
    required int totalPoints,
    required int currentStreak,
    String? levelTitle,
  }) {
    // レベルに応じた称号を取得
    final title = levelTitle ?? _getLevelTitle(level);

    // レベルに応じたメッセージをカスタマイズ
    String achievement = '';
    String encouragement = '';
    if (level >= 20) {
      achievement = '🌟✨ ついに最高位に到達！';
      encouragement = 'メモの神として君臨中！圧倒的な継続力を見せています💪';
    } else if (level >= 15) {
      achievement = '🎖️👑 上級者の仲間入り！';
      encouragement = '習慣化の達人として、日々のメモを極めています！';
    } else if (level >= 10) {
      achievement = '🏅⭐ メモマスター達成！';
      encouragement = '継続は力なり！その調子で突き進んでいます🔥';
    } else if (level >= 5) {
      achievement = '📈🎯 着実な成長を実現！';
      encouragement = 'メモ習慣が完全に身について来ました！';
    } else {
      achievement = '🚀💫 メモ習慣スタート！';
      encouragement = '楽しみながら続けています！';
    }

    // ストリークに応じた追加メッセージ
    String streakMessage = '';
    if (currentStreak >= 100) {
      streakMessage = '\n🔥 驚異の$currentStreak日連続達成！';
    } else if (currentStreak >= 50) {
      streakMessage = '\n🔥 $currentStreak日連続記録更新中！';
    } else if (currentStreak >= 30) {
      streakMessage = '\n🔥 1ヶ月以上の連続記録を達成！';
    } else if (currentStreak >= 7) {
      streakMessage = '\n🔥 1週間連続達成！';
    }

    return '''$achievement 🎉
$encouragement$streakMessage

━━━━━━━━━━━━━━
💎 私の実績を公開 💎
━━━━━━━━━━━━━━

🏆 称号: $title
📊 レベル: Lv.$level
⭐ 総ポイント: ${totalPoints.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} pt
🔥 連続記録: $currentStreak日継続中
📈 全国ランキング参加中

━━━━━━━━━━━━━━

$appNameは、ゲーム感覚で
メモ習慣が楽しく続くアプリ！

✨ レベルアップの喜び
✨ 28種類のアチーブメント
✨ リアルタイムランキング
✨ 連続記録の可視化

あなたも一緒に始めませんか？
継続の楽しさを実感できますよ！

完全無料で今すぐ体験👇
$appUrl

#マイメモ #メモアプリ #レベル$level #$title #生産性向上 #習慣化 #ゲーミフィケーション #継続は力なり #$currentStreak日連続''';
  }

  /// レベルから称号を取得
  static String _getLevelTitle(int level) {
    if (level >= 20) return 'メモの神';
    if (level >= 15) return 'メモの達人';
    if (level >= 10) return 'メモマスター';
    if (level >= 5) return 'メモの使い手';
    if (level >= 3) return 'メモ学習者';
    return 'メモ初心者';
  }

  /// アプリをシェアする（Web版）
  static Future<void> shareAppWeb({String? customMessage}) async {
    final message = customMessage ?? getRandomShareMessage();

    if (kIsWeb) {
      // Web版: Web Share API または Twitter インテントを使用
      try {
        // ✅ 修正: Web Share APIを共通ユーティリティ経由で呼び出し
        await shareWebContent(appName, message, appUrl);
      } catch (e) {
        // Web Share APIが利用できない場合（デスクトップブラウザなど）
        // フォールバック: クリップボードにコピー & Twitter インテント
        try {
          await Clipboard.setData(ClipboardData(text: message));
          // Twitterインテント用のURLを開く
          final twitterUrl = Uri.encodeFull(
            'https://twitter.com/intent/tweet?text=$message',
          );
          // ✅ 修正: 共通ユーティリティ経由でURLを開く
          openWebUrl(twitterUrl);
        } catch (clipboardError) {
          // クリップボードアクセスも失敗した場合はエラーを再スロー
          rethrow;
        }
      }
    }
  }

  /// アプリをシェアする（モバイル版）
  static Future<void> shareAppMobile({String? customMessage}) async {
    final message = customMessage ?? getRandomShareMessage();

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: '$appName - ゲーミフィケーションで楽しくメモ習慣を！',
        ),
      );
    } catch (e) {
      // エラー時はクリップボードにコピー
      await Clipboard.setData(ClipboardData(text: message));
      rethrow;
    }
  }

  /// プラットフォームに応じて適切なシェア方法を選択
  static Future<void> shareApp({String? customMessage}) async {
    if (kIsWeb) {
      await shareAppWeb(customMessage: customMessage);
    } else {
      await shareAppMobile(customMessage: customMessage);
    }
  }

  /// URLをクリップボードにコピー
  static Future<void> copyAppUrlToClipboard() async {
    await Clipboard.setData(const ClipboardData(text: appUrl));
  }

  /// ユーザーの実績を含めたシェア
  static Future<void> shareWithUserStats({
    required int level,
    required int totalPoints,
    required int currentStreak,
    String? levelTitle,
  }) async {
    final message = getCustomShareMessage(
      level: level,
      totalPoints: totalPoints,
      currentStreak: currentStreak,
      levelTitle: levelTitle,
    );
    await shareApp(customMessage: message);
  }

  /// Twitter向けに最適化したシェア
  static Future<void> shareToTwitter({String? customMessage}) async {
    final message = customMessage ?? getRandomShareMessage();
    final twitterUrl = Uri.encodeFull(
      'https://twitter.com/intent/tweet?text=$message',
    );

    if (kIsWeb) {
      // ✅ 修正: 共通ユーティリティ経由でURLを開く
      openWebUrl(twitterUrl);
    } else {
      // モバイルの場合は通常のシェア
      await shareAppMobile(customMessage: message);
    }
  }

  /// Facebook向けに最適化したシェア
  static Future<void> shareToFacebook() async {
    const facebookUrl = 'https://www.facebook.com/sharer/sharer.php?u=$appUrl';

    if (kIsWeb) {
      // ✅ 修正: 共通ユーティリティ経由でURLを開く
      openWebUrl(facebookUrl);
    } else {
      // モバイルの場合は通常のシェア
      await shareAppMobile();
    }
  }

  /// LINE向けに最適化したシェア
  static Future<void> shareToLine({String? customMessage}) async {
    final message = customMessage ?? getRandomShareMessage();
    final lineUrl = Uri.encodeFull(
      'https://line.me/R/msg/text/?$message',
    );

    if (kIsWeb) {
      // ✅ 修正: 共通ユーティリティ経由でURLを開く
      openWebUrl(lineUrl);
    } else {
      // モバイルの場合は通常のシェア
      await shareAppMobile(customMessage: message);
    }
  }

  // ==========================================
  // 動的OGP画像付きシェアリンク機能
  // ==========================================

  /// 動的OGP付きシェアリンクを生成（Netlify Functions使用）
  /// [quoteId] 名言のID（nullの場合はランダム）
  static String generateDynamicShareLink({int? quoteId}) {
    if (quoteId != null) {
      return '$netlifyBaseUrl/share?id=$quoteId';
    } else {
      // ランダムな名言ID
      final randomId = DateTime.now().microsecondsSinceEpoch %
          PhilosopherQuote.quotes.length;
      return '$netlifyBaseUrl/share?id=$randomId';
    }
  }

  /// Twitter向けシェア（動的OGP対応）
  static Future<void> shareToTwitterWithDynamicOgp({
    int? quoteId,
    int? level,
    int? totalPoints,
    int? currentStreak,
  }) async {
    // 名言IDを取得
    final selectedQuoteId = quoteId ??
        (DateTime.now().microsecondsSinceEpoch %
            PhilosopherQuote.quotes.length);

    // 動的OGPリンクを生成
    final shareLink = generateDynamicShareLink(quoteId: selectedQuoteId);

    // 名言を取得
    final quote = PhilosopherQuote
        .quotes[selectedQuoteId % PhilosopherQuote.quotes.length];

    // シェアメッセージ
    String message = '''💭 今日の名言 - ${quote.author}

「${quote.quote}」

マイメモで学びの習慣を始めよう！
$shareLink

#マイメモ #${quote.author} #名言 #哲学''';

    if (level != null && totalPoints != null && currentStreak != null) {
      message = '''💭 今日の名言 - ${quote.author}

「${quote.quote}」

✨ 私の実績 ✨
📊 レベル: Lv.$level
⭐ ポイント: $totalPoints pt
🔥 連続: $currentStreak日

マイメモで、あなたも習慣化！
$shareLink

#マイメモ #${quote.author} #レベル$level #名言''';
    }

    final twitterUrl = Uri.encodeFull(
      'https://twitter.com/intent/tweet?text=$message',
    );

    if (kIsWeb) {
      // ✅ 修正: 共通ユーティリティ経由でURLを開く
      openWebUrl(twitterUrl);
    } else {
      await shareAppMobile(customMessage: message);
    }
  }

  /// Facebook向けシェア（動的OGP対応）
  static Future<void> shareToFacebookWithDynamicOgp({int? quoteId}) async {
    final shareLink = generateDynamicShareLink(quoteId: quoteId);
    final facebookUrl =
        'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(shareLink)}';

    if (kIsWeb) {
      // ✅ 修正: 共通ユーティリティ経由でURLを開く
      openWebUrl(facebookUrl);
    } else {
      await shareAppMobile(customMessage: shareLink);
    }
  }

  /// LINE向けシェア（動的OGP対応）
  static Future<void> shareToLineWithDynamicOgp({
    int? quoteId,
    int? level,
    int? totalPoints,
    int? currentStreak,
  }) async {
    // 名言IDを取得
    final selectedQuoteId = quoteId ??
        (DateTime.now().microsecondsSinceEpoch %
            PhilosopherQuote.quotes.length);

    // 動的OGPリンクを生成
    final shareLink = generateDynamicShareLink(quoteId: selectedQuoteId);

    // 名言を取得
    final quote = PhilosopherQuote
        .quotes[selectedQuoteId % PhilosopherQuote.quotes.length];

    String message = '''💭 ${quote.author}の名言

「${quote.quote}」

マイメモで学びの習慣を！
$shareLink''';

    if (level != null && totalPoints != null && currentStreak != null) {
      message = '''💭 ${quote.author}の名言

「${quote.quote}」

私の実績: Lv.$level / $totalPoints pt / $currentStreak日連続

$shareLink''';
    }

    final lineUrl = Uri.encodeFull(
      'https://line.me/R/msg/text/?$message',
    );

    if (kIsWeb) {
      // ✅ 修正: 共通ユーティリティ経由でURLを開く
      openWebUrl(lineUrl);
    } else {
      await shareAppMobile(customMessage: message);
    }
  }

  /// URLをクリップボードにコピー（動的OGP対応）
  static Future<void> copyDynamicShareLinkToClipboard({int? quoteId}) async {
    final shareLink = generateDynamicShareLink(quoteId: quoteId);
    await Clipboard.setData(ClipboardData(text: shareLink));
  }
}
