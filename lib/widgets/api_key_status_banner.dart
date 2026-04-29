import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Windows版#94: AI プロバイダー API キーの設定状況バナー
///
/// ai-assistant EF の `get_provider_status` action を叩き、未設定キーが
/// ある場合に画面トップに「対応が必要」バナーを表示する。
///
/// 例: OPENAI_API_KEY 未設定 → 「Claude quota 到達時に fallback できない」旨を告知。
class ApiKeyStatusBanner extends StatefulWidget {
  const ApiKeyStatusBanner({super.key});

  @override
  State<ApiKeyStatusBanner> createState() => _ApiKeyStatusBannerState();
}

class _ApiKeyStatusBannerState extends State<ApiKeyStatusBanner> {
  List<String> _configured = [];
  List<String> _missing = [];
  Map<String, dynamic> _details = {};
  bool _loading = true;
  bool _dismissed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'ai-assistant',
        body: {'action': 'get_provider_status'},
      );
      final data = res.data;
      if (!mounted) return;
      if (data is Map<String, dynamic>) {
        setState(() {
          _configured = List<String>.from(data['configured'] ?? const []);
          _missing = List<String>.from(data['missing'] ?? const []);
          _details = Map<String, dynamic>.from(data['details'] ?? const {});
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _envFor(String provider) {
    final detail = _details[provider];
    if (detail is Map && detail['env'] is String) {
      return detail['env'] as String;
    }
    return '${provider.toUpperCase()}_API_KEY';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _dismissed) return const SizedBox.shrink();
    if (_missing.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // 全て未設定 = critical / 一部未設定 = warning
    final isCritical = _configured.isEmpty;
    final bgColor = isCritical
        ? const Color(0xFFDC2626).withValues(alpha: isDark ? 0.25 : 0.10)
        : const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.22 : 0.10);
    final borderColor =
        isCritical ? const Color(0xFFDC2626) : const Color(0xFFF59E0B);
    final icon = isCritical ? Icons.error_outline : Icons.warning_amber_rounded;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: borderColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isCritical
                      ? 'AI プロバイダーの API キーが全て未設定です'
                      : 'AI プロバイダーの API キーが一部未設定です (fallback 制限あり)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                    height: 1.5,
                  ),
                ),
              ),
              IconButton(
                tooltip: '閉じる',
                icon: const Icon(Icons.close, size: 18),
                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                onPressed: () => setState(() => _dismissed = true),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_configured.isNotEmpty)
                  Text(
                    '設定済み: ${_configured.join(", ")}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white70 : const Color(0xFF374151),
                      height: 1.5,
                    ),
                  ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _missing.map((p) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: borderColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: borderColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '${_envFor(p)} 未設定',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color:
                              isDark ? Colors.white : const Color(0xFF111827),
                          height: 1.5,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),
                Text(
                  isCritical
                      ? '管理者 → Supabase Dashboard → Settings → Edge Functions → Secrets で API キーを登録してください。'
                      : '他プロバイダーが quota 到達時に上記の未設定キーへフォールバックできません。管理者に設定を依頼してください。',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                    height: 1.4,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'status fetch error: $_error',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF991B1B),
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
