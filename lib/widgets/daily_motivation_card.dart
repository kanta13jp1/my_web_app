import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/philosopher_quote.dart';

/// 毎日の名言カード。
/// generate-quote-image / share-quote Edge Function と連携し、
/// SNSへのシェアボタンを提供する。
class DailyMotivationCard extends StatefulWidget {
  const DailyMotivationCard({super.key});

  @override
  State<DailyMotivationCard> createState() => _DailyMotivationCardState();
}

class _DailyMotivationCardState extends State<DailyMotivationCard> {
  late int _quoteIndex;
  bool _sharing = false;

  static const _appBase = 'https://my-web-app-b67f4.web.app';

  @override
  void initState() {
    super.initState();
    // 今日の日付をシードにして毎日違う名言を表示
    final today = DateTime.now();
    final seed = today.year * 10000 + today.month * 100 + today.day;
    _quoteIndex = Random(seed).nextInt(PhilosopherQuote.quotes.length);
  }

  PhilosopherQuote get _quote => PhilosopherQuote.quotes[_quoteIndex];

  String get _shareUrl => '$_appBase/';

  Future<void> _shareOnX() async {
    final text = Uri.encodeComponent(
      '「${_quote.quote}」\n— ${_quote.author}\n\n#自分株式会社 #buildinpublic\n$_shareUrl',
    );
    final url = Uri.parse('https://twitter.com/intent/tweet?text=$text');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyShareLink() async {
    await Clipboard.setData(ClipboardData(text: _shareUrl));
    if (!mounted) return;
    setState(() => _sharing = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    if (mounted) setState(() => _sharing = false);
  }

  void _nextQuote() {
    setState(() {
      _quoteIndex = (_quoteIndex + 1) % PhilosopherQuote.quotes.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final quote = _quote;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
                : [const Color(0xFFF5F3FF), const Color(0xFFEDE9FE)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.format_quote,
                    color: Color(0xFF7C3AED),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '今日の名言',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7C3AED),
                        height: 1.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: _nextQuote,
                    tooltip: '次の名言',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: const Color(0xFF7C3AED),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '「${quote.quote}」',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.7,
                  color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '— ${quote.author}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7C3AED),
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  if (quote.authorDescription != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(${quote.authorDescription})',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFFBDBDBD)
                            : const Color(0xFF757575),
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _ActionChip(
                    label: 'X でシェア',
                    icon: Icons.share,
                    onTap: _shareOnX,
                  ),
                  const SizedBox(width: 8),
                  _ActionChip(
                    label: _sharing ? 'コピー完了!' : 'リンクコピー',
                    icon: _sharing ? Icons.check : Icons.link,
                    onTap: _copyShareLink,
                  ),
                  const Spacer(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF7C3AED).withAlpha(60),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: const Color(0xFF7C3AED)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7C3AED),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
