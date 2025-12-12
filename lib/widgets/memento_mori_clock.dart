import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MementoMoriClock extends StatefulWidget {
  final String? birthDateString;
  final int targetAge;
  final double maintenanceRatio;

  const MementoMoriClock({
    super.key,
    required this.birthDateString,
    this.targetAge = 80,
    this.maintenanceRatio = 0.5,
  });

  @override
  State<MementoMoriClock> createState() => _MementoMoriClockState();
}

class _MementoMoriClockState extends State<MementoMoriClock> {
  Timer? _timer;
  int? _remainingSeconds;
  String _wasteImpact = "0.0000";

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MementoMoriClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.birthDateString != oldWidget.birthDateString) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.birthDateString == null) return;

    final birthDate = DateTime.tryParse(widget.birthDateString!);
    if (birthDate == null) return;

    // 死亡予定日 = 誕生日 + 目標寿命
    // 簡易的な計算として、誕生日の年にtargetAgeを足す
    final deathDate = DateTime(
      birthDate.year + widget.targetAge,
      birthDate.month,
      birthDate.day,
    );

    _tick(deathDate);
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => _tick(deathDate));
  }

  void _tick(DateTime deathDate) {
    final now = DateTime.now();
    final totalSecondsLeft = deathDate.difference(now).inSeconds;

    // 可処分時間（睡眠などを引いた時間）
    final realSeconds = (totalSecondsLeft * widget.maintenanceRatio).floor();
    final safeRealSeconds = realSeconds > 0 ? realSeconds : 0;

    // 「1時間(3600秒)を無駄にした時のダメージ率」
    double impact = 0;
    if (safeRealSeconds > 0) {
      impact = (3600 / safeRealSeconds) * 100;
    }

    if (mounted) {
      setState(() {
        _remainingSeconds = safeRealSeconds;
        _wasteImpact = impact.toStringAsFixed(5);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.birthDateString == null) {
      return _buildUnsetContainer();
    }

    final formatter = NumberFormat("#,###");
    final hours = _remainingSeconds != null ? _remainingSeconds! ~/ 3600 : 0;
    final minutes =
        _remainingSeconds != null ? (_remainingSeconds! % 3600) ~/ 60 : 0;
    final seconds = _remainingSeconds != null ? _remainingSeconds! % 60 : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A), // ほぼ黒
        border: Border.all(color: Colors.red.shade900, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(
                alpha:
                    0.2), // alpha is deprecated inside withValues? No, withOpacity is. using withValues for Flutter 3.27+ or withOpacity for older. Assuming standard.
            // color: Colors.red.withOpacity(0.2), // Use this if older Flutter
            blurRadius: 15,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withOpacity(0.3),
              border: Border(bottom: BorderSide(color: Colors.red.shade900)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "MEMENTO MORI PROTOCOL",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  "TARGET: ${widget.targetAge}",
                  style: TextStyle(
                    color: Colors.red.shade200,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // Clock Body
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  "夢を叶えるための正味の残り時間",
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 8),
                if (_remainingSeconds == null)
                  const Text("CALCULATING...",
                      style: TextStyle(color: Colors.white))
                else
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        _buildTimeUnit(
                            formatter.format(hours), "hours", Colors.red),
                        _buildSeparator(),
                        _buildTimeUnit(minutes.toString().padLeft(2, '0'),
                            "min", Colors.white),
                        _buildSeparator(),
                        _buildTimeUnit(seconds.toString().padLeft(2, '0'),
                            "sec", Colors.white,
                            isPulse: true),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Impact Alert
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.2),
                    border:
                        Border.all(color: Colors.red.shade900.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 11, color: Colors.redAccent),
                      children: [
                        const TextSpan(text: "警告: 今1時間を無駄にすると、残りの人生の "),
                        TextSpan(
                          text: "$_wasteImpact%",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const TextSpan(text: " が永久に失われます。"),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                const Text(
                  "\"今日という日は、残りの人生で最初の日であり、最も若い日である\"",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 9,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnsetContainer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: const Column(
        children: [
          Icon(Icons.hourglass_disabled, color: Colors.grey),
          SizedBox(height: 8),
          Text(
            "死のリミット計測不能",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Text(
            "プロフィール画面で「生年月日」を設定し、\n現実を直視してください。",
            style: TextStyle(color: Colors.grey, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(String value, String unit, Color color,
      {bool isPulse = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 2),
        Text(
          unit,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSeparator() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ":",
        style: TextStyle(color: Colors.grey, fontSize: 24),
      ),
    );
  }
}
