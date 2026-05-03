---
title: "インディー開発者のグロース戦略 — グロースループ・紹介設計・Analytics の実践"
tags: 個人開発,buildinpublic,Flutter,programming
published: true
---

「良いものを作れば売れる」は幻想です。インディー開発者がユーザーを増やすには、製品設計の段階からグロースの仕組みを組み込む必要があります。本記事ではグロースループの設計から紹介リワード、コンテンツマーケティング、Analytics まで、コードレベルで実践できる手法を解説します。

## 1. グロースループ vs ファネル

**ファネル**（従来型）は一方通行です: 広告 → LP → 登録 → 課金。ユーザーが離脱したら終わりです。

**グロースループ**は自己増殖します。ユーザーの行動が次のユーザーを呼ぶ仕組みを設計します。

```text
グロースループの例:
  ユーザーがコンテンツ作成
  → 共有ボタンでシェア
  → 新規ユーザーが閲覧
  → 登録してコンテンツ作成
  → ループが回り続ける
```

| ループ種別 | 例 | 主な施策 |
|------------|-----|---------|
| Viral / 共有 | Figma の共有リンク | ShareCard, SNS 投稿 |
| Content | Notion のパブリックページ | SEO 最適化、OGP |
| 紹介 (Referral) | Dropbox の「友達を招待」 | 紹介コード、双方特典 |
| Product-led | Slack の無料プラン | フリーミアム + アップグレード導線 |

## 2. Viral Coefficient の計算

```dart
/// K-factor (バイラル係数) を計算する
/// K > 1 で指数成長、K < 1 で線形成長
class ViralMetrics {
  /// [invitesSentPerUser] 1 ユーザーが送る平均招待数
  /// [conversionRate] 招待 → 登録の転換率 (0.0 〜 1.0)
  static double kFactor({
    required double invitesSentPerUser,
    required double conversionRate,
  }) =>
      invitesSentPerUser * conversionRate;

  /// 初期ユーザー数から N サイクル後のユーザー数を予測
  static int projectGrowth({
    required int initialUsers,
    required double k,
    required int cycles,
  }) {
    if (k >= 1) {
      // 等比数列: U_n = U_0 * (k^cycles - 1) / (k - 1)
      return (initialUsers * (pow(k, cycles) - 1) / (k - 1)).round();
    } else {
      // 収束: U_∞ ≈ U_0 / (1 - k)
      return (initialUsers / (1 - k)).round();
    }
  }
}

// Supabase で計測
Future<ViralStats> fetchViralStats() async {
  final result = await supabase.rpc('get_viral_stats');
  return ViralStats.fromJson(result as Map<String, dynamic>);
}
```

```sql
-- Edge Function / RPC で使うビュー
CREATE OR REPLACE FUNCTION get_viral_stats()
RETURNS json AS $$
  SELECT json_build_object(
    'total_invites_sent',     COUNT(*) FILTER (WHERE type = 'invite'),
    'invites_converted',      COUNT(*) FILTER (WHERE type = 'invite' AND converted = true),
    'conversion_rate',        ROUND(
                                COUNT(*) FILTER (WHERE type = 'invite' AND converted = true)::numeric /
                                NULLIF(COUNT(*) FILTER (WHERE type = 'invite'), 0), 3
                              ),
    'avg_invites_per_user',   ROUND(AVG(invites_per_user), 2)
  )
  FROM referral_events
  CROSS JOIN LATERAL (
    SELECT COUNT(*) AS invites_per_user
    FROM referral_events r2 WHERE r2.referrer_id = referral_events.referrer_id
  ) sub
$$ LANGUAGE sql;
```

## 3. 紹介システムの実装

```dart
import 'package:share_plus/share_plus.dart';

class ReferralService {
  static const _baseUrl = 'https://your-app.com';

  /// 紹介コードを生成または取得
  Future<String> getReferralCode(String userId) async {
    final existing = await supabase
        .from('referral_codes')
        .select('code')
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) return existing['code'] as String;

    // 新規作成
    final code = _generateCode(userId);
    await supabase.from('referral_codes').insert({
      'user_id': userId,
      'code': code,
      'created_at': DateTime.now().toIso8601String(),
    });
    return code;
  }

  String _generateCode(String userId) {
    // ユーザー ID の先頭 6 文字 + ランダム 4 文字
    final prefix = userId.replaceAll('-', '').substring(0, 6).toUpperCase();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final suffix = List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
    return '$prefix$suffix';
  }

  /// 招待リンクをシェア
  Future<void> shareInvite({
    required String code,
    required String senderName,
    String? customMessage,
  }) async {
    final url = '$_baseUrl/join?ref=$code';
    final message = customMessage ??
        '$senderName があなたをアプリに招待しています！\n'
        '登録すると 2 人とも 30 日間プレミアムが無料になります。\n\n$url';

    await Share.share(message, subject: '招待リンク');
    await _trackInviteSent(code);
  }

  Future<void> _trackInviteSent(String code) async {
    await supabase.from('referral_events').insert({
      'code': code,
      'type': 'invite_sent',
      'sent_at': DateTime.now().toIso8601String(),
    });
  }

  /// 登録時に紹介コードを処理
  Future<ReferralReward?> processReferral({
    required String newUserId,
    required String referralCode,
  }) async {
    final referrer = await supabase
        .from('referral_codes')
        .select('user_id')
        .eq('code', referralCode)
        .maybeSingle();

    if (referrer == null) return null;

    final referrerId = referrer['user_id'] as String;

    // 双方に報酬を付与（idempotent）
    await supabase.rpc('grant_referral_reward', params: {
      'p_referrer_id': referrerId,
      'p_new_user_id': newUserId,
      'p_code': referralCode,
    });

    return const ReferralReward(
      daysGranted: 30,
      message: '紹介ありがとうございます！30 日間のプレミアムを付与しました。',
    );
  }
}

class ReferralReward {
  final int daysGranted;
  final String message;
  const ReferralReward({required this.daysGranted, required this.message});
}
```

### ShareCard Widget

```dart
class ShareCard extends StatelessWidget {
  final String referralCode;
  final String userName;

  const ShareCard({
    super.key,
    required this.referralCode,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$userName の招待',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '登録すると 2 人とも\n30 日間無料プレミアム',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  referralCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: referralCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('コードをコピーしました')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## 4. UTM トラッキング

```dart
class UtmService {
  static const _storage = FlutterSecureStorage();

  /// アプリ起動時に UTM パラメータを保存
  static Future<void> captureFromUrl(Uri uri) async {
    final params = {
      'utm_source': uri.queryParameters['utm_source'],
      'utm_medium': uri.queryParameters['utm_medium'],
      'utm_campaign': uri.queryParameters['utm_campaign'],
      'utm_content': uri.queryParameters['utm_content'],
      'ref': uri.queryParameters['ref'], // 紹介コード
    }..removeWhere((_, v) => v == null);

    if (params.isNotEmpty) {
      await _storage.write(
        key: 'first_touch_utm',
        value: jsonEncode(params),
      );
    }
  }

  static Future<Map<String, String?>> getFirstTouch() async {
    final raw = await _storage.read(key: 'first_touch_utm');
    if (raw == null) return {};
    return Map<String, String?>.from(jsonDecode(raw) as Map);
  }

  /// 登録時に属性情報を送信
  static Future<void> attributeRegistration(String userId) async {
    final utm = await getFirstTouch();
    if (utm.isEmpty) return;

    await supabase.from('user_attributions').insert({
      'user_id': userId,
      'utm_source': utm['utm_source'],
      'utm_medium': utm['utm_medium'],
      'utm_campaign': utm['utm_campaign'],
      'referral_code': utm['ref'],
      'attributed_at': DateTime.now().toIso8601String(),
    });
  }
}
```

## 5. Analytics — Plausible / PostHog / Supabase

```dart
// 軽量イベントトラッキング（Supabase で自前実装）
class Analytics {
  static Future<void> track(
    String event, {
    Map<String, dynamic>? properties,
  }) async {
    final user = supabase.auth.currentUser;
    await supabase.from('analytics_events').insert({
      'user_id': user?.id,
      'event': event,
      'properties': properties ?? {},
      'page': _currentPage,
      'session_id': _sessionId,
      'occurred_at': DateTime.now().toIso8601String(),
    });
  }

  static String get _sessionId => _sessionIdValue ??= _generateSessionId();
  static String? _sessionIdValue;
  static String _generateSessionId() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36);

  static String _currentPage = '/';
  static void setPage(String page) => _currentPage = page;
}

// 使用例
await Analytics.track('referral_shared', properties: {'code': code});
await Analytics.track('feature_used', properties: {'feature': 'meal_log'});
await Analytics.track('subscription_started', properties: {'plan': 'pro'});
```

## 6. コンテンツマーケティングと SEO

Flutter Web で OGP タグを動的に設定する方法:

```dart
// SEO サービス
class SeoService {
  static void setMeta({
    required String title,
    required String description,
    String? imageUrl,
    String? canonicalUrl,
  }) {
    // Flutter Web: index.html の meta タグを JS 経由で更新
    // または go_router + flutter_web_plugins でサーバーサイド生成
    if (kIsWeb) {
      html.document.title = title;
      _setMetaTag('description', description);
      _setMetaTag('og:title', title);
      _setMetaTag('og:description', description);
      if (imageUrl != null) _setMetaTag('og:image', imageUrl);
      if (canonicalUrl != null) _setLinkTag('canonical', canonicalUrl);
    }
  }

  static void _setMetaTag(String name, String content) {
    var element = html.document.querySelector('meta[name="$name"]') ??
        html.document.querySelector('meta[property="$name"]');
    if (element == null) {
      element = html.MetaElement()..setAttribute('name', name);
      html.document.head!.append(element);
    }
    element.setAttribute('content', content);
  }

  static void _setLinkTag(String rel, String href) {
    var element = html.document.querySelector('link[rel="$rel"]');
    if (element == null) {
      element = html.LinkElement()..setAttribute('rel', rel);
      html.document.head!.append(element);
    }
    element.setAttribute('href', href);
  }
}
```

## まとめ

グロース施策は「作る前に設計する」のが鉄則です。

1. **ループ設計** → どのアクションがユーザーを呼ぶかを定義
2. **紹介システム** → 双方特典 + ワンクリック共有
3. **UTM トラッキング** → どのチャネルが効いているかを計測
4. **Analytics** → 施策の効果を定量化してループを改善

K-factor が 0.3 でも、それは 1 人のユーザーが 0.3 人を連れてくる = 全体で 43% のオーガニック増加を意味します。次回は Dart パッケージの公開方法を解説します。
