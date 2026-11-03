import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:my_web_app/services/payment_owner_local_candidate.dart';

void main() {
  globalContext.setProperty(
    'syntheticCandidateRun'.toJS,
    ((JSString input) {
      final args = jsonDecode(input.toDart) as Map<String, dynamic>;
      final store =
          createPaymentOwnerLocalCandidate(args['database'] as String);
      return store
          .compareAndSet(
            owner: args['owner'] as String,
            expectedRevision: args['expectedRevision'] as int,
            requestId: args['requestId'] as String,
            value: args['value'] as String,
          )
          .then((result) => jsonEncode({
                'status': result.status.name,
                'revision': result.revision,
              }).toJS)
          .toJS;
    }).toJS,
  );
}
