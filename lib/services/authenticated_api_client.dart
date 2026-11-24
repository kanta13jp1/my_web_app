import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'auth_http_interceptor_client.dart';

/// Unified exception for failed JSON API calls executed by [AuthenticatedApiClient].
class AuthenticatedApiException implements Exception {
  const AuthenticatedApiException({
    required this.uri,
    required this.statusCode,
    required this.body,
  });

  final Uri uri;
  final int statusCode;
  final String body;

  @override
  String toString() =>
      'AuthenticatedApiException($statusCode, $uri): ${body.length > 200 ? body.substring(0, 200) : body}';
}

/// Centralized API module so feature components issue JSON requests without
/// touching auth headers, token refresh locks, or 401 session redirects.
class AuthenticatedApiClient {
  AuthenticatedApiClient({
    required AuthHttpInterceptorClient httpClient,
    Uri? baseUri,
  })  : _httpClient = httpClient,
        _baseUri = baseUri;

  /// Convenience factory bound lazily to [SupabaseAuthSessionGateway].
  factory AuthenticatedApiClient.fromSupabase({
    required Set<String> allowedAuthOrigins,
    Uri? baseUri,
    GlobalKey<NavigatorState>? navigatorKey,
    UnauthorizedRedirectCallback? onUnauthorizedRedirect,
    http.Client? innerClient,
    String loginRoute = '/login',
  }) {
    return AuthenticatedApiClient(
      baseUri: baseUri,
      httpClient: AuthHttpInterceptorClient(
        sessionGateway: SupabaseAuthSessionGateway(),
        innerClient: innerClient,
        navigatorKey: navigatorKey,
        onUnauthorizedRedirect: onUnauthorizedRedirect,
        config: AuthHttpInterceptorConfig(
          loginRoute: loginRoute,
          allowedAuthOrigins: allowedAuthOrigins,
        ),
      ),
    );
  }

  final AuthHttpInterceptorClient _httpClient;
  final Uri? _baseUri;

  Uri resolveUri(String pathOrUrl) {
    final trimmed = pathOrUrl.trim();
    final parsed = Uri.parse(trimmed);
    if (parsed.hasScheme) {
      return parsed;
    }
    final base = _baseUri;
    if (base == null) {
      throw ArgumentError.value(
        pathOrUrl,
        'pathOrUrl',
        'Relative path requires a non-null baseUri on AuthenticatedApiClient',
      );
    }
    return base.resolveUri(parsed);
  }

  Future<Map<String, dynamic>> getJson(
    String pathOrUrl, {
    Map<String, String>? headers,
  }) =>
      _sendJson('GET', pathOrUrl, headers: headers);

  Future<Map<String, dynamic>> postJson(
    String pathOrUrl, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) =>
      _sendJson('POST', pathOrUrl, body: body, headers: headers);

  Future<Map<String, dynamic>> putJson(
    String pathOrUrl, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) =>
      _sendJson('PUT', pathOrUrl, body: body, headers: headers);

  Future<Map<String, dynamic>> deleteJson(
    String pathOrUrl, {
    Map<String, String>? headers,
  }) =>
      _sendJson('DELETE', pathOrUrl, headers: headers);

  Future<Map<String, dynamic>> _sendJson(
    String method,
    String pathOrUrl, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = resolveUri(pathOrUrl);
    final request = http.Request(method, uri);
    request.headers['Accept'] = 'application/json';
    if (headers != null) {
      request.headers.addAll(headers);
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401) {
      throw AuthHttpUnauthorizedException(
        uri: uri,
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthenticatedApiException(
        uri: uri,
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    if (response.body.trim().isEmpty) {
      return const <String, dynamic>{};
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{'data': decoded};
  }

  void close() => _httpClient.close();
}
