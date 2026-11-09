import 'package:flutter/material.dart';

/// A dated editorial note about the text submitted to the 222nd Diet.
class DietSupportBillMemo extends StatefulWidget {
  const DietSupportBillMemo({
    super.key,
    required this.fontSize,
    required this.source,
  });

  final double fontSize;
  final Widget Function(String label, Uri uri) source;

  @override
  State<DietSupportBillMemo> createState() => _DietSupportBillMemoState();
}

class _DietSupportBillMemoState extends State<DietSupportBillMemo> {
  bool _legal = false;

  static final _bill = Uri.parse(
    'https://www.shugiin.go.jp/internet/itdb_gian.nsf/html/gian/honbun/houan/g22209001.htm',
  );
  static final _progress = Uri.parse(
    'https://www.shugiin.go.jp/internet/itdb_gian.nsf/html/gian/keika/1DE342E.htm',
  );
  static final _briefing = Uri.parse(
    'https://www.fsa.go.jp/common/conference/minister/2026b/20261009-1.html',
  );
  static final _hearing = Uri.https('www.shugiintv.go.jp', '/jp/index.php', {
    'ex': 'VL',
    'deli_id': '56466',
    'time': '22942.4',
  });

  Widget _heading(String title) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _body(String text) => Text(
        text,
        style: TextStyle(fontSize: widget.fontSize, height: 1.55),
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('法案メモ　飲食料品の消費税と働く人への支援金'),
        subtitle: const Text('第222回国会・閣法第1号　提出時案\n2026年11月9日確認'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('やわらか版'),
                selected: !_legal,
                onSelected: (_) => setState(() => _legal = false),
              ),
              ChoiceChip(
                label: const Text('法律用語版'),
                selected: _legal,
                onSelected: (_) => setState(() => _legal = true),
              ),
            ],
          ),
          if (_legal)
            _body(
              '正式名称　租税及び社会保険料による負担の軽減のための飲食料品に係る'
              '消費税率の臨時的な引下げ及び就業者負担軽減支援金の支給に関する法律案',
            ),
          _heading('飲食料品の税率（第2条）'),
          _body(
            _legal
                ? '2027年4月1日から2029年3月31日まで、対象となる飲食料品の国内での譲渡や'
                    '保税地域からの引取りに係る国税の消費税率を0.78％とする特例。'
                    '地方消費税込みの税率は1％で、契約時期などによる例外がある。'
                : '軽減税率の対象となる飲食料品の消費税を、地方分と合わせて1％に下げる案です。'
                    '期間は2027年4月1日から2029年3月31日までの2年間で、契約時期などによる例外があります。',
          ),
          widget.source('税率についての大臣説明（10月9日）', _briefing),
          _heading('支援金を受け取れる人（第9条）'),
          _body(
            _legal
                ? '前年の勤労所得が所得下限額を超え、前年の合計所得金額が所得上限額以下であり、'
                    '住民税額等を基に社会保険料控除額や公的年金等収入を反映した額が純負担基準額を超えることなどを要求する。'
                    '基準日に国内住所が必要。2027・2028年度は配偶者所得要件を適用せず、扶養児童の年齢基準は16歳未満とする。'
                : '前年に働いて得た所得、所得全体、住民税や社会保険料・年金収入を使って計算する負担を見て、対象者を決める案です。'
                    '基準日に日本国内に住所があることも条件です。最初の2年間は配偶者の所得を条件にせず、扶養する子の年齢基準は16歳未満です。',
          ),
          _heading('支援金の額（第10条）'),
          _body(
            _legal
                ? '支給は年度単位。原則額は前年所得と扶養児童の有無・人数に応じて政令で定める。'
                    '2027～2029年度には、税収見込額の考慮や本格導入に向けた額の調整など、年度別の特例を置く。'
                : '支援金は年度ごとに、前年の所得と扶養する子の有無・人数に応じて決める案です。'
                    '2027～2029年度には、本格導入に向けて額の決め方に特別なルールがあります。',
          ),
          widget.source('衆議院・提出時の法案本文', _bill),
          _heading('審議状況と未確定の点'),
          _body(
            '2026年11月6日に衆議院が可決し、同日に参議院が受理しました。'
            '11月9日に確認した審議経過では、参議院の議決と公布日は未確認です。'
            '提出時案は所得の基準額や個別の支給額を政令に委ねており、具体額はこの資料では確定できません。',
          ),
          widget.source('衆議院・この法案の審議経過', _progress),
          _heading('関連する委員会質疑'),
          _body(
            '10月23日の衆議院財務金融委員会で、この法案を議題としたことと、田中健議員'
            '（会議当時の会派は国民民主党・無所属クラブ）の発言枠を確認しました。'
            '個別の質問と答弁の対応は未確認です。',
          ),
          widget.source('衆議院審議中継・田中議員の発言開始位置', _hearing),
        ],
      ),
    );
  }
}
