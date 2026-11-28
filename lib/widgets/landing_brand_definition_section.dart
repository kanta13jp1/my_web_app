import 'package:flutter/material.dart';

/// ランディングページ内の「自分株式会社とは」ブランド定義セクション。
class LandingBrandDefinitionSection extends StatelessWidget {
  const LandingBrandDefinitionSection({
    super.key,
    this.onPhilosophyTap,
  });

  final VoidCallback? onPhilosophyTap;

  static const List<String> _principles = <String>[
    '自分が人生のCEOとして決める',
    '時間・お金・スキルを資産として育てる',
    '他人ではなく昨日の自分をKPIにする',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('landing_brand_definition'),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE7F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            key: const Key('landing_brand_definition_heading'),
            header: true,
            child: const Text(
              '自分株式会社とは',
              style: TextStyle(
                color: Color(0xFF172033),
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '自分株式会社は、自分自身を一つの会社に見立て、人生のCEOとして仕事・学習・お金・健康を経営する考え方をAIで実践できるライフマネジメントアプリです。AIが状況を整理し、今日やる1件まで具体化します。',
            style: TextStyle(
              color: Color(0xFF475569),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final principle in _principles)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF5FB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    principle,
                    style: const TextStyle(
                      color: Color(0xFF26364A),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('landing_brand_philosophy_link'),
            onPressed: onPhilosophyTap ??
                () => Navigator.of(context).pushNamed('/philosophy'),
            icon: const Icon(Icons.arrow_forward, size: 17),
            label: const Text('9つの基本理念を見る'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1F7AE0),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
