import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'data/procrastination_reset_gateway.dart';
import 'view_models/procrastination_reset_view_model.dart';
import 'views/procrastination_reset_page.dart';

class ProcrastinationResetFeature extends StatelessWidget {
  const ProcrastinationResetFeature({super.key, this.gateway, this.now});

  static const routeName = '/procrastination-reset';

  final ProcrastinationResetGateway? gateway;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProcrastinationResetViewModel>(
      create: (_) => ProcrastinationResetViewModel(
        gateway: gateway ?? SharedPreferencesProcrastinationResetGateway(),
        now: now,
      )..load(),
      child: const ProcrastinationResetPage(),
    );
  }
}
