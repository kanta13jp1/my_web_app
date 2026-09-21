import 'package:supabase_flutter/supabase_flutter.dart';
import 'jev_client.dart';

/// Authenticated server-side Jev. No TypeSafe key is ever sent to the browser.
class JevExpenseProxyClient extends JevClient {
  final bool Function() signedIn;
  final Future<dynamic> Function(Map<String, dynamic>) invoke;

  JevExpenseProxyClient({required this.signedIn, required this.invoke});

  static JevClient forCurrentSession() {
    final direct = JevClient();
    if (direct.isLocalMode) {
      return direct;
    }
    direct.dispose();
    return JevExpenseProxyClient(
      signedIn: () {
        try {
          final user = Supabase.instance.client.auth.currentUser;
          return user != null && !user.isAnonymous;
        } catch (_) {
          return false;
        }
      },
      invoke: (body) async {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser?.id;
        if (userId == null) {
          return null;
        }
        final response = await client.functions.invoke(
          'ai-hub',
          body: body,
        );
        if (response.status != 200 || client.auth.currentUser?.id != userId) {
          return null;
        }
        return response.data;
      },
    );
  }

  @override
  bool get isConfigured => signedIn();

  @override
  Future<JevClassificationResult?> classify({
    required String input,
    required List<JevChoice> choices,
    String? context,
  }) async {
    if (!isConfigured || input.trim().isEmpty || input.length > 500) {
      return null;
    }
    final clock = Stopwatch()..start();
    try {
      final dynamic response = await invoke({
        'action': 'expense.jev_suggest',
        'memo': input.trim(),
        'consent': true,
      }).timeout(const Duration(seconds: 8));
      if (!isConfigured || response is! Map) {
        return null;
      }
      final dynamic answers = response['answers'];
      final dynamic answer = answers is Map ? answers['classification'] : null;
      if (answer is! Map || answer['type'] != 'choice') {
        return null;
      }
      final dynamic id = answer['choice'];
      final dynamic confidence = answer['confidence'];
      final dynamic probabilities = answer['probabilities'];
      final ids = choices.map((choice) => choice.id).toSet();
      if (!ids.contains(id) ||
          confidence is! num ||
          !confidence.isFinite ||
          confidence < 0 ||
          confidence > 1 ||
          probabilities is! Map ||
          probabilities.length != ids.length) {
        return null;
      }
      final scores = <String, double>{};
      for (final entry in probabilities.entries) {
        final dynamic value = entry.value;
        if (!ids.contains(entry.key) ||
            value is! num ||
            !value.isFinite ||
            value < 0 ||
            value > 1) {
          return null;
        }
        scores[entry.key as String] = value.toDouble();
      }
      if ((scores.values.fold<double>(0, (sum, n) => sum + n) - 1).abs() >
          0.01) {
        return null;
      }
      return JevClassificationResult(
        bestChoiceId: id as String,
        bestChoice: choices.firstWhere((choice) => choice.id == id),
        confidence: confidence.toDouble(),
        scores: scores,
        latencyMs: clock.elapsedMilliseconds,
      );
    } catch (_) {
      return null;
    }
  }
}
