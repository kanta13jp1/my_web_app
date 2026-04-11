import 'package:flutter/material.dart';

/// リアルタイム思考妨害介入ウィジェット
/// ホーム画面の禁欲ガードパネル内で「今この瞬間の衝動」をワンタップで排除する
class ThoughtInterruptQuickWidget extends StatelessWidget {
  const ThoughtInterruptQuickWidget({super.key});

  static final List<_ImpulseItem> _items = [
    _ImpulseItem(
      'sns', 'SNS', Icons.thumb_up, const Color(0xFF1D9BF0),
      '通知をOFFにしてスマホを裏返す', '水を1杯飲んで3回深呼吸',
    ),
    _ImpulseItem(
      'games', 'ゲーム', Icons.videogame_asset, const Color(0xFF7C3AED),
      'アプリを閉じて画面ロック', '5分間ストレッチ',
    ),
    _ImpulseItem(
      'video', '動画', Icons.play_circle, const Color(0xFFEF4444),
      'タブを閉じてブラウザを終了', '読みたい本を1ページ開く',
    ),
    _ImpulseItem(
      'smoking', 'タバコ', Icons.smoking_rooms, const Color(0xFF92400E),
      '禁煙アイテム(ガム・水)を手に取る', 'エレベーターで階段に変更',
    ),
    _ImpulseItem(
      'alcohol', 'お酒', Icons.local_bar, const Color(0xFFF59E0B),
      '冷水・炭酸水を代替として用意', '翌朝のコストを計算する',
    ),
    _ImpulseItem(
      'impulse', '衝動', Icons.block, const Color(0xFFDB2777),
      '目を閉じて10秒カウント', '目標ノートを1行書く',
    ),
  ];

  void _showInterventionSheet(BuildContext context, _ImpulseItem item) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _InterventionSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF4338CA).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF4338CA).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_alt, size: 16, color: Color(0xFF4338CA)),
              const SizedBox(width: 6),
              const Text(
                '今の衝動を即排除',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4338CA),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  '/thought-interrupt-diagnosis',
                ),
                child: const Text(
                  '診断 →',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4338CA),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _items.map((item) {
              return GestureDetector(
                onTap: () => _showInterventionSheet(context, item),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: item.color.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon, size: 14, color: item.color),
                      const SizedBox(width: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: item.color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ImpulseItem {
  _ImpulseItem(
    this.id,
    this.label,
    this.icon,
    this.color,
    this.eliminationAction,
    this.replacementAction,
  );
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String eliminationAction;
  final String replacementAction;
}

class _InterventionSheet extends StatelessWidget {
  const _InterventionSheet({required this.item});
  final _ImpulseItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                '${item.label}の衝動を今すぐ排除',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ActionTile(
            icon: Icons.block,
            color: Colors.redAccent,
            title: '排除アクション',
            body: item.eliminationAction,
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.swap_horiz,
            color: Colors.green,
            title: '代替行動',
            body: item.replacementAction,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('排除した'),
              style: FilledButton.styleFrom(
                backgroundColor: item.color,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(fontSize: 14, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
