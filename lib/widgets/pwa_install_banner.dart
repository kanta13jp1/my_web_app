import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/pwa_install_prompt.dart';

class PwaInstallBanner extends StatefulWidget {
  final String storageKey;
  final Duration cooldown;
  final bool debugForceVisible;
  final DateTime Function()? nowProvider;

  const PwaInstallBanner({
    super.key,
    this.storageKey = 'pwa_install_banner_dismissed_at',
    this.cooldown = const Duration(days: 7),
    this.debugForceVisible = false,
    this.nowProvider,
  });

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
  bool _isLoading = true;
  bool _isDismissed = false;
  bool _canPromptInstall = false;
  bool _installHintShown = false;
  late final PwaInstallPromptController _installPromptController;

  DateTime _now() => widget.nowProvider?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _installPromptController = PwaInstallPromptController(
      onAvailabilityChanged: _handleInstallAvailabilityChanged,
    );
    _installPromptController.attach();
    _loadDismissedState();
  }

  @override
  void dispose() {
    _installPromptController.dispose();
    super.dispose();
  }

  void _handleInstallAvailabilityChanged(bool isAvailable) {
    if (!mounted) {
      return;
    }
    setState(() {
      _canPromptInstall = isAvailable;
    });
  }

  Future<void> _loadDismissedState() async {
    if (!kIsWeb && !widget.debugForceVisible) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _isDismissed = true;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final dismissedAtValue = prefs.getString(widget.storageKey);
    final dismissedAt =
        dismissedAtValue == null ? null : DateTime.tryParse(dismissedAtValue);
    final isDismissed =
        dismissedAt != null && _now().difference(dismissedAt) < widget.cooldown;

    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
      _isDismissed = isDismissed;
    });
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(widget.storageKey, _now().toIso8601String());

    if (!mounted) {
      return;
    }
    setState(() {
      _isDismissed = true;
    });
  }

  Future<void> _showInstallHint() async {
    final didPrompt = await _installPromptController.promptInstall();
    if (!mounted) {
      return;
    }
    setState(() {
      _installHintShown = true;
    });
    final message = didPrompt
        ? 'Install prompt opened.'
        : 'Use the browser install button to add this app.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isDismissed) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: const Key('pwa_install_banner'),
      color: colorScheme.primaryContainer.withValues(alpha: 0.72),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.install_mobile, color: colorScheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _installHintShown
                        ? 'Install prompt ready'
                        : _canPromptInstall
                            ? 'Install this app'
                            : 'Add to home screen',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Open the tracker from your home screen shortcut.',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.8,
                      ),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: const Key('pwa_install_banner_install'),
                        onPressed: _showInstallHint,
                        icon: const Icon(Icons.add_to_home_screen, size: 18),
                        label: Text(_canPromptInstall ? 'Install' : 'How'),
                      ),
                      TextButton.icon(
                        key: const Key('pwa_install_banner_dismiss'),
                        onPressed: _dismiss,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Later'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
