/// Domain models and deterministic evaluator for pre-editor browser/hardware
/// compatibility and media permissions (#2716).
enum PreflightSeverity {
  pass('pass', '適合'),
  warning('warning', '推奨事項あり'),
  blocker('blocker', '要対応 (ブロック)');

  const PreflightSeverity(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

enum MediaPermissionState {
  granted('granted', '許可済み'),
  prompt('prompt', '未確認 (要テスト)'),
  denied('denied', '拒否 (OS/ブラウザ設定要確認)'),
  unsupported('unsupported', '非対応');

  const MediaPermissionState(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

enum BrowserEngineKind {
  chromium('chromium', 'Chromium系 (Chrome / Edge)'),
  firefox('firefox', 'Firefox'),
  safari('safari', 'Safari / WebKit'),
  other('other', 'その他 / ネイティブ');

  const BrowserEngineKind(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

class VideoSystemSnapshot {
  const VideoSystemSnapshot({
    required this.isWebRuntime,
    required this.isSecureContext,
    required this.userAgent,
    required this.browserName,
    required this.engine,
    required this.webGlAvailable,
    required this.hardwareAccelerated,
    required this.gpuRenderer,
    required this.deviceMemoryGb,
    required this.hardwareConcurrency,
    required this.supportsMediaDevices,
    required this.supportsDisplayMedia,
    required this.microphonePermission,
    required this.cameraPermission,
    required this.screenSharePermission,
  });

  final bool isWebRuntime;
  final bool isSecureContext;
  final String userAgent;
  final String browserName;
  final BrowserEngineKind engine;
  final bool webGlAvailable;
  final bool hardwareAccelerated;
  final String gpuRenderer;
  final double? deviceMemoryGb;
  final int? hardwareConcurrency;
  final bool supportsMediaDevices;
  final bool supportsDisplayMedia;
  final MediaPermissionState microphonePermission;
  final MediaPermissionState cameraPermission;
  final MediaPermissionState screenSharePermission;
}

class PreflightCheckItem {
  const PreflightCheckItem({
    required this.id,
    required this.title,
    required this.severity,
    required this.summary,
    this.remediationSteps = const <String>[],
  });

  final String id;
  final String title;
  final PreflightSeverity severity;
  final String summary;
  final List<String> remediationSteps;
}

class VideoPreflightReport {
  const VideoPreflightReport({
    required this.snapshot,
    required this.checks,
    required this.overallSeverity,
    required this.troubleshootingSteps,
  });

  final VideoSystemSnapshot snapshot;
  final List<PreflightCheckItem> checks;
  final PreflightSeverity overallSeverity;
  final List<String> troubleshootingSteps;

  bool get hasBlockers => overallSeverity == PreflightSeverity.blocker;

  bool get hasWarnings => overallSeverity == PreflightSeverity.warning;

  bool get canProceedSmoothly => overallSeverity == PreflightSeverity.pass;
}

abstract interface class VideoPreflightProbe {
  Future<VideoSystemSnapshot> collectSnapshot();

  Future<VideoSystemSnapshot> verifyPermission({
    required final String capability,
  });
}

bool isSoftwareGpuRenderer(final String renderer) {
  final normalized = renderer.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  const softwareHints = <String>[
    'swiftshader',
    'llvmpipe',
    'softpipe',
    'microsoft basic render',
    'software rasterizer',
    'google swiftshader',
  ];
  for (final hint in softwareHints) {
    if (normalized.contains(hint)) {
      return true;
    }
  }
  return false;
}

BrowserEngineKind classifyBrowserEngine(final String userAgent) {
  final ua = userAgent.toLowerCase();
  if (ua.contains('edg/') ||
      ua.contains('chrome/') ||
      ua.contains('chromium/') ||
      ua.contains('crios/')) {
    return BrowserEngineKind.chromium;
  }
  if (ua.contains('firefox/') || ua.contains('fxios/')) {
    return BrowserEngineKind.firefox;
  }
  if (ua.contains('safari/') && !ua.contains('chrome/')) {
    return BrowserEngineKind.safari;
  }
  return BrowserEngineKind.other;
}

String detectBrowserLabel(final String userAgent) {
  final ua = userAgent.toLowerCase();
  if (ua.contains('edg/')) return 'Microsoft Edge (Chromium)';
  if (ua.contains('chrome/') || ua.contains('chromium/')) {
    return 'Google Chrome / Chromium';
  }
  if (ua.contains('firefox/')) return 'Mozilla Firefox';
  if (ua.contains('safari/')) return 'Apple Safari';
  return userAgent.trim().isEmpty ? '非ブラウザ環境 (VM / Native)' : 'その他ブラウザ';
}

VideoPreflightReport evaluateVideoPreflight(
  final VideoSystemSnapshot snapshot,
) {
  final checks = <PreflightCheckItem>[];
  final troubleshooting = <String>[];

  // 1. Browser Engine & HTTPS Secure Context.
  if (snapshot.isWebRuntime && !snapshot.isSecureContext) {
    final steps = <String>[
      'カメラ・マイク・画面共有 API を有効にするため、必ず HTTPS (または localhost) でアクセスしてください。',
    ];
    checks.add(
      PreflightCheckItem(
        id: 'secure_context',
        title: 'HTTPS セキュアコンテキスト',
        severity: PreflightSeverity.blocker,
        summary: '非HTTPS環境では録音・録画・画面共有 API がブラウザ仕様によりブロックされます。',
        remediationSteps: steps,
      ),
    );
    troubleshooting.addAll(steps);
  } else if (snapshot.isWebRuntime &&
      snapshot.engine != BrowserEngineKind.chromium) {
    final steps = <String>[
      '動画編集およびハードウェアアクセラレーションの安定稼働のため、Google Chrome または Microsoft Edge（Chromium ベース最新版）の利用を推奨します。',
    ];
    checks.add(
      PreflightCheckItem(
        id: 'browser_engine',
        title: '推奨ブラウザ互換性 (${snapshot.browserName})',
        severity: PreflightSeverity.warning,
        summary: '非Chromiumブラウザではマルチトラック再生や画面共有の安定性が低下する場合があります。',
        remediationSteps: steps,
      ),
    );
    troubleshooting.addAll(steps);
  } else {
    checks.add(
      PreflightCheckItem(
        id: 'browser_engine',
        title: 'ブラウザ互換性 (${snapshot.browserName})',
        severity: PreflightSeverity.pass,
        summary: snapshot.isWebRuntime
            ? '推奨 Chromium ベースブラウザ・HTTPS 環境で稼働しています。'
            : '非Webコンテキスト（VM/Native）として安全にバイパスされました。',
      ),
    );
  }

  // 2. WebGL & GPU Hardware Acceleration.
  if (snapshot.isWebRuntime &&
      (!snapshot.webGlAvailable || !snapshot.hardwareAccelerated)) {
    final steps = <String>[
      'Chrome のアドレスバーに chrome://settings/system を入力し、「利用可能な場合はグラフィック アクセラレーションを使用する」をオンにして Chrome を再起動してください。',
      '再起動後、chrome://gpu を開き「WebGL」および「Video Decode」が Hardware accelerated になっていることを確認してください。',
      '改善しない場合は GPU ドライバを更新し、複数ウィンドウや外部 GPU 切替設定を確認してください。',
    ];
    checks.add(
      PreflightCheckItem(
        id: 'hardware_acceleration',
        title: 'ハードウェアアクセラレーション / WebGL',
        severity: PreflightSeverity.blocker,
        summary: snapshot.webGlAvailable
            ? 'ソフトウェア描画 (${snapshot.gpuRenderer}) が検知され、GPU アクセラレーションが無効になっています。'
            : 'WebGL コンテキストが取得できません（GPU アクセラレーション無効またはブロック）。',
        remediationSteps: steps,
      ),
    );
    troubleshooting.addAll(steps);
  } else {
    final rendererNote =
        snapshot.gpuRenderer.isNotEmpty ? ' (${snapshot.gpuRenderer})' : '';
    checks.add(
      PreflightCheckItem(
        id: 'hardware_acceleration',
        title: 'ハードウェアアクセラレーション / WebGL',
        severity: PreflightSeverity.pass,
        summary: snapshot.isWebRuntime
            ? 'GPU 描画が有効です$rendererNote。'
            : 'WebGL チェックは Web ランタイム実行時に評価されます。',
      ),
    );
  }

  // 3. System Memory (deviceMemory) & CPU Concurrency.
  final mem = snapshot.deviceMemoryGb;
  final cores = snapshot.hardwareConcurrency;
  if (mem != null && mem < 4.0) {
    final steps = <String>[
      'システムメモリ推定値が ${mem.toStringAsFixed(0)} GB 未満のため、動画編集時のタブクラッシュを防ぐには不要なタブを閉じ、8 GB RAM 以上の端末での実行を推奨します。',
    ];
    checks.add(
      PreflightCheckItem(
        id: 'memory_cpu',
        title: 'メモリ / CPU リソース',
        severity: PreflightSeverity.blocker,
        summary:
            'Navigator.deviceMemory = ${mem.toStringAsFixed(1)} GB (最低 4 GB / 推奨 8 GB 以上)。',
        remediationSteps: steps,
      ),
    );
    troubleshooting.addAll(steps);
  } else if ((mem != null && mem < 8.0) || (cores != null && cores < 4)) {
    final steps = <String>[
      '快適な動画プレビューのため 8 GB 以上の RAM（16 GB 推奨）および 4 コア以上の CPU を推奨します。重い編集時は他タブを閉じてください。',
    ];
    checks.add(
      PreflightCheckItem(
        id: 'memory_cpu',
        title: 'メモリ / CPU リソース',
        severity: PreflightSeverity.warning,
        summary:
            'RAM: ${mem?.toStringAsFixed(1) ?? '非公開'} GB / CPU コア数: ${cores ?? 0}',
        remediationSteps: steps,
      ),
    );
    troubleshooting.addAll(steps);
  } else {
    checks.add(
      PreflightCheckItem(
        id: 'memory_cpu',
        title: 'メモリ / CPU リソース',
        severity: PreflightSeverity.pass,
        summary:
            'RAM: ${mem?.toStringAsFixed(1) ?? '標準/非公開'} GB / CPU コア数: ${cores ?? 0}',
      ),
    );
  }

  // 4. Microphone / Camera / Screen Share Permissions.
  final hasDeniedMedia =
      snapshot.microphonePermission == MediaPermissionState.denied ||
          snapshot.cameraPermission == MediaPermissionState.denied ||
          snapshot.screenSharePermission == MediaPermissionState.denied;
  final hasPromptMedia =
      snapshot.microphonePermission == MediaPermissionState.prompt ||
          snapshot.cameraPermission == MediaPermissionState.prompt ||
          snapshot.screenSharePermission == MediaPermissionState.prompt;

  if (snapshot.isWebRuntime && !snapshot.supportsMediaDevices) {
    final steps = <String>[
      'navigator.mediaDevices が利用できません。Chrome 最新版かつ HTTPS 環境で再読み込みしてください。',
    ];
    checks.add(
      PreflightCheckItem(
        id: 'media_permissions',
        title: 'マイク・カメラ・画面共有パーミッション',
        severity: PreflightSeverity.blocker,
        summary: 'MediaDevices API が無効です。',
        remediationSteps: steps,
      ),
    );
    troubleshooting.addAll(steps);
  } else if (hasDeniedMedia) {
    final steps = <String>[
      'Chrome アドレスバー左のアイコン →「サイトの設定」または chrome://settings/content を開き、「マイク」「カメラ」の許可を「許可」に変更してページを再読み込みしてください。',
      'OS 側設定（macOS「システム設定 > プライバシーとセキュリティ > マイク/画面収録」または Windows「設定 > プライバシーとセキュリティ > マイク/カメラ」）で Chrome へのアクセス許可がオンになっているか確認してください。',
    ];
    checks.add(
      PreflightCheckItem(
        id: 'media_permissions',
        title: 'マイク・カメラ・画面共有パーミッション',
        severity: PreflightSeverity.blocker,
        summary:
            '拒否された権限があります (マイク: ${snapshot.microphonePermission.label} / カメラ: ${snapshot.cameraPermission.label} / 画面共有: ${snapshot.screenSharePermission.label})。',
        remediationSteps: steps,
      ),
    );
    troubleshooting.addAll(steps);
  } else if (hasPromptMedia || !snapshot.supportsDisplayMedia) {
    final steps = <String>[
      '録画・画面収録を利用する前に、下の「許可状態を検証」ボタンからマイク・カメラ・画面共有のブラウザ許可を完了してください。',
    ];
    checks.add(
      PreflightCheckItem(
        id: 'media_permissions',
        title: 'マイク・カメラ・画面共有パーミッション',
        severity: PreflightSeverity.warning,
        summary:
            '未確認または非対応の機能があります (マイク: ${snapshot.microphonePermission.label} / カメラ: ${snapshot.cameraPermission.label} / 画面共有: ${snapshot.screenSharePermission.label})。',
        remediationSteps: steps,
      ),
    );
    troubleshooting.addAll(steps);
  } else {
    checks.add(
      const PreflightCheckItem(
        id: 'media_permissions',
        title: 'マイク・カメラ・画面共有パーミッション',
        severity: PreflightSeverity.pass,
        summary: 'マイク・カメラ・画面共有のアクセス権限が利用可能です。',
      ),
    );
  }

  var overall = PreflightSeverity.pass;
  for (final item in checks) {
    if (item.severity == PreflightSeverity.blocker) {
      overall = PreflightSeverity.blocker;
      break;
    }
    if (item.severity == PreflightSeverity.warning) {
      overall = PreflightSeverity.warning;
    }
  }

  return VideoPreflightReport(
    snapshot: snapshot,
    checks: List<PreflightCheckItem>.unmodifiable(checks),
    overallSeverity: overall,
    troubleshootingSteps: List<String>.unmodifiable(troubleshooting),
  );
}
