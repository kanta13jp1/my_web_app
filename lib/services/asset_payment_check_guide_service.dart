import 'package:intl/intl.dart';

/// 「この負債の引き落としが実際に行われたか」をユーザー自身が金融機関で確認する
/// ための手順を生成する純関数サービス。
///
/// 決定論的なベース手順(口座名・支払予定日・金額から即時生成)は AI 不在でも必ず
/// 有用な手順を返す。加えて、ネット検索対応プロバイダ(perplexity 等)へ渡すプロンプトを
/// 組み立て、その金融機関の正式アプリ名・ログイン導線・取引明細の場所など具体手順を
/// 引き出す。AI 経路はオンライン時の拡張で、失敗/無効時はベース手順だけで完結する。
/// I/O を持たないため単体テストが容易。
class AssetPaymentCheckGuideService {
  const AssetPaymentCheckGuideService();

  /// 決定論的な確認手順。AI が使えなくても必ず返す。
  ///
  /// [billingCardName] が指定されたとき(= その負債が「カード請求にまとめて支払い」)
  /// は、銀行口座の入出金明細ではなく **そのカードの利用明細** で計上を確認する手順を
  /// 返す。実際の口座引き落としはカードの締め日にまとめて行われ、個別額では引き落と
  /// されないため、銀行明細での個別照合は誤りになる。
  String buildBaseGuide({
    required String debtName,
    String? paymentSourceAccountName,
    DateTime? paymentDate,
    int? paymentDay,
    double? paymentAmount,
    String? billingCardName,
  }) {
    final card = (billingCardName ?? '').trim();
    if (card.isNotEmpty) {
      return _buildCardBilledBaseGuide(
        debtName: debtName,
        cardName: card,
        paymentDate: paymentDate,
        paymentDay: paymentDay,
        paymentAmount: paymentAmount,
      );
    }
    final account = (paymentSourceAccountName ?? '').trim();
    final accountLabel = account.isEmpty ? '引き落とし元の口座' : account;
    final dateLabel = _dateLabel(paymentDate, paymentDay);
    final amountLabel = _amountLabel(paymentAmount);
    final buffer = StringBuffer()
      ..writeln('「$debtName」の引き落としを確認する手順:')
      ..writeln('1. $accountLabel のネットバンキングまたはスマホアプリにログインします。')
      ..writeln('2. 普通預金口座の「入出金明細（取引明細）」を開きます。');
    if (amountLabel != null) {
      buffer.writeln(
        '3. $dateLabel に $amountLabel の引き落とし（$debtName）があるか確認します。',
      );
    } else {
      buffer.writeln('3. $dateLabel 前後に $debtName の引き落としがあるか確認します。');
    }
    buffer
      ..writeln('4. 引き落としが確認できたら「支払済み」にチェックを入れます。')
      ..write(
        '5. 明細に無い場合は残高不足などで引き落としに失敗している可能性があるため、'
        '入金してから再度確認してください。',
      );
    return buffer.toString();
  }

  /// カード請求にまとめて支払う負債の確認手順(= [billingCardName] の利用明細で計上確認)。
  String _buildCardBilledBaseGuide({
    required String debtName,
    required String cardName,
    DateTime? paymentDate,
    int? paymentDay,
    double? paymentAmount,
  }) {
    final dateLabel = _dateLabel(paymentDate, paymentDay);
    final amountLabel = _amountLabel(paymentAmount);
    final buffer = StringBuffer()
      ..writeln('「$debtName」は $cardName の請求にまとめて支払われます。確認する手順:')
      ..writeln('1. $cardName のアプリまたは Web 明細にログインします。')
      ..writeln('2. 「ご利用明細（利用照会）」を開きます。');
    if (amountLabel != null) {
      buffer.writeln(
        '3. $dateLabel 頃に $amountLabel の $debtName の利用が計上されているか確認します。',
      );
    } else {
      buffer.writeln('3. $dateLabel 頃に $debtName の利用が計上されているか確認します。');
    }
    buffer
      ..writeln('4. 計上を確認できたら「支払済み」にチェックを入れます。')
      ..write(
        '5. 実際の口座引き落としは $cardName の引き落とし日にまとめて行われます'
        '（この負債だけが個別に引き落とされるわけではありません）。'
        '引き落としが不安なときは $cardName の引き落とし元口座の残高を確認してください。',
      );
    return buffer.toString();
  }

  /// ネット検索対応プロバイダへ渡すプロンプト。その金融機関に即した具体手順を求める。
  ///
  /// [billingCardName] が指定されたとき(= カード請求にまとめて支払い)は、銀行の
  /// 入出金明細ではなく **そのカードの利用明細** で計上を確認する手順を求める。
  String buildAiPrompt({
    required String debtName,
    String? paymentSourceAccountName,
    DateTime? paymentDate,
    int? paymentDay,
    double? paymentAmount,
    String? billingCardName,
  }) {
    final card = (billingCardName ?? '').trim();
    final dateLabel = _dateLabel(paymentDate, paymentDay);
    final amountLabel = _amountLabel(paymentAmount) ?? '利用額';
    if (card.isNotEmpty) {
      return [
        'あなたは家計管理アシスタントです。日本の利用者が、ある支払いがカードの利用',
        '明細に計上されたかを自分で確認する手順を、そのカード発行会社に即して案内して',
        'ください。',
        '対象: 「$debtName」は $card の請求にまとめて支払われます。',
        '確認したいこと: $dateLabel 頃に $amountLabel の $debtName の利用が計上されているか。',
        '出力要件:',
        '- $card の公式アプリ名／Web 明細名と、ログインから利用明細にたどり着くまでの',
        '  操作手順を、番号付きで簡潔に。',
        '- 実際の口座引き落としはカードの引き落とし日にまとめて行われ、この負債だけが',
        '  個別に引き落とされるわけではない点を補足する。',
        '- 不確かな点は断定せず、公式サイト/アプリで確認するよう促す。',
        '- 日本語。手順以外の前置きは最小限に。',
      ].join('\n');
    }
    final account = (paymentSourceAccountName ?? '').trim();
    final accountClause = account.isEmpty ? '引き落とし元の金融機関口座' : account;
    final fallbackAmountLabel = _amountLabel(paymentAmount) ?? '引き落とし額';
    return [
      'あなたは家計管理アシスタントです。日本の利用者が、ある引き落としが実際に',
      '行われたかを自分で確認する手順を、その金融機関に即して具体的に案内してください。',
      '対象: 「$debtName」の引き落とし。引き落とし元: $accountClause。',
      '確認したいこと: $dateLabel 前後に $fallbackAmountLabel の引き落としがあるか。',
      '出力要件:',
      '- その金融機関の公式アプリ名／ネットバンキング名と、ログインから入出金明細に',
      '  たどり着くまでの操作手順を、番号付きで簡潔に。',
      '- 不確かな点は断定せず、公式サイト/アプリで確認するよう促す。',
      '- 日本語。手順以外の前置きは最小限に。',
    ].join('\n');
  }

  String _dateLabel(DateTime? paymentDate, int? paymentDay) {
    if (paymentDate != null) {
      return DateFormat('M月d日').format(paymentDate);
    }
    if (paymentDay != null) {
      return '毎月$paymentDay日';
    }
    return '支払予定日';
  }

  String? _amountLabel(double? paymentAmount) {
    if (paymentAmount == null || paymentAmount <= 0) {
      return null;
    }
    return '${NumberFormat('#,##0').format(paymentAmount.round())}円';
  }
}
