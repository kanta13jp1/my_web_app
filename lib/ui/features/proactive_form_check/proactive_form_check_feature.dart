import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'data/proactive_form_validator.dart';
import 'view_models/proactive_form_check_view_model.dart';
import 'views/proactive_form_check_page.dart';

class ProactiveFormCheckFeature extends StatelessWidget {
  const ProactiveFormCheckFeature({
    super.key,
    this.validator,
    this.debounceDuration = const Duration(milliseconds: 550),
  });

  static const routeName = '/proactive-form-check';

  final ProactiveFormValidator? validator;
  final Duration debounceDuration;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProactiveFormCheckViewModel>(
      create: (_) => ProactiveFormCheckViewModel(
        validator: validator ?? const RuleBasedProactiveFormValidator(),
        debounceDuration: debounceDuration,
      ),
      child: const ProactiveFormCheckPage(),
    );
  }
}
