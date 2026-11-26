import 'package:flutter/material.dart';
import 'package:my_web_app/utils/home_feature_request_failure.dart';

SnackBar buildHomeFeatureRequestFailureSnackBar({
  required HomeFeatureRequestFailure failure,
  required Color backgroundColor,
  required VoidCallback onRetry,
}) {
  return SnackBar(
    content: Text(failure.userMessage),
    action: SnackBarAction(
      label: failure.retryLabel,
      onPressed: onRetry,
    ),
    backgroundColor: backgroundColor,
  );
}
