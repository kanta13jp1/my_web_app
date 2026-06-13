import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'feature_tap_logger.dart';

/// ピン留めが変化したら increment され、お気に入りセクションが再読込する。
final ValueNotifier<int> homePinnedFeaturesRevision = ValueNotifier<int>(0);

/// home tier チップ/リスト共通の遷移処理。
/// 利用履歴 (user_feature_usage) に記録してから named route へ遷移する。
Future<void> openHomeFeature(BuildContext context, String route, String label) {
  unawaited(recordFeatureTap(route, label));
  return Navigator.pushNamed(context, route);
}

/// 機能をお気に入り (user_pinned_features) に追加する。長押しから呼ばれる。
Future<void> pinHomeFeature(
  BuildContext context,
  String route,
  String label,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('お気に入りに追加するにはログインが必要です')),
    );
    return;
  }
  try {
    await Supabase.instance.client.from('user_pinned_features').upsert(
      {
        'user_id': user.id,
        'feature_route': route,
        'feature_label': label,
      },
      onConflict: 'user_id,feature_route',
    );
    homePinnedFeaturesRevision.value++;
    messenger?.showSnackBar(
      SnackBar(content: Text('「$label」をお気に入り（ピン止め）に追加しました')),
    );
  } catch (_) {
    messenger?.showSnackBar(const SnackBar(content: Text('お気に入りへの追加に失敗しました')));
  }
}
