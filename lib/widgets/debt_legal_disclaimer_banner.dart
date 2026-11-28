import 'package:flutter/material.dart';

/// 法的・契約上の注意点コンポーネントを表示するコンテキスト区分。
enum DebtLegalNoticeContext {
  consolidation,
  overpaymentAndSimulation,
  debtReliefConsultation,
}

/// 公的機関・専門家団体などの中立的な相談窓口リンク情報。
class DebtConsultationResource {
  final String id;
  final String title;
  final String subtitle;
  final String url;
  final String? phoneHint;

  const DebtConsultationResource({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.url,
    this.phoneHint,
  });
}

/// 借り換え・繰り上げ返済・債務整理に関する中立的な法的注意喚起・免責事項バナー (#2750 / #1369 / #1370)。
class DebtLegalDisclaimerBanner extends StatelessWidget {
  final DebtLegalNoticeContext contextType;
  final bool compact;

  const DebtLegalDisclaimerBanner({
    super.key,
    required this.contextType,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final String heading;
    final List<String> lines;
    switch (contextType) {
      case DebtLegalNoticeContext.consolidation:
        heading = 'おまとめローン検討時の法的・契約上の注意点（中立情報）';
        lines = const <String>[
          '・過払い金請求への影響: おまとめローンで既存の借入先を完済・一本化すると、'
              '完済時点から過払い金返還請求権の消滅時効（最終取引日から原則10年、'
              '2020年4月以降の終了は知った時から5年または行使可能な時から10年の早い方）'
              'が進行する場合や、同一貸金業者での借換え・和解条項により扱いが変わる場合があります。'
              '2010年以前からの長期借入等がある場合は、一本化契約の前に弁護士・司法書士や公的窓口へ確認してください。',
          '・総支払額増加の注意点: 利率が下がっても返済期間を長期化した場合や手数料・保証料が発生する場合、'
              '総支払利息・総支払額が増えることがあります。',
          '・免責事項: 本画面の試算・案内は一般的な概算・参考情報であり、'
              '個別の法的助言や審査結果・減額効果を保証するものではありません。',
        ];
      case DebtLegalNoticeContext.overpaymentAndSimulation:
        heading = '試算に関するご注意（概算）';
        lines = const <String>[
          '日割り利息（残高 × 実質年率 ÷ 365 × 日数）および月次シミュレーションは概算です。'
              '実際の約定日・うるう年・端数処理・最低返済額ルールにより金融機関の請求額と異なる場合があります。'
              '個別の法的・金融判断は専門家へご確認ください。',
        ];
      case DebtLegalNoticeContext.debtReliefConsultation:
        heading = '債務整理・相談窓口に関する中立的なご案内';
        lines = const <String>[
          '債務整理の手続き選択可否や影響（信用情報への登録期間、保証人・担保資産への影響など）は個別事情により異なります。'
              '本画面は一般的な概要と公的・中立的な相談窓口の案内であり、特定の事務所や手続きを推奨するものではありません。',
        ];
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF94A3B8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  heading,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final line in lines) ...<Widget>[
            Text(
              line,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                color: const Color(0xFF334155),
                height: 1.5,
              ),
            ),
            if (line != lines.last) const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
