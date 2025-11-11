import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/timer_service.dart';

/// フローティングタイマーウィジェット
/// 画面の右下に表示されるドラッグ可能なタイマー
class FloatingTimerWidget extends StatefulWidget {
  const FloatingTimerWidget({super.key});

  @override
  State<FloatingTimerWidget> createState() => _FloatingTimerWidgetState();
}

class _FloatingTimerWidgetState extends State<FloatingTimerWidget> {
  bool _isExpanded = false;
  Offset _position = const Offset(20, 100);

  @override
  Widget build(BuildContext context) {
    final timerService = Provider.of<TimerService>(context);

    if (!timerService.hasActiveTimer) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isExpanded
                ? _buildExpandedTimer(context, timerService)
                : _buildMinimizedTimer(context, timerService),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimizedTimer(BuildContext context, TimerService timerService) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.timer,
          size: 20,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          timerService.formatRemainingTime(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(
            timerService.isRunning ? Icons.pause : Icons.play_arrow,
            size: 20,
          ),
          onPressed: () {
            if (timerService.isRunning) {
              timerService.pauseTimer();
            } else {
              timerService.resumeTimer();
            }
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        IconButton(
          icon: const Icon(Icons.expand_more, size: 20),
          onPressed: () {
            setState(() {
              _isExpanded = true;
            });
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildExpandedTimer(BuildContext context, TimerService timerService) {
    final colorScheme = Theme.of(context).colorScheme;
    final timer = timerService.activeTimer!;

    return SizedBox(
      width: 250,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ヘッダー
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  timer.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.expand_less, size: 20),
                onPressed: () {
                  setState(() {
                    _isExpanded = false;
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // タイマー表示
          Center(
            child: Text(
              timerService.formatRemainingTime(),
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // プログレスバー
          LinearProgressIndicator(
            value: 1.0 - timerService.progress,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
          const SizedBox(height: 4),

          // 進捗テキスト
          Text(
            '${((1.0 - timerService.progress) * 100).toInt()}% (残り${timerService.remainingSeconds ~/ 60}分)',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // コントロールボタン
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 一時停止/再開ボタン
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (timerService.isRunning) {
                      timerService.pauseTimer();
                    } else {
                      timerService.resumeTimer();
                    }
                  },
                  icon: Icon(
                    timerService.isRunning ? Icons.pause : Icons.play_arrow,
                    size: 18,
                  ),
                  label: Text(
                    timerService.isRunning ? '一時停止' : '再開',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 停止ボタン
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    timerService.stopTimer();
                  },
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text(
                    '停止',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // リセットボタン
          TextButton.icon(
            onPressed: () {
              timerService.resetTimer();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text(
              'リセット',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
