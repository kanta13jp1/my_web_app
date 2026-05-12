import 'package:flutter/material.dart';

/// リアルタイム思考妨害介入ウィジェット
/// ホーム画面の禁欲ガードパネル内で「今この瞬間の衝動」をワンタップで排除する
class ThoughtInterruptQuickWidget extends StatelessWidget {
  const ThoughtInterruptQuickWidget({super.key});

  static final List<_ImpulseItem> _items = [
    _ImpulseItem(
      'sns',
      'SNS',
      Icons.thumb_up,
      const Color(0xFF1D9BF0),
      '通知をOFFにしてスマホを裏返す',
      '水を1杯飲んで3回深呼吸',
    ),
    _ImpulseItem(
      'games',
      'ゲーム',
      Icons.videogame_asset,
      const Color(0xFF7C3AED),
      'アプリを閉じて画面ロック',
      '5分間ストレッチ',
    ),
    _ImpulseItem(
      'video',
      '動画',
      Icons.play_circle,
      const Color(0xFFEF4444),
      'タブを閉じてブラウザを終了',
      '読みたい本を1ページ開く',
    ),
    _ImpulseItem(
      'smoking',
      'タバコ',
      Icons.smoking_rooms,
      const Color(0xFF92400E),
      '禁煙アイテム(ガム・水)を手に取る',
      'エレベーターで階段に変更',
    ),
    _ImpulseItem(
      'alcohol',
      'お酒',
      Icons.local_bar,
      const Color(0xFFF59E0B),
      '冷水・炭酸水を代替として用意',
      '翌朝のコストを計算する',
    ),
    _ImpulseItem(
      'impulse',
      '衝動',
      Icons.block,
      const Color(0xFFDB2777),
      '目を閉じて10秒カウント',
      '目標ノートを1行書く',
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

  void _showTotSupportSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _TotSupportSheet(),
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
              const Icon(
                Icons.psychology_alt,
                size: 16,
                color: Color(0xFF4338CA),
              ),
              const SizedBox(width: 6),
              const Text(
                '今の衝動を即排除',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4338CA),
                  fontSize: 13,
                  height: 1.5,
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
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('thought_interrupt_tot_support_button'),
              onPressed: () => _showTotSupportSheet(context),
              icon: const Icon(Icons.psychology_alt_outlined, size: 18),
              label: const Text('行き詰まり・思考サポート'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
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
                          height: 1.5,
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

class _TotSupportState {
  const _TotSupportState({
    required this.id,
    required this.label,
    required this.icon,
    required this.primaryAction,
    required this.refreshMethod,
    required this.organizeTool,
  });

  final String id;
  final String label;
  final IconData icon;
  final String primaryAction;
  final String refreshMethod;
  final String organizeTool;
}

const List<_TotSupportState> _totSupportStates = [
  _TotSupportState(
    id: 'words',
    label: '言葉が出ない',
    icon: Icons.chat_bubble_outline,
    primaryAction: '目線を上げて、言いたい単語を3つだけ箇条書きにする。',
    refreshMethod: '利き手ではない手で頭をゆっくり撫で、肩を2回回す。',
    organizeTool: 'メモに「対象 / 感情 / 次の一文」を1行ずつ書く。',
  ),
  _TotSupportState(
    id: 'focus',
    label: '集中できない',
    icon: Icons.center_focus_strong,
    primaryAction: '椅子に深く座り直し、足裏を床につけて視界の物を1つ減らす。',
    refreshMethod: '30秒の腹式呼吸を行い、終わったら次の1手だけ決める。',
    organizeTool: '今やる作業を「2分で終わる粒度」に分解する。',
  ),
  _TotSupportState(
    id: 'stress',
    label: '緊張が強い',
    icon: Icons.self_improvement,
    primaryAction: '顎と肩の力を抜き、手を机の上に置いて接触行動を止める。',
    refreshMethod: '温かい飲み物か水を取り、息を長く吐く呼吸を3回行う。',
    organizeTool: '不安を書き出し、制御できることだけ丸で囲む。',
  ),
];

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

class _TotSupportSheet extends StatefulWidget {
  const _TotSupportSheet();

  @override
  State<_TotSupportSheet> createState() => _TotSupportSheetState();
}

class _TotSupportSheetState extends State<_TotSupportSheet> {
  _TotSupportState _selectedState = _totSupportStates.first;
  double _stressLevel = 3;

  @override
  Widget build(BuildContext context) {
    final color =
        _stressLevel >= 4 ? const Color(0xFFE53935) : const Color(0xFF0F766E);
    final stressLabel = _stressLevel.round();

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          key: const Key('thought_interrupt_tot_support_sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _selectedState.icon,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '行き詰まり・思考サポート',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              '今の状態',
              style: TextStyle(fontWeight: FontWeight.w800, height: 1.5),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _totSupportStates.map((state) {
                return ChoiceChip(
                  key: Key('thought_interrupt_tot_state_${state.id}'),
                  label: Text(state.label),
                  selected: state.id == _selectedState.id,
                  onSelected: (_) {
                    setState(() => _selectedState = state);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'ストレスレベル $stressLabel / 5',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
            Slider(
              key: const Key('thought_interrupt_tot_stress_slider'),
              value: _stressLevel,
              min: 1,
              max: 5,
              divisions: 4,
              label: '$stressLabel',
              activeColor: color,
              onChanged: (value) => setState(() => _stressLevel = value),
            ),
            _ActionTile(
              icon: Icons.accessibility_new,
              color: color,
              title: '姿勢リセット',
              body: _selectedState.primaryAction,
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.spa_outlined,
              color: const Color(0xFF4CAF50),
              title: 'リフレッシュ手法',
              body: _selectedState.refreshMethod,
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.edit_note,
              color: const Color(0xFF3D5AFE),
              title: '思考整理ツール',
              body: _stressLevel >= 4
                  ? '${_selectedState.organizeTool} まず60秒で止め、続きは次の休憩後に回す。'
                  : _selectedState.organizeTool,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('作業に戻る'),
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                color: const Color(0xFFE0E0E0),
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
                  height: 1.5,
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
                    height: 1.5,
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
