import 'package:flutter/material.dart';

/// Displays an honest parity matrix (shipped vs. in-progress) and direct link
/// to the no-login browser migration diagnostic on /vs-notion and /vs-evernote.
class MigrationParitySection extends StatelessWidget {
  const MigrationParitySection({
    super.key,
    required this.competitorKey,
    required this.competitorName,
    required this.accentColor,
  });

  static const Key sectionKey = Key('comparison-migration-parity-section');
  static const Key diagnosticButtonKey = Key(
    'comparison-migration-diagnostic-cta',
  );

  final String competitorKey;
  final String competitorName;
  final Color accentColor;

  List<String> get _shippedItems {
    final normalized = competitorKey.toLowerCase();
    final primaryImporter = normalized == 'evernote'
        ? 'Evernote ENEX 一括取込（ノート・履歴・添付・検索構文・無料診断）'
        : 'Notion Export ZIP 一括取込（ネスト ZIP・CSV 表変換・添付対応・ログイン不要の無料診断）';
    return <String>[
      primaryImporter,
      'Chrome / Edge Web Clipper（MV3 拡張機能・自分 API 連携）',
      '無料コア枠（テキストノート無制限・添付 100 MiB / 1 ファイル 10 MiB）',
      'ノート・タスク・家計管理・AI 整理の統合ワークスペース',
    ];
  }

  static const List<String> _inProgressItems = <String>[
    'インライン / ブロックエディタ刷新・無制限入れ子ページ・バックリンク（Wave 2）',
    '1 データベースでの Table / Kanban / Calendar / Gallery 切替・新規 PDF/画像自動 OCR・メール転送ノート化（Wave 3）',
    'ENEX / Markdown ZIP 一括エクスポート・オフライン閲覧キャッシュ・リアルタイム共同編集（Wave 4）',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: sectionKey,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF141827),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '自分株式会社の現在の対応状況（実装済み / 開発中）',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF5F7FB),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$competitorName からの乗り換え前に、無料プラン仕様（テキストノート無制限・添付ストレージ 100 MiB／1 ファイル最大 10 MiB）と、ログイン不要・ブラウザ完結の無料移行診断（ノート数・添付容量・年間節約目安）を確認できます。',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFD6DCE9),
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final shippedCard = _buildParityCard(
                      title: '実装済み（今すぐ利用可能）',
                      badgeColor: const Color(0xFF10B981),
                      items: _shippedItems,
                      isShipped: true,
                    );
                    final roadmapCard = _buildParityCard(
                      title: '開発中（順次公開予定）',
                      badgeColor: const Color(0xFFF59E0B),
                      items: _inProgressItems,
                      isShipped: false,
                    );
                    if (constraints.maxWidth < 760) {
                      return Column(
                        children: <Widget>[
                          shippedCard,
                          const SizedBox(height: 12),
                          roadmapCard,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: shippedCard),
                        const SizedBox(width: 12),
                        Expanded(child: roadmapCard),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: diagnosticButtonKey,
                  onPressed: () => Navigator.of(context).pushNamed('/import'),
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text(
                    'ログイン不要で無料移行診断を試す',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3D5AFE),
                    foregroundColor: const Color(0xFFF5F7FB),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParityCard({
    required String title,
    required Color badgeColor,
    required List<String> items,
    required bool isShipped,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2135),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                isShipped ? Icons.check_circle_rounded : Icons.schedule_rounded,
                size: 18,
                color: badgeColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF5F7FB),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final String item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    isShipped ? '✓' : '・',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFD6DCE9),
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
