enum HomeFeatureRequestFailure {
  attachmentSelection(
    code: 'attachment_selection_failed',
    userMessage: '画像を選択できませんでした。対応形式と6MB以下のサイズを確認してください。',
    retryLabel: '画像を選び直す',
  ),
  attachmentAnalysis(
    code: 'attachment_analysis_failed',
    userMessage: '画像AI診断を完了できませんでした。通信状況を確認して、もう一度お試しください。',
    retryLabel: 'AI診断を再試行',
  ),
  submission(
    code: 'feature_request_submission_failed',
    userMessage: '追加要望を送信できませんでした。入力内容は保持されています。もう一度お試しください。',
    retryLabel: '送信を再試行',
  );

  const HomeFeatureRequestFailure({
    required this.code,
    required this.userMessage,
    required this.retryLabel,
  });

  final String code;
  final String userMessage;
  final String retryLabel;
}
