import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_repayment_simulation_service.dart';

/// 借金返済の月次進捗カード用データ (借金返済コミュニティ向けの公開投稿)。
///
/// 🔒 **開示範囲は型で固定する**。このカードは当事者として実名で公開の場に
/// 投稿されるため、身元特定・与信審査・就業に波及しうる情報は
/// **フィールドとして持たない**。載せる/載せないの判断をUI側の書き忘れに
/// 依存させると、一度の事故で取り消し不能な開示になる。
///
/// 載せる: 残債総額 / 今月の返済予定額 / 完済予定 / 利息見込み / 前月比 / 件数
/// 載せない: 年収・月収 / 口座残高 / 借入先名 / 勤務先 / 支払元口座
class DebtProgressCardData {
  /// 残債総額 (円 / 正の値)。
  final double totalDebt;

  /// 今月の返済予定額の合計 (円)。
  final double monthlyPayment;

  /// 現在の返済額を続けた場合の完済までの月数。
  /// null = 現在の返済額では完済しない (返済が利息に追いつかない等)。
  final int? payoffMonths;

  /// 完済までに支払う利息の見込み総額 (円)。
  /// payoffMonths が null のときは信頼できる総額を出せないので null。
  final double? estimatedInterest;

  /// 前月比の残債増減 (円 / 負値 = 減った)。
  /// null = 比較できる前月データが無い。
  final double? monthOverMonthDelta;

  /// 返済対象の負債件数。**名前は持たない** (借入先が分かると特定に繋がる)。
  final int debtCount;

  const DebtProgressCardData({
    required this.totalDebt,
    required this.monthlyPayment,
    required this.payoffMonths,
    required this.estimatedInterest,
    required this.monthOverMonthDelta,
    required this.debtCount,
  });

  /// 前月より残債が減ったか。前月データが無いときは null。
  bool? get isImproving {
    final delta = monthOverMonthDelta;
    if (delta == null) return null;
    return delta < 0;
  }

  /// 完済予定を「◯年◯ヶ月」に整形する。完済しない場合は null。
  String? get payoffLabel {
    final months = payoffMonths;
    if (months == null) return null;
    if (months < 12) return '$monthsヶ月';
    final years = months ~/ 12;
    final rest = months % 12;
    return rest == 0 ? '$years年' : '$years年$restヶ月';
  }
}

/// ワークブックから進捗カードのデータを組み立てる純サービス。
///
/// Supabase / 認証 / ネットワークに依存しない。
class DebtProgressCardService {
  const DebtProgressCardService();

  /// 投稿の下書き文面を組み立てる。
  ///
  /// **草案であって確定文ではない**。投稿前にユーザーが必ず編集できる前提で、
  /// 界隈の慣習 (残債・今月の返済・完済目標を淡々と report する) に寄せた
  /// たたき台を返す。
  ///
  /// 🔒 ここでも開示境界を守る: [DebtProgressCardData] が持たない情報は
  /// そもそも参照できないので、文面に年収・口座残高・借入先名は混入しない。
  String buildDraftText(
    DebtProgressCardData card, {
    required DateTime month,
    List<String> hashtags = const <String>['#借金返済', '#家計簿'],
  }) {
    final lines = <String>[
      '【${month.year}年${month.month}月の返済報告】',
      '残債 ${_yen(card.totalDebt)}${_deltaSuffix(card.monthOverMonthDelta)}',
      '今月の返済 ${_yen(card.monthlyPayment)}',
    ];
    final payoff = card.payoffLabel;
    if (payoff != null) {
      lines.add('このペースで完済まで あと$payoff');
    } else {
      // 完済しない見込みを黙って省くと、報告として誠実でなくなる。
      lines.add('※ 今の返済額だと元金が減りません(要見直し)');
    }
    final interest = card.estimatedInterest;
    if (interest != null) {
      lines.add('完済までの利息見込み ${_yen(interest)}');
    }
    if (hashtags.isNotEmpty) {
      lines
        ..add('')
        ..add(hashtags.join(' '));
    }
    return lines.join('\n');
  }

  /// カード画像を置く Storage 上のパス。
  ///
  /// 🔴 先頭セグメントは **必ず userId**。`debt-progress-cards` の RLS は
  /// `(storage.foldername(name))[1] = auth.uid()` で他人のフォルダへの
  /// 書き込みを弾いているため、ここが崩れると保存自体が失敗する。
  ///
  /// 同月に作り直しても衝突しないよう [uniqueSuffix] を末尾に付ける
  /// (upsert にすると「投稿済みの画像が後から差し替わる」事故が起きる)。
  String buildCardStoragePath({
    required String userId,
    required DateTime month,
    required String uniqueSuffix,
  }) {
    final ym = '${month.year}${month.month.toString().padLeft(2, '0')}';
    return '$userId/debt_progress_${ym}_$uniqueSuffix.png';
  }

  /// 画像の代替テキスト (X の alt)。
  ///
  /// 🔒 カードに描かれているのと同じ範囲だけを書く。alt は画像より機械可読な
  /// ので、ここに余分な情報を足すと開示範囲が静かに広がる。
  String buildCardAltText(
    DebtProgressCardData card, {
    required DateTime month,
  }) {
    final parts = <String>[
      '${month.year}年${month.month}月の返済報告カード',
      '残債 ${_yen(card.totalDebt)}',
      '今月の返済 ${_yen(card.monthlyPayment)}',
    ];
    final payoff = card.payoffLabel;
    parts.add(payoff == null ? '現在の返済額では完済しない見込み' : '完済まであと$payoff');
    return parts.join(' / ');
  }

  /// X への投稿ペイロードを組み立てる。
  ///
  /// 🔴 [text] には**ユーザーが編集した後の文面**を渡すこと。ここで
  /// 下書きを再生成すると、本人が直した内容が捨てられて意図しない文が
  /// 公開される (HITL が形骸化する)。
  ///
  /// [mediaUrl] を渡すと画像付き投稿になる。null/空なら**テキストのみ**で
  /// 投稿する — 画像のアップロードに失敗しても投稿自体は成立させたい
  /// (数字が伝われば報告として機能するため)。
  Map<String, dynamic> buildPostPayload(
    DebtProgressCardData card, {
    required DateTime month,
    String? text,
    String? mediaUrl,
  }) {
    final resolvedMedia = (mediaUrl ?? '').trim();
    return <String, dynamic>{
      'action': 'x.post',
      'text': text ?? buildDraftText(card, month: month),
      if (resolvedMedia.isNotEmpty) ...<String, dynamic>{
        'mediaUrl': resolvedMedia,
        'mediaType': 'image',
        'mediaAlt': buildCardAltText(card, month: month),
      },
      'source': 'debt_progress_card',
      'variant': 'debt_progress_report',
      'utmContent': 'debt_progress_card',
      'route': '/asset-management',
      'promptProfile': 'debt_progress_report_v1',
      'contentKind': 'data_report',
      'contentArchetype': 'data_report',
      'experimentKey': 'x_first_user_growth_10k',
      // 🔴 URL は本文に残す。リプライへ逃がすと流入が落ちることが実測済み
      // ([[session_20260728_part346_x_acquisition_rerank]])。
      'linkInReply': false,
    };
  }

  String _deltaSuffix(double? delta) {
    if (delta == null) return '';
    if (delta == 0) return '(前月比 ±0円)';
    final sign = delta < 0 ? '-' : '+';
    return '(前月比 $sign${_yen(delta.abs())})';
  }

  static String _yen(double value) {
    final rounded = value.round();
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '${rounded < 0 ? '-' : ''}$buffer円';
  }

  /// 完済月数と利息見込みの算出基準に使う戦略。
  ///
  /// 繰り上げ返済なし (extra = 0) の比較なので戦略差はほぼ出ないが、
  /// **カードの数字が実行ごとにブレないよう固定する**。
  static const AssetLiabilityRepaymentSimulationStrategy _basisStrategy =
      AssetLiabilityRepaymentSimulationStrategy.interestRate;

  /// 進捗カードを組み立てる。返済対象の負債が無ければ null。
  ///
  /// [priorBalancesByAccountId] は前月の残高スナップショット
  /// (`AssetAccountBalanceHistoryStore.priorMonthBalances` /
  /// **accountId -> 利用残高の絶対額 (正の値)**)。空なら前月比は null。
  DebtProgressCardData? build({
    required AssetLiabilityWorkbook workbook,
    Map<String, double> priorBalancesByAccountId = const <String, double>{},
  }) {
    const simulation = AssetLiabilityRepaymentSimulationService();
    // 繰り上げ返済なしの基準プラン = 「今のままだとこうなる」。
    final result = simulation.buildComparison(workbook: workbook);
    final basis = result.baselinePlanFor(_basisStrategy);
    if (basis == null || basis.priorityRows.isEmpty) return null;

    // 🔑 対象集合はシミュレーションが選んだものをそのまま使う。
    // ここで自前の絞り込み条件を書くと、カードの「残債総額」と
    // 「完済予定」が別々の集合を指し、合わない数字を公開してしまう。
    final eligibleIds = <String>{
      for (final row in basis.priorityRows) row.id,
    };

    final payoffMonths = basis.estimatedPayoffMonths;
    // 完済しない場合の利息総額はシミュレーション打ち切り時点の部分和でしかなく、
    // 「完済までに払う利息」として出すと実際より小さい額を約束することになる。
    final estimatedInterest =
        payoffMonths == null ? null : basis.estimatedInterestTotal;

    return DebtProgressCardData(
      totalDebt: basis.startingBalanceTotal,
      monthlyPayment: result.baseMonthlyPayment,
      payoffMonths: payoffMonths,
      estimatedInterest: estimatedInterest,
      monthOverMonthDelta: _monthOverMonthDelta(
        workbook: workbook,
        eligibleIds: eligibleIds,
        priorBalancesByAccountId: priorBalancesByAccountId,
      ),
      debtCount: basis.priorityRows.length,
    );
  }

  /// 前月比を出す。
  ///
  /// 🔴 **符号規約が両者で違う**: ワークブックの負債 `balance` は負値、
  /// 履歴ストアの前月残高は絶対額 (正)。素直に引き算すると符号が反転し、
  /// 返済が進んでいるのに「増えた」と公開投稿してしまう。両辺とも
  /// **絶対額に正規化**してから比較する。
  ///
  /// 🔑 **前月に記録が無い負債は比較から除外する**。0円として扱うと、
  /// 記録を始めたばかりの負債が「今月まるごと増えた」ように見える。
  /// 比較可能な行が1件も無ければ null (= カードに前月比を出さない)。
  double? _monthOverMonthDelta({
    required AssetLiabilityWorkbook workbook,
    required Set<String> eligibleIds,
    required Map<String, double> priorBalancesByAccountId,
  }) {
    if (priorBalancesByAccountId.isEmpty) return null;
    double current = 0;
    double prior = 0;
    var comparable = 0;
    for (final row in workbook.debtMasterRows) {
      if (!eligibleIds.contains(row.id)) continue;
      final priorBalance = priorBalancesByAccountId[row.id];
      if (priorBalance == null) continue;
      current += row.balance.abs();
      prior += priorBalance.abs();
      comparable += 1;
    }
    if (comparable == 0) return null;
    return current - prior;
  }
}
