import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;

/// アプリ自体をSNSでシェアするためのサービス
class AppShareService {
  static const String appUrl = 'https://my-web-app-b67f4.web.app/';
  static const String appName = 'マイメモ';

  /// 魅力的なシェアメッセージのバリエーション
  static final List<String> shareMessages = [
    '''🎮 ゲーム感覚でメモが続く！$appName

レベルアップ、アチーブメント、ストリーク機能で
毎日のメモ習慣が楽しくなる📝✨

✅ 28種類のアチーブメント
🏆 リーダーボードでランキング競争
🔥 連続記録で習慣化をサポート
🎨 美しい共有カード機能

今すぐ無料で始めよう！👇
$appUrl

#マイメモ #メモアプリ #生産性向上 #ノート術 #デジタルメモ #習慣化アプリ #ゲーミフィケーション''',
    '''📝 メモが続かない人へ！$appName

ゲーミフィケーションで楽しくメモ習慣を身につけよう🎮

🔹 レベルアップでモチベーションUP
🔹 28種類の達成感あるアチーブメント
🔹 ストリーク機能で毎日の習慣に
🔹 リーダーボードで仲間と競争

無料で今すぐ始める！👇
$appUrl

#マイメモ #生産性 #メモ術 #習慣化 #ノートアプリ''',
    '''🚀 メモアプリの新時代！$appName

レベル、アチーブメント、ストリークで
メモがゲームのように楽しくなる！🎮✨

【主な機能】
📊 リアルタイムランキング
🏅 28種類のアチーブメント
🔥 連続記録（ストリーク）機能
🎨 SNS映えする共有カード
📝 マークダウン対応

完全無料！今すぐ体験👇
$appUrl

#マイメモ #メモアプリ #ゲーミフィケーション #生産性向上''',
  ];

  /// ランダムにシェアメッセージを取得
  static String getRandomShareMessage() {
    final now = DateTime.now();
    // 日付ベースでメッセージを選択（毎日同じユーザーは同じメッセージ）
    final index = (now.day + now.month) % shareMessages.length;
    return shareMessages[index];
  }

  /// カスタムメッセージでシェア
  static String getCustomShareMessage({
    required int level,
    required int totalPoints,
    required int currentStreak,
  }) {
    return '''🎉 私は$appNameでレベル$levelに到達しました！

📊 総ポイント: ${totalPoints}pt
🔥 連続記録: ${currentStreak}日
🏆 ランキング参加中

あなたも一緒にメモ習慣を楽しもう！✨

今すぐ無料で始める👇
$appUrl

#マイメモ #メモアプリ #レベル$level #生産性向上 #習慣化''';
  }

  /// アプリをシェアする（Web版）
  static Future<void> shareAppWeb({String? customMessage}) async {
    final message = customMessage ?? getRandomShareMessage();

    if (kIsWeb) {
      // Web版: Web Share API または Twitter インテントを使用
      try {
        // Web Share APIを試みる（モバイルブラウザなどで利用可能）
        if (html.window.navigator.share != null) {
          await html.window.navigator.share({
            'title': appName,
            'text': message,
            'url': appUrl,
          });
        } else {
          // フォールバック: クリップボードにコピー
          await Clipboard.setData(ClipboardData(text: message));
          // Twitterインテント用のURLを開く
          final twitterUrl = Uri.encodeFull(
            'https://twitter.com/intent/tweet?text=$message',
          );
          html.window.open(twitterUrl, '_blank');
        }
      } catch (e) {
        // エラー時はクリップボードにコピー
        await Clipboard.setData(ClipboardData(text: message));
        rethrow;
      }
    }
  }

  /// アプリをシェアする（モバイル版）
  static Future<void> shareAppMobile({String? customMessage}) async {
    final message = customMessage ?? getRandomShareMessage();

    try {
      await Share.share(
        message,
        subject: '$appName - ゲーミフィケーションで楽しくメモ習慣を！',
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
  }) async {
    final message = getCustomShareMessage(
      level: level,
      totalPoints: totalPoints,
      currentStreak: currentStreak,
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
      html.window.open(twitterUrl, '_blank');
    } else {
      // モバイルの場合は通常のシェア
      await shareAppMobile(customMessage: message);
    }
  }

  /// Facebook向けに最適化したシェア
  static Future<void> shareToFacebook() async {
    final facebookUrl = 'https://www.facebook.com/sharer/sharer.php?u=$appUrl';

    if (kIsWeb) {
      html.window.open(facebookUrl, '_blank');
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
      html.window.open(lineUrl, '_blank');
    } else {
      // モバイルの場合は通常のシェア
      await shareAppMobile(customMessage: message);
    }
  }
}
