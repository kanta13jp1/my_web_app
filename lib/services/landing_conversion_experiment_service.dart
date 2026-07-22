import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

enum LandingExperimentVariant { control, treatment }

class LandingConversionHypothesis {
  final String id;
  final String title;
  final String primaryMetric;

  const LandingConversionHypothesis({
    required this.id,
    required this.title,
    required this.primaryMetric,
  });
}

class LandingExperimentAssignment {
  final LandingConversionHypothesis hypothesis;
  final LandingExperimentVariant variant;

  const LandingExperimentAssignment({
    required this.hypothesis,
    required this.variant,
  });

  bool enables(String hypothesisId) {
    return hypothesis.id != hypothesisId ||
        variant == LandingExperimentVariant.treatment;
  }

  String eventKey(String stage) {
    if (!LandingConversionExperimentService.supportedStages.contains(stage)) {
      throw ArgumentError.value(stage, 'stage', 'Unsupported LP event stage');
    }
    return 'lp_exp_${hypothesis.id}_${variant.name}_$stage';
  }

  @override
  bool operator ==(Object other) {
    return other is LandingExperimentAssignment &&
        other.hypothesis.id == hypothesis.id &&
        other.variant == variant;
  }

  @override
  int get hashCode => Object.hash(hypothesis.id, variant);
}

class LandingConversionExperimentService {
  static const String _hypothesisPreferenceKey =
      'landing_conversion_hypothesis_v1';
  static const String _variantPreferenceKey = 'landing_conversion_variant_v1';

  static const List<LandingConversionHypothesis> hypotheses = [
    LandingConversionHypothesis(
      id: 'h01',
      title: '成果を先に伝えるヒーロー',
      primaryMetric: 'hero CTA rate',
    ),
    LandingConversionHypothesis(
      id: 'h02',
      title: '目的別パーソナライズ',
      primaryMetric: 'trial start rate',
    ),
    LandingConversionHypothesis(
      id: 'h03',
      title: '登録前の価値体験',
      primaryMetric: 'trial to signup rate',
    ),
    LandingConversionHypothesis(
      id: 'h04',
      title: 'Magic Linkを主導線にする',
      primaryMetric: 'signup submit rate',
    ),
    LandingConversionHypothesis(
      id: 'h05',
      title: '料金リスクを先回りして解消',
      primaryMetric: 'hero CTA rate',
    ),
    LandingConversionHypothesis(
      id: 'h06',
      title: '具体的な利用結果を見せる',
      primaryMetric: 'trial start rate',
    ),
    LandingConversionHypothesis(
      id: 'h07',
      title: '実数の社会的証明',
      primaryMetric: 'signup submit rate',
    ),
    LandingConversionHypothesis(
      id: 'h08',
      title: 'プライバシー不安を解消',
      primaryMetric: 'signup completion rate',
    ),
    LandingConversionHypothesis(
      id: 'h09',
      title: 'モバイル固定CTA',
      primaryMetric: 'mobile signup submit rate',
    ),
    LandingConversionHypothesis(
      id: 'h10',
      title: '登録後に続きが残る価値',
      primaryMetric: 'trial to signup rate',
    ),
  ];

  static const Set<String> supportedStages = {
    'view',
    'hero_cta',
    'intent',
    'trial',
    'save_cta',
    'signup_submit',
    'signup_complete',
    'sticky_cta',
    'feature_outcome_trial',
    'feature_catalog_expand',
  };

  static final RegExp _eventKeyPattern = RegExp(
    r'^lp_exp_h(?:0[1-9]|10)_(?:control|treatment)_(?:view|hero_cta|intent|trial|save_cta|signup_submit|signup_complete|sticky_cta|feature_outcome_trial|feature_catalog_expand)$',
  );

  const LandingConversionExperimentService();

  Future<LandingExperimentAssignment> resolve({
    Uri? uri,
    SharedPreferences? preferences,
    int? deterministicBucket,
  }) async {
    final override = _resolveOverride(uri);
    if (override != null) {
      return override;
    }

    final prefs = preferences ?? await SharedPreferences.getInstance();
    final stored = _resolveStored(prefs);
    if (stored != null) {
      return stored;
    }

    final bucket =
        deterministicBucket ?? Random().nextInt(hypotheses.length * 2);
    final normalizedBucket = bucket.abs() % (hypotheses.length * 2);
    final assignment = LandingExperimentAssignment(
      hypothesis: hypotheses[normalizedBucket % hypotheses.length],
      variant: normalizedBucket < hypotheses.length
          ? LandingExperimentVariant.control
          : LandingExperimentVariant.treatment,
    );
    await prefs.setString(_hypothesisPreferenceKey, assignment.hypothesis.id);
    await prefs.setString(_variantPreferenceKey, assignment.variant.name);
    return assignment;
  }

  static bool isExperimentEventKey(String eventKey) {
    return _eventKeyPattern.hasMatch(eventKey);
  }

  LandingExperimentAssignment? _resolveOverride(Uri? uri) {
    final hypothesisId = uri?.queryParameters['lp_hypothesis'];
    final variantName = uri?.queryParameters['lp_variant'];
    if (hypothesisId == null || variantName == null) {
      return null;
    }
    return _resolveValues(hypothesisId, variantName);
  }

  LandingExperimentAssignment? _resolveStored(SharedPreferences prefs) {
    return _resolveValues(
      prefs.getString(_hypothesisPreferenceKey),
      prefs.getString(_variantPreferenceKey),
    );
  }

  LandingExperimentAssignment? _resolveValues(
    String? hypothesisId,
    String? variantName,
  ) {
    LandingConversionHypothesis? hypothesis;
    for (final candidate in hypotheses) {
      if (candidate.id == hypothesisId) {
        hypothesis = candidate;
        break;
      }
    }
    if (hypothesis == null) {
      return null;
    }

    LandingExperimentVariant? variant;
    for (final candidate in LandingExperimentVariant.values) {
      if (candidate.name == variantName) {
        variant = candidate;
        break;
      }
    }
    if (variant == null) {
      return null;
    }
    return LandingExperimentAssignment(
      hypothesis: hypothesis,
      variant: variant,
    );
  }
}
