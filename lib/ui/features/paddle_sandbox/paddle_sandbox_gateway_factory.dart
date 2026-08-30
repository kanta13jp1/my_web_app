import 'paddle_sandbox_gateway.dart';
import 'paddle_sandbox_gateway_stub.dart'
    if (dart.library.js_interop) 'paddle_sandbox_gateway_web.dart'
    as implementation;

PaddleSandboxGateway createPaddleSandboxGateway() {
  return implementation.createPaddleSandboxGateway();
}
