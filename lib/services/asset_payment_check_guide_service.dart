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
  String buildBaseGuide({
    required String debtName,
    String? paymentSourceAccountName,
    DateTime? paymentDate,
    int? paymentDay,
    double? paymentAmount,
  }) {
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

  /// ネット検索対応プロバイダへ渡すプロンプト。その金融機関に即した具体手順を求める。
  String buildAiPrompt({
    required String debtName,
    String? paymentSourceAccountName,
    DateTime? paymentDate,
    int? paymentDay,
    double? paymentAmount,
  }) {
    final account = (paymentSourceAccountName ?? '').trim();
    final accountClause = account.isEmpty ? '引き落とし元の金融機関口座' : account;
    final dateLabel = _dateLabel(paymentDate, paymentDay);
    final amountLabel = _amountLabel(paymentAmount) ?? '引き落とし額';
    return [
      'あなたは家計管理アシスタントです。日本の利用者が、ある引き落としが実際に',
      '行われたかを自分で確認する手順を、その金融機関に即して具体的に案内してください。',
      '対象: 「$debtName」の引き落とし。引き落とし元: $accountClause。',
      '確認したいこと: $dateLabel 前後に $amountLabel の引き落としがあるか。',
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
