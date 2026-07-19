import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

enum ActivationRevenueVariant { control, treatment }

class ActivationRevenueHypothesis {
  const ActivationRevenueHypothesis({
    required this.id,
    required this.title,
    required this.primaryMetric,
  });

  final String id;
  final String title;
  final String primaryMetric;
}

class ActivationRevenueAssignment {
  const ActivationRevenueAssignment({
    required this.hypothesis,
    required this.variant,
  });

  final ActivationRevenueHypothesis hypothesis;
  final ActivationRevenueVariant variant;

  bool enables(String hypothesisId) {
    return hypothesis.id != hypothesisId ||
        variant == ActivationRevenueVariant.treatment;
  }

  String eventKey(String stage) {
    if (!ActivationRevenueExperimentService.supportedStages.contains(stage)) {
      throw ArgumentError.value(
        stage,
        'stage',
        'Unsupported activation revenue event stage',
      );
    }
    return 'activation_exp_${hypothesis.id}_${variant.name}_$stage';
  }

  @override
  bool operator ==(Object other) {
    return other is ActivationRevenueAssignment &&
        other.hypothesis.id == hypothesis.id &&
        other.variant == variant;
  }

  @override
  int get hashCode => Object.hash(hypothesis.id, variant);
}

class ActivationRevenueExperimentService {
  const ActivationRevenueExperimentService();

  static const String _hypothesisPreferenceKey =
      'activation_revenue_hypothesis_v1';
  static const String _variantPreferenceKey = 'activation_revenue_variant_v1';

  static const List<ActivationRevenueHypothesis> hypotheses = [
    ActivationRevenueHypothesis(
      id: 'a01',
      title: '60秒で得られる成果を最初に伝える',
      primaryMetric: 'onboarding completion rate',
    ),
    ActivationRevenueHypothesis(
      id: 'a02',
      title: '仕事・学習・お金から目的を選ぶ',
      primaryMetric: 'first action start rate',
    ),
    ActivationRevenueHypothesis(
      id: 'a03',
      title: '悩み1項目だけで開始できる',
      primaryMetric: 'first action start rate',
    ),
    ActivationRevenueHypothesis(
      id: 'a04',
      title: '入力例から迷わず開始できる',
      primaryMetric: 'first action start rate',
    ),
    ActivationRevenueHypothesis(
      id: 'a05',
      title: '個別化した最優先1件を即時表示する',
      primaryMetric: 'first value completion rate',
    ),
    ActivationRevenueHypothesis(
      id: 'a06',
      title: '表示名を任意入力にして離脱を減らす',
      primaryMetric: 'onboarding completion rate',
    ),
    ActivationRevenueHypothesis(
      id: 'a07',
      title: '目的・提案・開始の3段階を見せる',
      primaryMetric: 'onboarding completion rate',
    ),
    ActivationRevenueHypothesis(
      id: 'a08',
      title: '提案を保存して再開できる価値を伝える',
      primaryMetric: 'onboarding completion rate',
    ),
    ActivationRevenueHypothesis(
      id: 'a09',
      title: '初回価値の後だけ任意課金を提示する',
      primaryMetric: 'billing view rate',
    ),
    ActivationRevenueHypothesis(
      id: 'a10',
      title: '無料・100円支援・Proの違いを価値で説明する',
      primaryMetric: 'checkout start rate',
    ),
  ];

  static const Set<String> supportedStages = {
    'onboarding_view',
    'intent_selected',
    'first_action_started',
    'first_action_completed',
    'onboarding_completed',
    'value_recap_view',
    'billing_view',
    'supporter_checkout',
    'pro_checkout',
    'checkout_return',
  };

  static final RegExp _eventKeyPattern = RegExp(
    r'^activation_exp_a(?:0[1-9]|10)_(?:control|treatment)_(?:onboarding_view|intent_selected|first_action_started|first_action_completed|onboarding_completed|value_recap_view|billing_view|supporter_checkout|pro_checkout|checkout_return)$',
  );

  Future<ActivationRevenueAssignment> resolve({
    Uri? uri,
    SharedPreferences? preferences,
    int? deterministicBucket,
  }) async {
    final override = _resolveOverride(uri);
    if (override != null) return override;

    final prefs = preferences ?? await SharedPreferences.getInstance();
    final stored = _resolveStored(prefs);
    if (stored != null) return stored;

    final bucket =
        deterministicBucket ?? Random().nextInt(hypotheses.length * 2);
    final normalizedBucket = bucket.abs() % (hypotheses.length * 2);
    final assignment = ActivationRevenueAssignment(
      hypothesis: hypotheses[normalizedBucket % hypotheses.length],
      variant: normalizedBucket < hypotheses.length
          ? ActivationRevenueVariant.control
          : ActivationRevenueVariant.treatment,
    );
    await prefs.setString(_hypothesisPreferenceKey, assignment.hypothesis.id);
    await prefs.setString(_variantPreferenceKey, assignment.variant.name);
    return assignment;
  }

  static bool isExperimentEventKey(String eventKey) {
    return _eventKeyPattern.hasMatch(eventKey);
  }

  ActivationRevenueAssignment? _resolveOverride(Uri? uri) {
    final hypothesisId = uri?.queryParameters['activation_hypothesis'];
    final variantName = uri?.queryParameters['activation_variant'];
    if (hypothesisId == null || variantName == null) return null;
    return _resolveValues(hypothesisId, variantName);
  }

  ActivationRevenueAssignment? _resolveStored(SharedPreferences prefs) {
    return _resolveValues(
      prefs.getString(_hypothesisPreferenceKey),
      prefs.getString(_variantPreferenceKey),
    );
  }

  ActivationRevenueAssignment? _resolveValues(
    String? hypothesisId,
    String? variantName,
  ) {
    ActivationRevenueHypothesis? hypothesis;
    for (final candidate in hypotheses) {
      if (candidate.id == hypothesisId) {
        hypothesis = candidate;
        break;
      }
    }
    if (hypothesis == null) return null;

    ActivationRevenueVariant? variant;
    for (final candidate in ActivationRevenueVariant.values) {
      if (candidate.name == variantName) {
        variant = candidate;
        break;
      }
    }
    if (variant == null) return null;
    return ActivationRevenueAssignment(
      hypothesis: hypothesis,
      variant: variant,
    );
  }
}
