import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Immutable snapshot of the active authentication token.
@immutable
class AuthSessionSnapshot {
  const AuthSessionSnapshot({
    required this.accessToken,
    this.expiresAt,
  });

  final String accessToken;
  final DateTime? expiresAt;

  bool get hasToken => accessToken.trim().isNotEmpty;
}

/// Abstract authentication gateway backing [AuthHttpInterceptorClient].
///
/// Implementations resolve session state dynamically at request time rather than
/// capturing tokens inside closures.
abstract class AuthSessionGateway {
  AuthSessionSnapshot? currentSession();

  Future<AuthSessionSnapshot?> refreshSession();

  Future<void> clearSession();
}

typedef SupabaseClientResolver = SupabaseClient Function();
typedef AuthClock = DateTime Function();
typedef UnauthorizedRedirectCallback = FutureOr<void> Function(
  String loginRoute,
);

/// Default [AuthSessionGateway] backed lazily by [Supabase.instance.client].
class SupabaseAuthSessionGateway implements AuthSessionGateway {
  SupabaseAuthSessionGateway({
    SupabaseClientResolver? clientResolver,
    Future<void> Function()? onLocalAuthCleared,
  })  : _clientResolver = clientResolver ?? _defaultClientResolver,
        _onLocalAuthCleared = onLocalAuthCleared;

  final SupabaseClientResolver _clientResolver;
  final Future<void> Function()? _onLocalAuthCleared;

  static SupabaseClient _defaultClientResolver() => Supabase.instance.client;

  @override
  AuthSessionSnapshot? currentSession() {
    final session = _clientResolver().auth.currentSession;
    if (session == null || session.accessToken.trim().isEmpty) {
      return null;
    }
    return _snapshotFromSession(session);
  }

  @override
  Future<AuthSessionSnapshot?> refreshSession() async {
    final response = await _clientResolver().auth.refreshSession();
    final session = response.session ?? _clientResolver().auth.currentSession;
    if (session == null || session.accessToken.trim().isEmpty) {
      return null;
    }
    return _snapshotFromSession(session);
  }

  @override
  Future<void> clearSession() async {
    try {
      await _clientResolver().auth.signOut();
    } catch (_) {
      // Best-effort sign-out; local cleanup callback still runs below.
    }
    final hook = _onLocalAuthCleared;
    if (hook != null) {
      await hook();
    }
  }

  static AuthSessionSnapshot _snapshotFromSession(Session session) {
    final epochSeconds = session.expiresAt;
    final jwt = session.accessToken;
    return AuthSessionSnapshot(
      accessToken: jwt,
      expiresAt: epochSeconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              epochSeconds * 1000,
              isUtc: true,
            ),
    );
  }
}

/// Configuration for [AuthHttpInterceptorClient].
@immutable
class AuthHttpInterceptorConfig {
  const AuthHttpInterceptorConfig({
    this.loginRoute = '/login',
    this.refreshLeadTime = const Duration(seconds: 60),
    this.allowedAuthOrigins = const <String>{},
    this.throwOnUnauthorized = false,
  });

  final String loginRoute;
  final Duration refreshLeadTime;

  /// Origin allowlist (e.g. `https://api.example.com`) eligible to receive
  /// `Authorization: Bearer` tokens. Fails closed when empty.
  final Set<String> allowedAuthOrigins;

  /// When true, throws [AuthHttpUnauthorizedException] after clearing auth and
  /// redirecting to [loginRoute] on an unrecoverable 401 response.
  final bool throwOnUnauthorized;
}

/// Exception raised when an API request fails authentication even after retry.
class AuthHttpUnauthorizedException implements Exception {
  const AuthHttpUnauthorizedException({
    required this.uri,
    required this.statusCode,
    this.message = '認証の有効期限が切れています。再度ログインしてください。',
  });

  final Uri uri;
  final int statusCode;
  final String message;

  @override
  String toString() =>
      'AuthHttpUnauthorizedException($statusCode, $uri): $message';
}

/// Centralized [http.BaseClient] interceptor that:
/// 1. Injects the latest non-stale Bearer token on allowed-origin requests.
/// 2. Coalesces proactive and 401-triggered token refreshes in a single flight.
/// 3. Clears local auth state and routes to `/login` on unrecoverable 401s.
class AuthHttpInterceptorClient extends http.BaseClient {
  AuthHttpInterceptorClient({
    required AuthSessionGateway sessionGateway,
    http.Client? innerClient,
    AuthHttpInterceptorConfig config = const AuthHttpInterceptorConfig(),
    GlobalKey<NavigatorState>? navigatorKey,
    UnauthorizedRedirectCallback? onUnauthorizedRedirect,
    AuthClock? clock,
  })  : _sessionGateway = sessionGateway,
        _inner = innerClient ?? http.Client(),
        _config = config,
        _navigatorKey = navigatorKey,
        _onUnauthorizedRedirect = onUnauthorizedRedirect,
        _clock = clock ?? _utcNow;

  static const String skipAuthHeader = 'x-skip-auth';

  final AuthSessionGateway _sessionGateway;
  final http.Client _inner;
  final AuthHttpInterceptorConfig _config;
  final GlobalKey<NavigatorState>? _navigatorKey;
  final UnauthorizedRedirectCallback? _onUnauthorizedRedirect;
  final AuthClock _clock;

  Future<AuthSessionSnapshot?>? _inFlightRefresh;
  Future<void>? _inFlightUnauthorized;
  bool _closed = false;

  static DateTime _utcNow() => DateTime.now().toUtc();

  /// Returns whether [uri] matches one of [AuthHttpInterceptorConfig.allowedAuthOrigins].
  bool isAuthOriginAllowed(Uri uri) {
    if (!uri.hasScheme || uri.host.isEmpty) {
      return false;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') {
      return false;
    }
    final requestPort = _effectivePort(uri);
    final requestHost = uri.host.toLowerCase();

    for (final rawOrigin in _config.allowedAuthOrigins) {
      final parsed = Uri.tryParse(rawOrigin.trim());
      if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
        continue;
      }
      if (parsed.scheme.toLowerCase() == scheme &&
          parsed.host.toLowerCase() == requestHost &&
          _effectivePort(parsed) == requestPort) {
        return true;
      }
    }
    return false;
  }

  static int _effectivePort(Uri uri) {
    if (uri.hasPort) return uri.port;
    return uri.scheme.toLowerCase() == 'https' ? 443 : 80;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) {
      throw StateError('AuthHttpInterceptorClient is already closed');
    }

    final skipAuth = _consumeSkipAuthHeader(request);
    final shouldAttachAuth = !skipAuth && isAuthOriginAllowed(request.url);
    final _ReplayTemplate? replayTemplate =
        request is http.Request ? _ReplayTemplate.fromRequest(request) : null;

    String? authValue;
    if (shouldAttachAuth) {
      authValue = await _resolveActiveToken();
      _applyAuthorizationHeader(request, authValue);
    }

    final firstResponse = await _inner.send(request);
    if (firstResponse.statusCode != 401 || !shouldAttachAuth) {
      return firstResponse;
    }

    final refreshed = await _refreshCoalesced(priorAuth: authValue);
    if (refreshed != null && refreshed.hasToken && replayTemplate != null) {
      await firstResponse.stream.drain<void>();
      final nextAuth = refreshed.accessToken;
      final retryRequest = replayTemplate.buildRequest(
        bearerValue: nextAuth,
      );
      final retryResponse = await _inner.send(retryRequest);
      if (retryResponse.statusCode != 401) {
        return retryResponse;
      }
      await _handleUnauthorized();
      if (_config.throwOnUnauthorized) {
        await retryResponse.stream.drain<void>();
        throw AuthHttpUnauthorizedException(
          uri: request.url,
          statusCode: retryResponse.statusCode,
        );
      }
      return retryResponse;
    }

    await _handleUnauthorized();
    if (_config.throwOnUnauthorized) {
      await firstResponse.stream.drain<void>();
      throw AuthHttpUnauthorizedException(
        uri: request.url,
        statusCode: firstResponse.statusCode,
      );
    }
    return firstResponse;
  }

  bool _consumeSkipAuthHeader(http.BaseRequest request) {
    String? matchedKey;
    String? matchedValue;
    for (final entry in request.headers.entries) {
      if (entry.key.toLowerCase() == skipAuthHeader) {
        matchedKey = entry.key;
        matchedValue = entry.value;
        break;
      }
    }
    if (matchedKey != null) {
      request.headers.remove(matchedKey);
    }
    return matchedValue?.trim().toLowerCase() == 'true';
  }

  Future<String?> _resolveActiveToken() async {
    final current = _sessionGateway.currentSession();
    if (current == null || !current.hasToken) {
      return null;
    }
    if (_needsProactiveRefresh(current)) {
      final priorAuth = current.accessToken;
      final refreshed = await _refreshCoalesced(
        priorAuth: priorAuth,
      );
      if (refreshed != null && refreshed.hasToken) {
        return refreshed.accessToken;
      }
      return _sessionGateway.currentSession()?.accessToken;
    }
    return current.accessToken;
  }

  bool _needsProactiveRefresh(AuthSessionSnapshot snapshot) {
    final expiresAt = snapshot.expiresAt;
    if (expiresAt == null) return false;
    final cutoff = _clock().toUtc().add(_config.refreshLeadTime);
    return !expiresAt.toUtc().isAfter(cutoff);
  }

  Future<AuthSessionSnapshot?> _refreshCoalesced({
    required String? priorAuth,
  }) async {
    final latest = _sessionGateway.currentSession();
    final latestAuth = latest?.accessToken;
    if (priorAuth != null &&
        latest != null &&
        latest.hasToken &&
        latestAuth != priorAuth &&
        !_needsProactiveRefresh(latest)) {
      return latest;
    }

    final existing = _inFlightRefresh;
    if (existing != null) {
      return existing;
    }

    final completer = _runRefresh();
    _inFlightRefresh = completer;
    try {
      return await completer;
    } finally {
      if (identical(_inFlightRefresh, completer)) {
        _inFlightRefresh = null;
      }
    }
  }

  Future<AuthSessionSnapshot?> _runRefresh() async {
    try {
      final next = await _sessionGateway.refreshSession();
      if (next != null && next.hasToken) {
        return next;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleUnauthorized() async {
    final existing = _inFlightUnauthorized;
    if (existing != null) {
      return existing;
    }
    final future = _clearAndRedirect();
    _inFlightUnauthorized = future;
    try {
      await future;
    } finally {
      if (identical(_inFlightUnauthorized, future)) {
        _inFlightUnauthorized = null;
      }
    }
  }

  Future<void> _clearAndRedirect() async {
    await _sessionGateway.clearSession();
    final callback = _onUnauthorizedRedirect;
    if (callback != null) {
      await callback(_config.loginRoute);
      return;
    }
    final navigatorState = _navigatorKey?.currentState;
    if (navigatorState != null) {
      // Do not await pushNamedAndRemoveUntil; its Future resolves only on pop.
      unawaited(
        navigatorState.pushNamedAndRemoveUntil(
          _config.loginRoute,
          (Route<dynamic> _) => false,
        ),
      );
    }
  }

  static void _applyAuthorizationHeader(
    http.BaseRequest request,
    String? token,
  ) {
    final keysToRemove = request.headers.keys
        .where((key) => key.toLowerCase() == 'authorization')
        .toList();
    for (final key in keysToRemove) {
      request.headers.remove(key);
    }
    if (token != null && token.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _inner.close();
    super.close();
  }
}

class _ReplayTemplate {
  const _ReplayTemplate({
    required this.method,
    required this.url,
    required this.headers,
    required this.bodyBytes,
    required this.followRedirects,
    required this.maxRedirects,
    required this.persistentConnection,
  });

  factory _ReplayTemplate.fromRequest(http.Request request) {
    return _ReplayTemplate(
      method: request.method,
      url: request.url,
      headers: Map<String, String>.from(request.headers),
      bodyBytes: List<int>.from(request.bodyBytes),
      followRedirects: request.followRedirects,
      maxRedirects: request.maxRedirects,
      persistentConnection: request.persistentConnection,
    );
  }

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final List<int> bodyBytes;
  final bool followRedirects;
  final int maxRedirects;
  final bool persistentConnection;

  http.Request buildRequest({required String bearerValue}) {
    final clone = http.Request(method, url)
      ..followRedirects = followRedirects
      ..maxRedirects = maxRedirects
      ..persistentConnection = persistentConnection;
    clone.headers.addAll(headers);
    if (bodyBytes.isNotEmpty) {
      clone.bodyBytes = bodyBytes;
    }
    AuthHttpInterceptorClient._applyAuthorizationHeader(clone, bearerValue);
    return clone;
  }
}
