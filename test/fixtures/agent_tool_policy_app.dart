import 'package:flutter/material.dart';
import 'package:my_web_app/pages/agent_tool_policy_preview_page.dart';

// Controlled transport responses; this fixture never contacts production.
void main() {
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  var failures = 0;
  runApp(
    MaterialApp(
      home: AgentToolPolicyPreviewPage(
        preview: (role, scopes) async {
          await Future<void>.delayed(const Duration(milliseconds: 150));
          if (scopes == 'offline' && failures++ == 0) {
            throw StateError('controlled transport failure');
          }
          return {
            'allowed': scopes == 'read' || scopes == 'offline',
            'blocked_reason': scopes == 'read' || scopes == 'offline'
                ? null
                : 'invalid_requested_scope',
          };
        },
      ),
    ),
  );
}
