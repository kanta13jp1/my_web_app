import 'package:flutter/material.dart';

/// Reloads calendar records without navigating or resetting the parent form.
class AssetCalendarRefreshControl extends StatefulWidget {
  const AssetCalendarRefreshControl({super.key, required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  State<AssetCalendarRefreshControl> createState() =>
      _AssetCalendarRefreshControlState();
}

class _AssetCalendarRefreshControlState
    extends State<AssetCalendarRefreshControl> {
  bool _loading = false;
  String? _message;
  bool _failed = false;

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await widget.onRefresh();
      if (!mounted) return;
      setState(() {
        _failed = false;
        _message = '記録を更新しました。表示中の日付・入力内容は保持しています。';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _message = '記録を更新できませんでした。表示は前回のままです。再試行してください。';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            key: const Key('asset_calendar_refresh'),
            onPressed: _loading ? null : _refresh,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(
              _loading
                ? '記録を更新中…'
                : _failed
                    ? '記録の更新を再試行'
                    : 'カレンダーの記録を更新',
            ),
          ),
          if (_message != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _message!,
                style: TextStyle(
                  color: _failed ? Theme.of(context).colorScheme.error : null,
                ),
              ),
            ),
        ],
      );
}
