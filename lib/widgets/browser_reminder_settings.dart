import 'package:flutter/material.dart';
import '../services/browser_reminder_controller.dart';

class BrowserReminderSettingsTile extends StatelessWidget {
  const BrowserReminderSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = BrowserReminderController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListTile(
        leading: const Icon(Icons.desktop_windows_outlined),
        title: const Text('「手は机へ」デスクトップ通知'),
        subtitle: Text(
          controller.running
              ? '実行中・約${controller.intervalMinutes}分おき'
              : '停止中・開始／テスト／間隔を設定',
        ),
        trailing: const Icon(Icons.settings_outlined),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: BrowserReminderSettings(controller: controller),
          ),
        ),
      ),
    );
  }
}

class BrowserReminderSettings extends StatefulWidget {
  const BrowserReminderSettings({super.key, required this.controller});
  final BrowserReminderController controller;

  @override
  State<BrowserReminderSettings> createState() =>
      _BrowserReminderSettingsState();
}

class _BrowserReminderSettingsState extends State<BrowserReminderSettings>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.refreshPermission();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.refreshPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // The session controller intentionally outlives this settings sheet.
    super.dispose();
  }

  String _permissionLabel(String permission) => switch (permission) {
        'granted' => '許可済み',
        'denied' => 'ブロック中',
        'default' => '未許可',
        _ => 'この環境は未対応',
      };

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('「手は机へ」', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('髪を触っていることに気づくための、やさしい合図です。'),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              controller.running
                  ? '実行中・約${controller.intervalMinutes}分おき'
                  : '停止中',
            ),
          ),
          Text('ブラウザの通知：${_permissionLabel(controller.permission)}'),
          const SizedBox(height: 12),
          const Text('通知間隔'),
          Wrap(
            spacing: 8,
            children: [
              for (final minutes in BrowserReminderController.intervals)
                ChoiceChip(
                  label: Text('$minutes分'),
                  selected: controller.intervalMinutes == minutes,
                  onSelected: controller.busy
                      ? null
                      : (_) => controller.setInterval(minutes),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: !controller.supported ||
                        controller.busy ||
                        controller.running
                    ? null
                    : controller.start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('開始'),
              ),
              OutlinedButton.icon(
                onPressed: controller.running || controller.busy
                    ? controller.stop
                    : null,
                icon: const Icon(Icons.stop),
                label: const Text('停止'),
              ),
              OutlinedButton(
                onPressed: !controller.supported || controller.busy
                    ? null
                    : controller.testNotification,
                child: const Text('テスト通知'),
              ),
            ],
          ),
          if (controller.busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const Text('通知の許可・送信を確認しています。'),
          ],
          if (controller.lastRequestedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              '最終表示応答：${controller.lastRequestedAt!.toLocal().toIso8601String().split('T').last.split('.').first}',
            ),
          ],
          if (controller.message != null) ...[
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(controller.message!)),
          ],
          const SizedBox(height: 16),
          const Text(
            'ページを開いている間だけ動作します。アプリ内で別の画面へ移動しても継続しますが、'
            'ページを閉じる・再読込すると停止します。複数タブで開始すると、それぞれから通知されます。'
            'バックグラウンドのタブ、省電力、スリープでは遅延・停止する場合があり、正確な5分間隔は保証されません。'
            '遅れた分をまとめて通知することはありません。',
          ),
          const SizedBox(height: 8),
          const Text(
            '別のアプリを見ていてもWindowsの通知として表示できます。'
            '表示位置・音・バナーはWindowsとブラウザの設定に従います。'
            '「開始」か「テスト通知」を押すと、必要に応じてブラウザの許可確認が開きます。',
          ),
        ],
      ),
    );
  }
}
