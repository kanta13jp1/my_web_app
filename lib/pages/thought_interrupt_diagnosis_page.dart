import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 思考妨害パターン診断ページ
/// 4つの質問で最大の思考妨害要因を特定し、禁欲ガードの対象を自動設定する
class ThoughtInterruptDiagnosisPage extends StatefulWidget {
  const ThoughtInterruptDiagnosisPage({super.key});

  @override
  State<ThoughtInterruptDiagnosisPage> createState() =>
      _ThoughtInterruptDiagnosisPageState();
}

class _ThoughtInterruptDiagnosisPageState
    extends State<ThoughtInterruptDiagnosisPage> {
  final _supabase = Supabase.instance.client;

  int _currentStep = 0;
  final List<String?> _answers = [null, null, null, null];
  bool _isSaving = false;
  bool _isDone = false;
  Map<String, dynamic>? _result;

  static final List<_DiagQuestion> _questions = [
    _DiagQuestion(
      question: 'Q1: 集中が途切れた時、最初に何をしますか？',
      icon: Icons.psychology_alt,
      options: [
        _DiagOption(
          'sns',
          'SNS をチェック',
          Icons.thumb_up,
          const Color(0xFF3D5AFE),
        ),
        _DiagOption(
          'mobile_games',
          'ゲームを開く',
          Icons.videogame_asset,
          const Color(0xFF7C3AED),
        ),
        _DiagOption(
          'video',
          '動画を見る',
          Icons.play_circle,
          const Color(0xFFE53935),
        ),
        _DiagOption('manga', '漫画を読む', Icons.menu_book, const Color(0xFF0891B2)),
        _DiagOption(
          'smartphone',
          'スマホを手に取る',
          Icons.smartphone,
          const Color(0xFF9CA3AF),
        ),
        _DiagOption(
          'eating_out',
          '食べ物を探す',
          Icons.fastfood,
          const Color(0xFFFF6B35),
        ),
      ],
    ),
    _DiagQuestion(
      question: 'Q2: 作業中に衝動が来た時、何をしたくなりますか？',
      icon: Icons.local_fire_department,
      options: [
        _DiagOption(
          'smoking',
          'タバコを吸う',
          Icons.smoking_rooms,
          const Color(0xFF795548),
        ),
        _DiagOption(
          'alcohol',
          'お酒を飲む',
          Icons.local_bar,
          const Color(0xFFF59E0B),
        ),
        _DiagOption(
          'masturbation',
          '性的な衝動に従う',
          Icons.block,
          const Color(0xFFFF6B35),
        ),
        _DiagOption(
          'dating_apps',
          '出会い系・異性探索',
          Icons.favorite,
          const Color(0xFFE11D48),
        ),
        _DiagOption(
          'gambling',
          'ギャンブル・賭け事',
          Icons.casino,
          const Color(0xFF059669),
        ),
        _DiagOption(
          'eating_out',
          '間食・外食',
          Icons.restaurant,
          const Color(0xFFFF6B35),
        ),
      ],
    ),
    _DiagQuestion(
      question: 'Q3: 1日のうち、最も集中が途切れやすい時間帯は？',
      icon: Icons.access_time,
      options: [
        _DiagOption(
          'morning',
          '朝 (6〜9時)',
          Icons.wb_sunny,
          const Color(0xFFFFC107),
        ),
        _DiagOption(
          'midday',
          '昼食後 (12〜14時)',
          Icons.lunch_dining,
          const Color(0xFFF97316),
        ),
        _DiagOption(
          'afternoon',
          '午後 (14〜17時)',
          Icons.cloud,
          const Color(0xFF3D5AFE),
        ),
        _DiagOption(
          'evening',
          '夕方 (17〜20時)',
          Icons.wb_twilight,
          const Color(0xFFFF6B35),
        ),
        _DiagOption(
          'night',
          '夜 (20〜23時)',
          Icons.nights_stay,
          const Color(0xFF3D5AFE),
        ),
        _DiagOption(
          'midnight',
          '深夜 (23時〜)',
          Icons.bedtime,
          const Color(0xFF1E293B),
        ),
      ],
    ),
    _DiagQuestion(
      question: 'Q4: 集中が途切れる前に気づく「サイン」はありますか？',
      icon: Icons.warning_amber,
      options: [
        _DiagOption(
          'hand',
          '手が無意識に動く',
          Icons.front_hand,
          const Color(0xFF009688),
        ),
        _DiagOption(
          'eyes',
          '目が泳ぐ・視線が定まらない',
          Icons.visibility,
          const Color(0xFF0891B2),
        ),
        _DiagOption(
          'posture',
          '姿勢が崩れる',
          Icons.airline_seat_recline_normal,
          const Color(0xFF795548),
        ),
        _DiagOption(
          'yawn',
          'あくびが出る・眠くなる',
          Icons.bedtime_outlined,
          const Color(0xFF3D5AFE),
        ),
        _DiagOption(
          'restless',
          'そわそわ・落ち着かない',
          Icons.directions_run,
          const Color(0xFFFF6B35),
        ),
        _DiagOption(
          'none',
          'サインを感じない',
          Icons.help_outline,
          const Color(0xFF9CA3AF),
        ),
      ],
    ),
  ];

  void _selectOption(String value) {
    setState(() {
      _answers[_currentStep] = value;
    });
  }

  void _nextStep() {
    if (_currentStep < _questions.length - 1) {
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _submit() async {
    if (_supabase.auth.currentUser == null) return;
    setState(() => _isSaving = true);
    try {
      final res = await _supabase.functions.invoke(
        'ai-hub',
        body: {'action': 'judgment.get'},
      );
      final data = res.data;
      setState(() {
        _isDone = true;
        _result = data is Map<String, dynamic> ? data : null;
      });
    } catch (_) {
      // EF未対応の場合もローカルで結果を表示
      setState(() {
        _isDone = true;
        _result = _buildLocalResult();
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Map<String, dynamic> _buildLocalResult() {
    // 主な妨害要因をローカルで判定
    final focusBreak = _answers[0] ?? 'sns';
    final impulse = _answers[1] ?? 'smoking';
    final peakTime = _answers[2] ?? 'night';
    final sign = _answers[3] ?? 'none';

    final Map<String, String> timeLabel = {
      'morning': '朝',
      'midday': '昼食後',
      'afternoon': '午後',
      'evening': '夕方',
      'night': '夜',
      'midnight': '深夜',
    };
    final Map<String, String> itemLabel = {
      'sns': 'SNS',
      'mobile_games': 'スマホゲーム',
      'video': '動画',
      'manga': '漫画',
      'smartphone': 'スマホ',
      'eating_out': '間食・外食',
      'smoking': 'タバコ',
      'alcohol': 'お酒',
      'masturbation': '性的衝動',
      'dating_apps': '出会い系',
      'gambling': 'ギャンブル',
    };

    return {
      'top_disruptors': [focusBreak, impulse],
      'peak_time': timeLabel[peakTime] ?? peakTime,
      'warning_sign': sign,
      'advice':
          '${timeLabel[peakTime] ?? peakTime}に${itemLabel[focusBreak] ?? focusBreak}の誘惑が強まる傾向があります。'
              'この時間帯はスマホを別室に置くか、代替行動（深呼吸・散歩・水を飲む）を設定しましょう。',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('思考妨害パターン診断'),
        leading: _currentStep > 0 && !_isDone
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _prevStep,
              )
            : null,
      ),
      body: _isDone ? _buildResult() : _buildQuestion(),
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_currentStep];
    final selected = _answers[_currentStep];
    return Column(
      children: [
        // プログレスバー
        LinearProgressIndicator(
          value: (_currentStep + 1) / _questions.length,
          backgroundColor: const Color(0xFFEEEEEE),
          color: const Color(0xFF3D5AFE),
          minHeight: 4,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(q.icon, color: const Color(0xFF3D5AFE), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '${_currentStep + 1} / ${_questions.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black45,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                q.question,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              ...q.options.map(
                (opt) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OptionCard(
                    option: opt,
                    isSelected: selected == opt.value,
                    onTap: () => _selectOption(opt.value),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      selected == null ? null : (_isSaving ? null : _nextStep),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D5AFE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    disabledBackgroundColor: const Color(0xFFE0E0E0),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _currentStep < _questions.length - 1
                              ? '次へ →'
                              : '診断結果を見る',
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disruptors = _result?['top_disruptors'] as List? ?? [];
    final peakTime = _result?['peak_time']?.toString() ?? '';
    final advice = _result?['advice']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Center(
          child: Icon(Icons.shield, size: 56, color: Color(0xFF3D5AFE)),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            '診断完了',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3D5AFE),
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (disruptors.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.report_problem,
                        color: Color(0xFFFF6B35),
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'あなたの主な思考妨害',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: disruptors.map((d) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2A1500)
                              : const Color(0xFFFFE0B2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          d.toString(),
                          style: const TextStyle(
                            color: Color(0xFFEF6C00),
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (peakTime.isNotEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.access_time, color: Color(0xFF3D5AFE)),
              title: const Text('集中が途切れやすい時間帯'),
              subtitle: Text(peakTime),
            ),
          ),
        const SizedBox(height: 12),
        if (advice.isNotEmpty)
          Card(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1A1A2E)
                : const Color(0xFFE8EAF6),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.psychology,
                        color: Color(0xFF303F9F),
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'アドバイス',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF303F9F),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    advice,
                    style: const TextStyle(fontSize: 14, height: 1.7),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => Navigator.pushReplacementNamed(
            context,
            '/abstinence-guard',
          ),
          icon: const Icon(Icons.shield, size: 18),
          label: const Text('禁欲ガードで防衛を開始'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3D5AFE),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () {
            setState(() {
              _currentStep = 0;
              _answers.fillRange(0, 4, null);
              _isDone = false;
              _result = null;
            });
          },
          child: const Text('もう一度診断する'),
        ),
      ],
    );
  }
}

class _DiagQuestion {
  _DiagQuestion({
    required this.question,
    required this.icon,
    required this.options,
  });
  final String question;
  final IconData icon;
  final List<_DiagOption> options;
}

class _DiagOption {
  _DiagOption(this.value, this.label, this.icon, this.color);
  final String value;
  final String label;
  final IconData icon;
  final Color color;
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });
  final _DiagOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:
              isSelected ? option.color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? option.color : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: option.color.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              option.icon,
              color: isSelected ? option.color : const Color(0xFF9CA3AF),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? option.color : Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: option.color, size: 20),
          ],
        ),
      ),
    );
  }
}
