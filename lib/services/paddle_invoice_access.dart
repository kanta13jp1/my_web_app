import 'package:flutter/foundation.dart' show kReleaseMode;

typedef PaddleInvoicePortalLauncher = Future<bool> Function(Uri uri);

class PaddleInvoiceAccessConfig {
  const PaddleInvoiceAccessConfig({
    required this.enabled,
    required this.customerPortalUrl,
    required this.releaseMode,
  });

  factory PaddleInvoiceAccessConfig.fromEnvironment() {
    return const PaddleInvoiceAccessConfig(
      enabled: bool.fromEnvironment('PADDLE_SANDBOX_ENABLED'),
      customerPortalUrl: String.fromEnvironment(
        'PADDLE_SANDBOX_CUSTOMER_PORTAL_URL',
      ),
      releaseMode: kReleaseMode,
    );
  }

  final bool enabled;
  final String customerPortalUrl;
  final bool releaseMode;

  bool get shouldExpose => enabled && !releaseMode;

  Uri? get portalUri {
    final candidate = Uri.tryParse(customerPortalUrl.trim());
    return _isAllowedGenericSandboxPortal(candidate) ? candidate : null;
  }

  String? get validationMessage {
    if (releaseMode) {
      return 'Paddle sandbox の請求書導線は本番ビルドでは利用できません。';
    }
    if (!enabled) {
      return 'Paddle sandbox は無効です。';
    }
    if (customerPortalUrl.trim().isEmpty) {
      return 'Paddle sandbox のCustomer Portal URLが設定されていません。';
    }
    if (portalUri == null) {
      return 'Paddle sandbox の汎用Customer Portal URLを確認してください。';
    }
    return null;
  }

  bool get canOpen => shouldExpose && validationMessage == null;
}

bool _isAllowedGenericSandboxPortal(Uri? uri) {
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'sandbox-customer-portal.paddle.com' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.fragment.isNotEmpty ||
      uri.pathSegments.length != 1 ||
      !RegExp(r'^cpl_[a-z0-9]{10,}$').hasMatch(uri.pathSegments.single)) {
    return false;
  }

  // Authenticated portal-session and invoice links are temporary. Only the
  // stable generic portal URL may be compiled into this sandbox UI.
  return uri.queryParameters.isEmpty;
}
