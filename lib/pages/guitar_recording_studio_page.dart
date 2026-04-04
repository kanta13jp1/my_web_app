import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

/// ギターレコーディングスタジオ (メイン機能)
/// スマホのマイクでギター演奏を録音・保存・再生できる。
/// guitar-recording-studio Edge Function と連携してスタジオ情報を取得。
class GuitarRecordingStudioPage extends StatefulWidget {
  const GuitarRecordingStudioPage({super.key});

  @override
  State<GuitarRecordingStudioPage> createState() =>
      _GuitarRecordingStudioPageState();
}

class _GuitarRecordingStudioPageState
    extends State<GuitarRecordingStudioPage> {
  final _supabase = Supabase.instance.client;

  // 録音状態
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  web.MediaRecorder? _mediaRecorder;
  web.MediaStream? _mediaStream;
  final List<JSObject> _audioChunks = [];
  String? _audioUrl;
  String? _errorMessage;

  // メトロノーム
  bool _isMetronomeActive = false;
  int _bpm = 120;
  int _beatCount = 0;
  int _beatsPerMeasure = 4;
  Timer? _metronomeTimer;

  // スタジオデータ
  bool _isLoadingStudio = false;
  List<String> _presets = [];
  List<String> _chordNames = [];
  List<String> _tuningNames = [];
  String _selectedPreset = 'acoustic_fingerpicking';
  String _selectedTuning = 'standard';

  // 保存フォーム
  final _titleController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _isSaving = false;
  bool _savedSuccessfully = false;
  bool _isPublic = false;
  String? _savedRecordingId; // 保存後の共有用ID

  // 選択中のコード
  String? _selectedChord;
  Map<String, dynamic>? _chordDetail;

  // タブ
  int _tabIndex = 0;

  // 録音履歴
  List<Map<String, dynamic>> _recordings = [];
  bool _isLoadingRecordings = false;

  // 練習統計
  Map<String, dynamic>? _practiceStats;
  bool _isLoadingStats = false;
  String? _statsError;

  // AI分析
  Map<String, dynamic>? _aiAnalysis;
  bool _isLoadingAI = false;

  // X投稿
  bool _isPostingToX = false;

  // 録音ファイル (共有・保存用)
  static const String _recordingsBucket = 'guitar-recordings';
  Uint8List? _shareableAudioBytes;
  String? _shareableAudioMimeType;
  String _shareableAudioExtension = 'wav';
  String _shareableAudioLabel = 'WAV';
  Uint8List? _masteredWavBytes;
  bool _isSharingFile = false;
  final Map<String, String> _signedPlaybackUrls = {};
  String? _sharedRecordingId;
  Map<String, dynamic>? _sharedRecording;
  bool _isLoadingSharedRecording = false;
  String? _sharedRecordingError;

  @override
  void initState() {
    super.initState();
    _sharedRecordingId = _extractSharedRecordingId();
    if (_sharedRecordingId != null) {
      unawaited(_fetchSharedRecording(_sharedRecordingId!));
    }
    _fetchStudioData();
    _fetchRecordings();
    _fetchPracticeStats();
    _fetchAIAnalysis();
  }

  @override
  void dispose() {
    _stopMetronome();
    _recordingTimer?.cancel();
    _mediaRecorder?.stop();
    _mediaStream?.getTracks().toDart.forEach((t) => t.stop());
    if (_audioUrl != null) {
      web.URL.revokeObjectURL(_audioUrl!);
    }
    _titleController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  /// Supabase SDK が String を返す場合もあるため安全にMapに変換
  Map<String, dynamic>? _parseResponse(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, dynamic>) return parsed;
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      } catch (_) {}
    }
    return null;
  }

  String _preferredRecorderMimeType() {
    const candidates = <String>[
      'audio/mp4;codecs=mp4a.40.2',
      'audio/mp4',
      'audio/mpeg',
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
    ];
    for (final candidate in candidates) {
      if (web.MediaRecorder.isTypeSupported(candidate)) {
        return candidate;
      }
    }
    return '';
  }

  bool _isShareFriendlyMime(String mimeType) {
    final normalized = mimeType.toLowerCase();
    return normalized.contains('mp4') ||
        normalized.contains('mpeg') ||
        normalized.contains('aac');
  }

  String _extensionForMime(String mimeType) {
    final normalized = mimeType.toLowerCase();
    if (normalized.contains('mpeg')) return 'mp3';
    if (normalized.contains('mp4') || normalized.contains('aac')) return 'm4a';
    if (normalized.contains('ogg')) return 'ogg';
    if (normalized.contains('webm')) return 'webm';
    return 'wav';
  }

  String _shareLabelForMime(String mimeType) {
    final extension = _extensionForMime(mimeType);
    if (extension == 'm4a') return 'M4A';
    if (extension == 'mp3') return 'MP3';
    if (extension == 'webm') return 'WebM';
    if (extension == 'ogg') return 'OGG';
    return 'WAV';
  }

  String _sanitizeFileName(String input) {
    final trimmed = input.trim();
    final safe = trimmed
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return safe.isEmpty ? 'guitar-recording' : safe;
  }

  String _buildLocalFileName(String title, String extension) {
    final safeTitle = _sanitizeFileName(title);
    return '$safeTitle.$extension';
  }

  Future<Uint8List> _blobToBytes(web.Blob blob) {
    final completer = Completer<Uint8List>();
    final reader = web.FileReader();
    reader.onload = ((web.Event _) {
      if (completer.isCompleted) return;
      final result = reader.result;
      if (result == null) {
        completer.completeError(StateError('Blob bytes are empty'));
        return;
      }
      final dataUrl = (result as JSString).toDart;
      final commaIndex = dataUrl.indexOf(',');
      if (commaIndex < 0) {
        completer.completeError(StateError('Invalid data URL'));
        return;
      }
      completer.complete(base64Decode(dataUrl.substring(commaIndex + 1)));
    }).toJS;
    reader.onerror = ((web.Event _) {
      if (completer.isCompleted) return;
      completer.completeError(
        StateError(reader.error?.message ?? 'Failed to read audio blob'),
      );
    }).toJS;
    reader.readAsDataURL(blob);
    return completer.future;
  }

  List<Float32List> _masterChannels(List<Float32List> channels) {
    double peak = 0.0;
    for (final channel in channels) {
      for (final sample in channel) {
        final absValue = sample.abs();
        if (absValue > peak) {
          peak = absValue;
        }
      }
    }

    final gain = peak > 0 ? math.min(2.4, 0.98 / peak) : 1.0;
    return channels.map((channel) {
      final mastered = Float32List(channel.length);
      double previousInput = 0.0;
      double previousOutput = 0.0;
      for (int index = 0; index < channel.length; index++) {
        final input = channel[index];
        final highPassed = input - previousInput + (0.995 * previousOutput);
        previousInput = input;
        previousOutput = highPassed;
        final arg = highPassed * gain * 1.08;
        final e2 = math.exp(2 * arg);
        final limited = (e2 - 1) / (e2 + 1);
        mastered[index] = limited.clamp(-1.0, 1.0).toDouble();
      }
      return mastered;
    }).toList();
  }

  Future<String?> _resolveRecordingPlaybackUrl(
    Map<String, dynamic> recording,
  ) async {
    final filePath = recording['filePath']?.toString() ?? '';
    if (filePath.isEmpty) {
      return recording['playbackUrl']?.toString();
    }
    final cached = _signedPlaybackUrls[filePath];
    if (cached != null && cached.isNotEmpty) return cached;
    final signedUrl = await _supabase.storage
        .from(_recordingsBucket)
        .createSignedUrl(filePath, 60 * 30);
    _signedPlaybackUrls[filePath] = signedUrl;
    return signedUrl;
  }

  Future<void> _playSavedRecording(Map<String, dynamic> recording) async {
    final url = await _resolveRecordingPlaybackUrl(recording);
    if (url == null || url.isEmpty) return;
    final audio = web.HTMLAudioElement()..src = url;
    audio.play();
    final recordingId = recording['recordingId']?.toString() ?? '';
    if (recordingId.isNotEmpty) {
      unawaited(
        _supabase.functions.invoke(
          'guitar-recording-studio',
          body: {'action': 'increment_play', 'recordingId': recordingId},
        ),
      );
    }
  }

  Future<void> _downloadSavedRecording(Map<String, dynamic> recording) async {
    final url = await _resolveRecordingPlaybackUrl(recording);
    if (url == null || url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('保存済み音声の URL を取得できませんでした'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final title = recording['title']?.toString().trim().isNotEmpty == true
        ? recording['title'].toString().trim()
        : 'guitar-recording';
    final extension =
        recording['exportFormat']?.toString().trim().isNotEmpty == true
            ? recording['exportFormat'].toString().trim()
            : 'wav';
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = _buildLocalFileName(title, extension)
      ..style.display = 'none';
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
  }

  Future<String> _uploadCurrentRecordingFile(
    String userId,
    String title,
  ) async {
    final bytes = _shareableAudioBytes;
    final mimeType = _shareableAudioMimeType;
    if (bytes == null || mimeType == null) {
      throw StateError('録音データがありません');
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = _shareableAudioExtension;
    final path = '$userId/${timestamp}_${_sanitizeFileName(title)}.$extension';
    await _supabase.storage.from(_recordingsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: mimeType),
        );
    return path;
  }

  Future<void> _shareCurrentRecording() async {
    if (_shareableAudioBytes == null || _shareableAudioMimeType == null) {
      return;
    }
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : 'guitar-recording';
    final fileName = _buildLocalFileName(title, _shareableAudioExtension);
    final publicUrl =
        _isPublic && _savedRecordingId != null
            ? 'https://my-web-app-b67f4.web.app/#/guitar-recording-studio?share=${_savedRecordingId!}'
            : null;
    setState(() => _isSharingFile = true);
    try {
      final blob = web.Blob(
        [_shareableAudioBytes!.buffer.toJS].toJS,
        web.BlobPropertyBag(type: _shareableAudioMimeType!),
      );
      final blobUrl = web.URL.createObjectURL(blob);
      final anchor = web.HTMLAnchorElement()
        ..href = blobUrl
        ..download = fileName
        ..style.display = 'none';
      web.document.body?.appendChild(anchor);
      anchor.click();
      anchor.remove();
      web.URL.revokeObjectURL(blobUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$fileName をダウンロードしました${publicUrl != null ? '\n共有URL: $publicUrl' : ''}',
          ),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ダウンロードに失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharingFile = false);
    }
  }

  String? _extractSharedRecordingId() {
    final fragment = Uri.base.fragment;
    final queryIndex = fragment.indexOf('?');
    if (queryIndex < 0) return null;
    final query = fragment.substring(queryIndex + 1);
    final params = Uri.splitQueryString(query);
    final shareId = params['share']?.trim();
    return shareId == null || shareId.isEmpty ? null : shareId;
  }

  Future<void> _fetchSharedRecording(String recordingId) async {
    setState(() {
      _isLoadingSharedRecording = true;
      _sharedRecordingError = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'guitar-recording-studio',
        queryParameters: {
          'action': 'public_recording',
          'recordingId': recordingId,
        },
      );
      final data = _parseResponse(res.data);
      final recording = data?['recording'];
      if (mounted) {
        setState(() {
          _sharedRecording = recording is Map<String, dynamic>
              ? recording
              : recording is Map
                  ? Map<String, dynamic>.from(recording)
                  : null;
          _isLoadingSharedRecording = false;
          _sharedRecordingError =
              _sharedRecording == null ? '公開録音が見つかりませんでした' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sharedRecording = null;
          _isLoadingSharedRecording = false;
          _sharedRecordingError = '$e';
        });
      }
    }
  }

  Future<void> _playSharedRecording() async {
    final url = _sharedRecording?['playbackUrl']?.toString() ?? '';
    if (url.isEmpty) return;
    final audio = web.HTMLAudioElement()..src = url;
    audio.play();
    final recordingId = _sharedRecording?['recordingId']?.toString() ?? '';
    if (recordingId.isNotEmpty) {
      unawaited(
        _supabase.functions.invoke(
          'guitar-recording-studio',
          body: {'action': 'increment_play', 'recordingId': recordingId},
        ),
      );
    }
  }

  void _downloadSharedRecording() {
    final url = _sharedRecording?['playbackUrl']?.toString() ?? '';
    if (url.isEmpty) return;
    final title = _sharedRecording?['title']?.toString().trim().isNotEmpty == true
        ? _sharedRecording!['title'].toString().trim()
        : 'guitar-recording';
    final extension =
        _sharedRecording?['exportFormat']?.toString().trim().isNotEmpty == true
            ? _sharedRecording!['exportFormat'].toString().trim()
            : 'wav';
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = _buildLocalFileName(title, extension)
      ..style.display = 'none';
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
  }

  Future<void> _fetchStudioData() async {
    setState(() => _isLoadingStudio = true);
    try {
      final res = await _supabase.functions.invoke(
        'guitar-recording-studio',
        queryParameters: {'action': 'dashboard'},
      );
      final data = _parseResponse(res.data);
      if (data != null) {
        final rawPresets = data['presets'];
        final rawChords = data['chordLibrary'];
        final rawTunings = data['tunings'];
        setState(() {
          if (rawPresets is List) {
            _presets = rawPresets
                .map((p) => (p as Map<String, dynamic>)['id'] as String)
                .toList();
          }
          if (rawChords is List) {
            _chordNames = rawChords.map((c) => c as String).toList();
          }
          if (rawTunings is List) {
            _tuningNames = rawTunings.map((t) => t as String).toList();
          }
        });
      }
    } catch (_) {
      setState(() {
        _presets = [
          'acoustic_fingerpicking',
          'rock_rhythm',
          'blues_lead',
          'jazz_clean',
          'metal_heavy',
          'classical',
          'funk_rhythm',
          'ambient',
        ];
        _chordNames = ['C', 'D', 'E', 'F', 'G', 'A', 'B', 'Am', 'Em', 'Dm'];
        _tuningNames = ['standard', 'drop_d', 'open_g', 'open_d', 'dadgad'];
      });
    } finally {
      if (mounted) setState(() => _isLoadingStudio = false);
    }
  }

  Future<void> _fetchRecordings() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _isLoadingRecordings = true);
    try {
      final res = await _supabase.functions.invoke(
        'guitar-recording-studio',
        queryParameters: {'action': 'recordings', 'userId': user.id},
      );
      final data = _parseResponse(res.data);
      if (data != null) {
        final error = data['error']?.toString();
        if (error != null && error.isNotEmpty) {
          debugPrint('fetchRecordings error from server: $error');
        }
        final list = data['recordings'];
        if (list is List) {
          if (mounted) {
            setState(() {
              _recordings = list
                  .map((r) => r is Map<String, dynamic> ? r : Map<String, dynamic>.from(r as Map))
                  .toList();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('fetchRecordings exception: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRecordings = false);
    }
  }

  Future<void> _fetchPracticeStats() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoadingStats = false;
        _statsError = 'ログインが必要です';
      });
      return;
    }
    setState(() {
      _isLoadingStats = true;
      _statsError = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'guitar-recording-studio',
        queryParameters: {'action': 'practice_stats', 'userId': user.id},
      );
      final data = _parseResponse(res.data);
      if (mounted) {
        setState(() {
          _practiceStats = data ?? {};
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _practiceStats = {};
          _isLoadingStats = false;
          _statsError = '$e';
        });
      }
    }
  }

  Future<void> _postToX(String title, String recordingId) async {
    setState(() => _isPostingToX = true);
    try {
      final shareUrl =
          recordingId.isNotEmpty && recordingId != 'unknown'
              ? 'https://my-web-app-b67f4.web.app/#/guitar-recording-studio?share=$recordingId'
              : null;
      final message = [
        '🎸 ギター演奏を録音しました',
        '「$title」',
        if (shareUrl != null) shareUrl,
        '#ギター #録音 #buildinpublic',
      ].join('\n');
      final intentUrl =
          'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(message)}';
      web.window.open(intentUrl, '_blank');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('X の投稿画面を開きました'),
          backgroundColor: Color(0xFF1DA1F2),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('X 投稿画面を開けませんでした: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPostingToX = false);
    }
  }

  Future<void> _fetchAIAnalysis() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _isLoadingAI = true);
    try {
      final res = await _supabase.functions.invoke(
        'guitar-recording-studio',
        body: {'action': 'ai_analyze', 'userId': user.id, 'analysisType': 'practice_menu'},
      );
      final data = _parseResponse(res.data);
      if (data != null) {
        setState(() => _aiAnalysis = data);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingAI = false);
  }

  Future<void> _deleteRecording(String recordingId) async {
    try {
      await _supabase.functions.invoke(
        'guitar-recording-studio',
        body: {'action': 'delete_recording', 'recordingId': recordingId},
      );
      await _fetchRecordings();
      await _fetchPracticeStats();
      await _fetchAIAnalysis();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _fetchChordDetail(String chordName) async {
    setState(() => _chordDetail = null);
    try {
      final res = await _supabase.functions.invoke(
        'guitar-recording-studio',
        queryParameters: {'action': 'chord', 'name': chordName},
      );
      final data = _parseResponse(res.data);
      if (data != null) {
        setState(() => _chordDetail = data);
      }
    } catch (_) {}
  }

  // ─── 録音 ───────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_audioUrl != null) {
      web.URL.revokeObjectURL(_audioUrl!);
    }
    setState(() {
      _errorMessage = null;
      _audioUrl = null;
      _shareableAudioBytes = null;
      _shareableAudioMimeType = null;
      _shareableAudioExtension = 'wav';
      _shareableAudioLabel = 'WAV';
      _masteredWavBytes = null;
      _savedSuccessfully = false;
      _savedRecordingId = null;
    });
    try {
      final mediaDevices = web.window.navigator.mediaDevices;

      // 高音質設定: エコーキャンセル・ノイズ抑制・自動ゲインをOFFにし、
      // 楽器の生音をそのまま録音する
      final audioConstraints = {
        'echoCancellation': false,
        'noiseSuppression': false,
        'autoGainControl': false,
        'sampleRate': 48000,
        'channelCount': 2,
      }.jsify()!;
      final constraints = web.MediaStreamConstraints(
        audio: audioConstraints,
      );
      final stream = await mediaDevices.getUserMedia(constraints).toDart;
      _mediaStream = stream;
      _audioChunks.clear();

      // MediaRecorder: まず audio/webm;codecs=opus を試し、
      // 非対応 (iOS Safari等) なら audio/mp4 → デフォルトにフォールバック
      String mimeType = _preferredRecorderMimeType();
      if (!web.MediaRecorder.isTypeSupported(mimeType)) {
        mimeType = 'audio/mp4';
        if (!web.MediaRecorder.isTypeSupported(mimeType)) {
          mimeType = ''; // ブラウザデフォルト
        }
      }
      final options = mimeType.isNotEmpty
          ? web.MediaRecorderOptions(
              mimeType: mimeType,
              audioBitsPerSecond: 320000,
            )
          : web.MediaRecorderOptions(audioBitsPerSecond: 320000);
      _mediaRecorder = web.MediaRecorder(stream, options);

      _mediaRecorder!.addEventListener(
        'dataavailable',
        (web.Event event) {
          final blobEvent = event as web.BlobEvent;
          final data = blobEvent.data;
          if (data.size > 0) {
            _audioChunks.add(data as JSObject);
          }
        }.toJS,
      );

      _mediaRecorder!.addEventListener(
        'stop',
        (web.Event _) {
          unawaited(_buildAudioBlob());
        }.toJS,
      );

      _mediaRecorder!.start(250);

      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordingDuration = Duration.zero;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_isRecording && !_isPaused) {
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
          });
        }
      });
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      String msg;
      if (errStr.contains('notallowed') ||
          errStr.contains('permission') ||
          errStr.contains('denied')) {
        msg = 'マイクへのアクセスが拒否されました。\n\n'
            '📱 スマホ: 設定 → アプリ → ブラウザ → マイク → 許可\n'
            '🖥 PC (Chrome): アドレスバー左の🔒→マイク→許可\n'
            '🖥 PC (Firefox): アドレスバー左のカメラアイコン→許可\n\n'
            'ページを再読み込み後、もう一度お試しください。';
      } else if (errStr.contains('notfound') ||
          errStr.contains('devicenotfound')) {
        msg = 'マイクが見つかりません。\nマイクが接続されているか確認してください。';
      } else if (errStr.contains('notsupported') ||
          errStr.contains('insecure')) {
        msg = 'このブラウザでは録音がサポートされていません。\nChrome または Safari をお使いください。\nまた https:// でアクセスしていることを確認してください。';
      } else {
        msg = 'マイクへのアクセスに失敗しました。\nブラウザの設定でマイクが許可されているか確認してください。';
      }
      setState(() => _errorMessage = msg);
    }
  }

  /// 録音チャンクからBlobを作成し、WAVに変換する
  Future<void> _buildAudioBlob() async {
    final blobParts = _audioChunks.toJS;
    final recorderMime = _mediaRecorder?.mimeType ?? 'audio/webm';
    final blobInit = web.BlobPropertyBag(type: recorderMime);
    final rawBlob = web.Blob(blobParts, blobInit);

    // WebM/OGG → WAV に変換 (iPhone互換性のため)
    final sourceBytes = await _blobToBytes(rawBlob);
    await _convertToWav(
      rawBlob,
      sourceBytes: sourceBytes,
      sourceMimeType: recorderMime,
    );
  }

  /// Web Audio API を使って任意の音声BlobをWAVに変換
  Future<void> _convertToWav(
    web.Blob sourceBlob, {
    required Uint8List sourceBytes,
    required String sourceMimeType,
  }) async {
    try {
      final arrayBuf = await sourceBlob.arrayBuffer().toDart;
      final audioCtx = web.AudioContext();
      final audioBuf = await audioCtx.decodeAudioData(arrayBuf).toDart;

      // PCM データ取得
      final numChannels = audioBuf.numberOfChannels;
      final sampleRate = audioBuf.sampleRate.toInt();
      final channels = <Float32List>[];
      for (int ch = 0; ch < numChannels; ch++) {
        channels.add(audioBuf.getChannelData(ch).toDart);
      }

      // WAV ヘッダ + データ構築
      final wavBytes =
          _encodeWav(_masterChannels(channels), sampleRate, numChannels);
      final wavBlob = web.Blob(
        [wavBytes.buffer.toJS].toJS,
        web.BlobPropertyBag(type: 'audio/wav'),
      );
      final url = web.URL.createObjectURL(wavBlob);
      final useSourceAsPrimary = _isShareFriendlyMime(sourceMimeType);
      if (mounted) {
        setState(() {
          _audioUrl = url;
          _masteredWavBytes = wavBytes;
          _shareableAudioBytes = useSourceAsPrimary ? sourceBytes : wavBytes;
          _shareableAudioMimeType =
              useSourceAsPrimary ? sourceMimeType : 'audio/wav';
          _shareableAudioExtension = useSourceAsPrimary
              ? _extensionForMime(sourceMimeType)
              : 'wav';
          _shareableAudioLabel = useSourceAsPrimary
              ? _shareLabelForMime(sourceMimeType)
              : 'WAV';
        });
      }
      audioCtx.close();
    } catch (_) {
      // WAV変換に失敗した場合は元の形式でフォールバック
      final url = web.URL.createObjectURL(sourceBlob);
      if (mounted) {
        setState(() {
          _audioUrl = url;
          _masteredWavBytes = null;
          _shareableAudioBytes = sourceBytes;
          _shareableAudioMimeType = sourceMimeType;
          _shareableAudioExtension = _extensionForMime(sourceMimeType);
          _shareableAudioLabel = _shareLabelForMime(sourceMimeType);
        });
      }
    }
  }

  /// Float32 PCM → 16-bit WAV バイト列にエンコード
  Uint8List _encodeWav(List<Float32List> channels, int sampleRate, int numChannels) {
    final length = channels[0].length;
    final byteRate = sampleRate * numChannels * 2; // 16-bit = 2 bytes
    final dataSize = length * numChannels * 2;
    final buffer = ByteData(44 + dataSize);

    // RIFF header
    buffer.setUint8(0, 0x52); // R
    buffer.setUint8(1, 0x49); // I
    buffer.setUint8(2, 0x46); // F
    buffer.setUint8(3, 0x46); // F
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    buffer.setUint8(8, 0x57); // W
    buffer.setUint8(9, 0x41); // A
    buffer.setUint8(10, 0x56); // V
    buffer.setUint8(11, 0x45); // E

    // fmt chunk
    buffer.setUint8(12, 0x66); // f
    buffer.setUint8(13, 0x6D); // m
    buffer.setUint8(14, 0x74); // t
    buffer.setUint8(15, 0x20); // (space)
    buffer.setUint32(16, 16, Endian.little); // chunk size
    buffer.setUint16(20, 1, Endian.little); // PCM format
    buffer.setUint16(22, numChannels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, numChannels * 2, Endian.little); // block align
    buffer.setUint16(34, 16, Endian.little); // bits per sample

    // data chunk
    buffer.setUint8(36, 0x64); // d
    buffer.setUint8(37, 0x61); // a
    buffer.setUint8(38, 0x74); // t
    buffer.setUint8(39, 0x61); // a
    buffer.setUint32(40, dataSize, Endian.little);

    // Interleave PCM samples
    int offset = 44;
    for (int i = 0; i < length; i++) {
      for (int ch = 0; ch < numChannels; ch++) {
        double sample = channels[ch][i];
        // Clamp to [-1.0, 1.0]
        if (sample > 1.0) sample = 1.0;
        if (sample < -1.0) sample = -1.0;
        final intSample = (sample * 32767).round();
        buffer.setInt16(offset, intSample, Endian.little);
        offset += 2;
      }
    }

    return buffer.buffer.asUint8List();
  }

  void _pauseRecording() {
    final state = _mediaRecorder?.state;
    if (state == 'recording') {
      _mediaRecorder!.pause();
      setState(() => _isPaused = true);
    } else if (state == 'paused') {
      _mediaRecorder!.resume();
      setState(() => _isPaused = false);
    }
  }

  void _stopRecording() {
    _recordingTimer?.cancel();
    _mediaRecorder?.stop();
    _mediaStream?.getTracks().toDart.forEach((t) => t.stop());
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });
  }

  void _playRecording() {
    if (_audioUrl == null) return;
    final audio = web.HTMLAudioElement()..src = _audioUrl!;
    audio.play();
  }

  void _discardRecording() {
    if (_audioUrl != null) web.URL.revokeObjectURL(_audioUrl!);
    setState(() {
      _audioUrl = null;
      _audioChunks.clear();
      _shareableAudioBytes = null;
      _shareableAudioMimeType = null;
      _shareableAudioExtension = 'wav';
      _shareableAudioLabel = 'WAV';
      _masteredWavBytes = null;
      _recordingDuration = Duration.zero;
      _savedSuccessfully = false;
      _savedRecordingId = null;
    });
  }

  void _downloadRecording() {
    final bytes = _shareableAudioBytes;
    final mimeType = _shareableAudioMimeType;
    if (bytes == null || mimeType == null) return;
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : 'guitar-recording';
    final fileName = _buildLocalFileName(title, _shareableAudioExtension);
    final blob = web.Blob(
      [bytes.buffer.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..style.display = 'none';
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }

  void _downloadMasteredWav() {
    final bytes = _masteredWavBytes;
    if (bytes == null) return;
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : 'guitar-recording';
    final blob = web.Blob(
      [bytes.buffer.toJS].toJS,
      web.BlobPropertyBag(type: 'audio/wav'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = _buildLocalFileName(title, 'wav')
      ..style.display = 'none';
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }

  Future<void> _saveRecording() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _errorMessage = 'ログインが必要です');
      return;
    }
    final title = _titleController.text.trim();
    if (_shareableAudioBytes == null || _shareableAudioMimeType == null) {
      setState(() => _errorMessage = '保存する録音データがありません');
      return;
    }
    if (title.isEmpty) {
      setState(() => _errorMessage = 'タイトルを入力してください');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    String? uploadedPath;
    try {
      uploadedPath = await _uploadCurrentRecordingFile(user.id, title);
      final res = await _supabase.functions.invoke(
        'guitar-recording-studio',
        body: {
          'action': 'save_recording',
          'title': title,
          'durationSeconds': _recordingDuration.inSeconds,
          'preset': _selectedPreset,
          'tuning': _selectedTuning,
          'bpm': _bpm,
          'tracks': 1,
          'filePath': uploadedPath,
          'fileMimeType': _shareableAudioMimeType,
          'fileSizeBytes': _shareableAudioBytes!.length,
          'exportFormat': _shareableAudioExtension,
          'tags': _tagsController.text.trim().isEmpty
              ? <String>[]
              : _tagsController.text
                  .split(',')
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .toList(),
          'isPublic': _isPublic,
        },
      );
      // レスポンスから recording ID を取得 (共有URL生成用)
      String? recId;
      try {
        final data = res.data;
        if (data is Map) {
          recId = data['recordingId']?.toString() ??
              data['id']?.toString();
        }
      } catch (_) {}
      setState(() {
        _savedSuccessfully = true;
        _savedRecordingId = recId;
      });
      await _fetchRecordings();
      await _fetchPracticeStats();
      await _fetchAIAnalysis();
    } catch (e) {
      if (uploadedPath != null) {
        unawaited(
          _supabase.storage.from(_recordingsBucket).remove([uploadedPath]),
        );
      }
      setState(() => _errorMessage = '保存に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── メトロノーム ────────────────────────────────────────────

  void _toggleMetronome() {
    if (_isMetronomeActive) {
      _stopMetronome();
    } else {
      _startMetronome();
    }
  }

  void _startMetronome() {
    _beatCount = 0;
    final intervalMs = (60000 / _bpm).round();
    _metronomeTimer =
        Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      final isAccent = _beatCount % _beatsPerMeasure == 0;
      setState(() {
        _beatCount++;
      });
      // Web Audio API でビープ音
      try {
        final ctx = web.AudioContext();
        final osc = ctx.createOscillator();
        final gain = ctx.createGain();
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.frequency.value = isAccent ? 880.0 : 440.0;
        gain.gain.value = 0.3;
        final now = ctx.currentTime;
        osc.start(now);
        osc.stop(now + 0.05);
      } catch (_) {}
    });
    setState(() => _isMetronomeActive = true);
  }

  void _stopMetronome() {
    _metronomeTimer?.cancel();
    setState(() {
      _isMetronomeActive = false;
      _beatCount = 0;
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ─── UI ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_sharedRecordingId != null) {
      return _buildSharedRecordingScaffold();
    }
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.music_note, color: Color(0xFFE94560)),
            SizedBox(width: 8),
            Text(
              'ギタースタジオ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              _tabButton('録音', 0),
              _tabButton('コード', 1),
              _tabButton('テンポ', 2),
              _tabButton('履歴', 3),
              _tabButton('統計', 4),
              _tabButton('AI', 5),
            ],
          ),
        ),
      ),
      body: _buildTabContent(),
    );
  }

  Widget _buildSharedRecordingScaffold() {
    final recording = _sharedRecording;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        title: const Text('公開ギター録音'),
      ),
      body: _isLoadingSharedRecording
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE94560)),
            )
          : recording == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.music_off, size: 56, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text(
                        _sharedRecordingError ?? '公開録音を読み込めませんでした',
                        style: const TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        recording['title']?.toString() ?? 'guitar-recording',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${recording['durationDisplay'] ?? recording['durationSeconds'] ?? '-'} / ${recording['preset'] ?? '-'} / ${recording['exportFormat'] ?? 'wav'}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16213E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.graphic_eq,
                              color: Color(0xFFE94560),
                              size: 56,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _playSharedRecording,
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('再生'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4CAF50),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: _downloadSharedRecording,
                                  icon: const Icon(Icons.download_outlined),
                                  label: const Text('保存'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                    side: const BorderSide(color: Colors.white24),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _tabButton(String label, int index) {
    final isSelected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tabIndex = index);
          if (index == 3) _fetchRecordings();
          if (index == 4) _fetchPracticeStats();
          if (index == 5 && _aiAnalysis == null) _fetchAIAnalysis();
        },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? const Color(0xFFE94560)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFFE94560)
                  : Colors.white60,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tabIndex) {
      case 0:
        return _buildRecordingTab();
      case 1:
        return _buildChordTab();
      case 2:
        return _buildMetronomeTab();
      case 3:
        return _buildHistoryTab();
      case 4:
        return _buildStatsTab();
      case 5:
        return _buildAITab();
      default:
        return _buildRecordingTab();
    }
  }

  // ── 録音タブ ──────────────────────────────────────────────────

  Widget _buildRecordingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_errorMessage != null) _errorCard(_errorMessage!),
          _presetSelector(),
          const SizedBox(height: 12),
          _inlineMetronomeToggle(),
          const SizedBox(height: 12),
          _recorderWidget(),
          if (_audioUrl != null) ...[
            const SizedBox(height: 16),
            _saveWidget(),
          ],
        ],
      ),
    );
  }

  Widget _errorCard(String msg) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(msg, style: const TextStyle(color: Colors.white70)),
    );
  }

  Widget _presetSelector() {
    if (_isLoadingStudio) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE94560)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ジャンル / プリセット',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _presets.map((p) {
            final isSelected = p == _selectedPreset;
            return FilterChip(
              label: Text(
                _presetLabel(p),
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedPreset = p),
              backgroundColor: const Color(0xFF16213E),
              selectedColor: const Color(0xFFE94560),
              checkmarkColor: Colors.white,
              side: BorderSide(
                color:
                    isSelected ? const Color(0xFFE94560) : Colors.white24,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text(
              'チューニング: ',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _selectedTuning,
              dropdownColor: const Color(0xFF16213E),
              style: const TextStyle(color: Colors.white),
              underline: const SizedBox(),
              items: _tuningNames
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedTuning = v);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _recorderWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              _isRecording ? const Color(0xFFE94560) : Colors.white12,
        ),
        boxShadow: _isRecording
            ? [
                BoxShadow(
                  color:
                      const Color(0xFFE94560).withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Text(
            _formatDuration(_recordingDuration),
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: _isRecording
                  ? const Color(0xFFE94560)
                  : Colors.white38,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (_isRecording) ...[
            const SizedBox(height: 8),
            _buildWaveformIndicator(),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isRecording && _audioUrl == null) _buildRecordButton(),
              if (_isRecording) ...[
                _buildPauseButton(),
                const SizedBox(width: 24),
                _buildStopButton(),
              ],
              if (!_isRecording && _audioUrl != null) ...[
                _buildPlayButton(),
                const SizedBox(width: 12),
                _buildShareButton(),
                const SizedBox(width: 12),
                _buildDownloadButton(),
                const SizedBox(width: 12),
                _buildDiscardButton(),
              ],
            ],
          ),
          if (!_isRecording && _audioUrl == null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'ボタンを押して録音開始',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          if (!_isRecording && _audioUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  Text(
                    '録音完了: ${_formatDuration(_recordingDuration)}',
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '48kHz preview WAV / share: $_shareableAudioLabel / iPhone compatible',
                    style: const TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWaveformIndicator() {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          12,
          (i) => AnimatedContainer(
            duration: Duration(milliseconds: 100 + i * 30),
            width: 4,
            height: _isRecording && !_isPaused
                ? (4.0 + (i % 5) * 4.0)
                : 4.0,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE94560),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _startRecording,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFE94560),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE94560).withValues(alpha: 0.5),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.mic, color: Colors.white, size: 36),
      ),
    );
  }

  Widget _buildPauseButton() {
    return GestureDetector(
      onTap: _pauseRecording,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white38, width: 2),
        ),
        child: Icon(
          _isPaused ? Icons.play_arrow : Icons.pause,
          color: Colors.white70,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildStopButton() {
    return GestureDetector(
      onTap: _stopRecording,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFE94560).withValues(alpha: 0.8),
        ),
        child: const Icon(Icons.stop, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: _playRecording,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF4CAF50),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
              blurRadius: 12,
            ),
          ],
        ),
        child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildShareButton() {
    return GestureDetector(
      onTap: _isSharingFile ? null : _shareCurrentRecording,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isSharingFile
              ? const Color(0xFF0F3460).withValues(alpha: 0.5)
              : const Color(0xFF1DA1F2),
        ),
        child: _isSharingFile
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.ios_share,
                color: Colors.white,
                size: 22,
              ),
      ),
    );
  }

  Widget _buildDownloadButton() {
    return GestureDetector(
      onTap: _downloadRecording,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF0F3460),
        ),
        child: const Icon(
          Icons.download_outlined,
          color: Colors.white70,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildDiscardButton() {
    return GestureDetector(
      onTap: _discardRecording,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white54,
          size: 22,
        ),
      ),
    );
  }

  Widget _saveWidget() {
    if (_savedSuccessfully) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4CAF50)),
        ),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
                SizedBox(width: 8),
                Text(
                  '保存しました！',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSharingFile ? null : _shareCurrentRecording,
                    icon: _isSharingFile
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.ios_share, size: 16),
                    label: Text('ファイル共有 ($_shareableAudioLabel)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DA1F2),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                if (_masteredWavBytes != null &&
                    _shareableAudioExtension.toLowerCase() != 'wav') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _downloadMasteredWav,
                      icon: const Icon(Icons.graphic_eq, size: 16),
                      label: const Text('WAV保存'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (_isPublic) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final id = _savedRecordingId ?? 'unknown';
                        final url =
                            'https://my-web-app-b67f4.web.app/#/guitar-recording-studio?share=$id';
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('共有リンクをコピーしました！'),
                            backgroundColor: Color(0xFF4CAF50),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('共有リンクをコピー'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4CAF50),
                        side: const BorderSide(color: Color(0xFF4CAF50)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isPostingToX
                          ? null
                          : () {
                              final title = _titleController.text.trim().isNotEmpty
                                  ? _titleController.text.trim()
                                  : '新しい録音';
                              _postToX(title, _savedRecordingId ?? 'unknown');
                            },
                      icon: _isPostingToX
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Xに投稿'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DA1F2),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '録音を保存',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'タイトルを入力...',
              hintStyle: TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Color(0xFF0F3460),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFE94560)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tagsController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'タグ (カンマ区切り: rock, practice, solo)',
              hintStyle: TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Color(0xFF0F3460),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFE94560)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('公開する', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(width: 8),
              Switch(
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
                activeThumbColor: const Color(0xFFE94560),
              ),
              const Spacer(),
              Text(
                _isPublic ? '他ユーザーに公開' : '自分だけ',
                style: TextStyle(
                  color: _isPublic ? const Color(0xFFE94560) : Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveRecording,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? '保存中...' : '保存する'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE94560),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineMetronomeToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggleMetronome,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isMetronomeActive
                    ? const Color(0xFFE94560)
                    : Colors.white12,
              ),
              child: Icon(
                _isMetronomeActive ? Icons.music_off : Icons.music_note,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'メトロノーム $_bpm BPM',
            style: TextStyle(
              color: _isMetronomeActive ? const Color(0xFFE94560) : Colors.white54,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 100,
            child: Slider(
              value: _bpm.toDouble(),
              min: 40,
              max: 240,
              activeColor: const Color(0xFFE94560),
              inactiveColor: Colors.white12,
              onChanged: (v) {
                setState(() => _bpm = v.round());
                if (_isMetronomeActive) {
                  _stopMetronome();
                  _startMetronome();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── コード辞典タブ ─────────────────────────────────────────────

  Widget _buildChordTab() {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: ListView.builder(
            itemCount: _chordNames.length,
            itemBuilder: (context, index) {
              final chord = _chordNames[index];
              final isSelected = chord == _selectedChord;
              return ListTile(
                dense: true,
                title: Text(
                  chord,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFFE94560)
                        : Colors.white70,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                selectedTileColor:
                    const Color(0xFFE94560).withValues(alpha: 0.1),
                onTap: () {
                  setState(() => _selectedChord = chord);
                  _fetchChordDetail(chord);
                },
              );
            },
          ),
        ),
        const VerticalDivider(color: Colors.white12, width: 1),
        Expanded(
          child: _selectedChord == null
              ? const Center(
                  child: Text(
                    'コードを選択',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : _buildChordDetail(),
        ),
      ],
    );
  }

  Widget _buildChordDetail() {
    if (_chordDetail == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE94560)),
      );
    }
    final frets = _chordDetail!['frets'] as List?;
    final fingers = _chordDetail!['fingers'] as String?;
    final stringNames = _chordDetail!['stringNames'] as List?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_selectedChord コード',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          if (frets != null && stringNames != null)
            _buildChordDiagram(
              frets.map((f) => f as int).toList(),
              stringNames.map((s) => s as String).toList(),
            ),
          if (fingers != null) ...[
            const SizedBox(height: 16),
            Text(
              'フィンガリング: $fingers',
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '凡例: x=ミュート, 0=開放弦, 数字=フレット',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChordDiagram(List<int> frets, List<String> strings) {
    return SizedBox(
      width: 280,
      height: 240,
      child: CustomPaint(
        painter: _ChordDiagramPainter(frets: frets, strings: strings),
      ),
    );
  }

  // ── メトロノームタブ ────────────────────────────────────────────

  Widget _buildMetronomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SizedBox(
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _beatsPerMeasure,
                (i) {
                  final beat = _beatCount % _beatsPerMeasure;
                  final isActive = _isMetronomeActive && i == beat - 1;
                  final isAccent = i == 0;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    width: isActive ? 60 : 50,
                    height: isActive ? 60 : 50,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? (isAccent
                              ? const Color(0xFFE94560)
                              : const Color(0xFF0F3460))
                          : Colors.white12,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white38,
                          fontWeight: FontWeight.bold,
                          fontSize: isActive ? 18 : 16,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '$_bpm BPM',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Slider(
            value: _bpm.toDouble(),
            min: 30,
            max: 300,
            divisions: 270,
            activeColor: const Color(0xFFE94560),
            inactiveColor: Colors.white24,
            label: '$_bpm',
            onChanged: (v) {
              setState(() => _bpm = v.round());
              if (_isMetronomeActive) {
                _stopMetronome();
                _startMetronome();
              }
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _bpmPresetButton(60),
              _bpmPresetButton(80),
              _bpmPresetButton(100),
              _bpmPresetButton(120),
              _bpmPresetButton(140),
              _bpmPresetButton(160),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '拍子: ',
                style: TextStyle(color: Colors.white70),
              ),
              ...[2, 3, 4, 6].map(
                (b) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('$b/4'),
                    selected: _beatsPerMeasure == b,
                    onSelected: (_) {
                      setState(() => _beatsPerMeasure = b);
                      if (_isMetronomeActive) {
                        _stopMetronome();
                        _startMetronome();
                      }
                    },
                    selectedColor: const Color(0xFFE94560),
                    backgroundColor: const Color(0xFF16213E),
                    labelStyle: TextStyle(
                      color: _beatsPerMeasure == b
                          ? Colors.white
                          : Colors.white60,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _toggleMetronome,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isMetronomeActive
                    ? const Color(0xFFE94560)
                    : const Color(0xFF16213E),
                border: Border.all(
                  color: const Color(0xFFE94560),
                  width: 2,
                ),
                boxShadow: _isMetronomeActive
                    ? [
                        BoxShadow(
                          color: const Color(0xFFE94560)
                              .withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                _isMetronomeActive ? Icons.stop : Icons.play_arrow,
                color: Colors.white,
                size: 44,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bpmPresetButton(int bpm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: OutlinedButton(
        onPressed: () {
          setState(() => _bpm = bpm);
          if (_isMetronomeActive) {
            _stopMetronome();
            _startMetronome();
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: const BorderSide(color: Colors.white24),
          minimumSize: const Size(40, 30),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(fontSize: 12),
        ),
        child: Text('$bpm'),
      ),
    );
  }

  // ── 録音履歴タブ ──────────────────────────────────────────────

  Widget _buildHistoryTab() {
    if (_isLoadingRecordings) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE94560)),
      );
    }
    if (_recordings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_off, size: 64, color: Colors.white24),
            const SizedBox(height: 12),
            const Text(
              'まだ録音がありません',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              '録音タブで演奏を記録しましょう',
              style: TextStyle(color: Colors.white24, fontSize: 13),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _fetchRecordings,
              icon: const Icon(Icons.refresh),
              label: const Text('更新'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchRecordings,
      color: const Color(0xFFE94560),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _recordings.length,
        itemBuilder: (ctx, i) {
          final r = _recordings[i];
          final title = r['title'] as String? ?? '無題';
          final duration = r['durationSeconds'] as int? ?? 0;
          final preset = r['preset'] as String? ?? '';
          final createdAt =
              r['createdAt'] as String? ?? r['created_at'] as String? ?? '';
          final bpm = r['bpm'] as int? ?? 0;
          final tuning = r['tuning'] as String? ?? '';
          final isPublicRec = r['isPublic'] as bool? ?? false;
          final likes = r['likes'] as int? ?? 0;
          final plays = r['plays'] as int? ?? 0;
          final tags = r['tags'] as List? ?? [];
          final recordingId = r['recordingId'] as String? ?? '';
          final exportFormat = r['exportFormat'] as String? ?? 'wav';
          return Card(
            color: const Color(0xFF16213E),
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFE94560),
                        radius: 18,
                        child: Icon(Icons.music_note, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              '${_formatDuration(Duration(seconds: duration))} • ${_presetLabel(preset)}'
                              '${bpm > 0 ? ' • ${bpm}BPM' : ''}'
                              '${tuning.isNotEmpty ? ' • $tuning' : ''}',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (isPublicRec)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.public, color: Colors.white38, size: 16),
                        ),
                      if (likes > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite, color: Color(0xFFE94560), size: 14),
                            const SizedBox(width: 2),
                            Text('$likes', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white38, size: 20),
                        color: const Color(0xFF16213E),
                        onSelected: (value) {
                          if (value == 'delete' && recordingId.isNotEmpty) {
                            _deleteRecording(recordingId);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'delete', child: Text('削除', style: TextStyle(color: Colors.redAccent))),
                        ],
                      ),
                    ],
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: tags.map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('#$t', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ),).toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _playSavedRecording(r),
                        icon: const Icon(Icons.play_circle_fill, color: Color(0xFF4CAF50)),
                        visualDensity: VisualDensity.compact,
                        tooltip: '再生',
                      ),
                      IconButton(
                        onPressed: () => _downloadSavedRecording(r),
                        icon: const Icon(Icons.download_outlined, color: Colors.white70),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'ダウンロード',
                      ),
                      if (recordingId.isNotEmpty) ...[
                        IconButton(
                          onPressed: () => _postToX(title, recordingId),
                          icon: const Icon(Icons.open_in_new, color: Color(0xFF1DA1F2)),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Xに投稿',
                        ),
                        if (isPublicRec)
                          IconButton(
                            onPressed: () {
                              final shareUrl =
                                  'https://my-web-app-b67f4.web.app/#/guitar-recording-studio?share=$recordingId';
                              Clipboard.setData(ClipboardData(text: shareUrl));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('共有リンクをコピーしました'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.link, color: Colors.white54),
                            visualDensity: VisualDensity.compact,
                            tooltip: '共有リンク',
                          ),
                      ],
                      const Spacer(),
                      if (plays > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            '$plays plays',
                            style: const TextStyle(color: Colors.white24, fontSize: 11),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          exportFormat.toUpperCase(),
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt,
                      style: const TextStyle(color: Colors.white24, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 練習統計タブ ──────────────────────────────────────────────

  Widget _buildStatsTab() {
    if (_isLoadingStats) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE94560)),
      );
    }
    if (_practiceStats == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart, size: 64, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              _statsError ?? '統計を読み込めませんでした',
              style: const TextStyle(color: Colors.white38),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _fetchPracticeStats,
              icon: const Icon(Icons.refresh),
              label: const Text('再読み込み'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
              ),
            ),
          ],
        ),
      );
    }
    final totalRecordings = _practiceStats!['totalSessions'] as int?
        ?? _practiceStats!['totalRecordings'] as int? ?? 0;
    final totalMinutes = _practiceStats!['totalMinutes'] as int?
        ?? _practiceStats!['totalPracticeMinutes'] as int? ?? 0;
    final streak = _practiceStats!['streakDays'] as int?
        ?? _practiceStats!['currentStreak'] as int? ?? 0;
    final favoritePreset = _practiceStats!['favoritePreset'] as String? ?? '-';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;

    return RefreshIndicator(
      onRefresh: _fetchPracticeStats,
      color: const Color(0xFFE94560),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
        children: [
          // ストリーク
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: streak > 0
                    ? [const Color(0xFFE94560), const Color(0xFFBF360C)]
                    : [const Color(0xFF16213E), const Color(0xFF16213E)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  streak > 0 ? Icons.local_fire_department : Icons.music_off,
                  color: streak > 0 ? Colors.amber : Colors.white24,
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  '$streak',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '日連続練習中',
                  style: TextStyle(
                    color: streak > 0 ? Colors.white70 : Colors.white38,
                    fontSize: 14,
                  ),
                ),
                if (streak == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '録音を保存してストリークを始めましょう！',
                      style: TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 統計カード
          Row(
            children: [
              Expanded(child: _statCard('総録音数', '$totalRecordings', Icons.mic)),
              const SizedBox(width: 12),
              Expanded(child: _statCard(
                '総練習時間',
                hours > 0 ? '$hours時間$mins分' : '$mins分',
                Icons.timer,
              ),),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statCard('よく使うジャンル', _presetLabel(favoritePreset), Icons.album)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('平均録音時間', totalRecordings > 0
                  ? '${(totalMinutes / totalRecordings).round()}分'
                  : '-', Icons.av_timer,),),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _fetchPracticeStats,
            icon: const Icon(Icons.refresh),
            label: const Text('統計を更新'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFE94560), size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── AIタブ ────────────────────────────────────────────────────

  Widget _buildAITab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFFE94560)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
                const SizedBox(height: 8),
                const Text(
                  'AIギターコーチ',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'あなたの練習データを分析し、上達のためのアドバイスを提供します',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isLoadingAI ? null : _fetchAIAnalysis,
                  icon: _isLoadingAI
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)))
                      : const Icon(Icons.psychology),
                  label: Text(_isLoadingAI ? '分析中...' : (_aiAnalysis != null ? '再分析する' : '練習を分析する')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF7C3AED),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),

          if (_aiAnalysis != null) ...[
            const SizedBox(height: 16),

            // インサイト
            _aiSection('分析結果', Icons.insights, _aiInsights()),

            // レコメンデーション
            if ((_aiAnalysis!['recommendations'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              _aiSection('おすすめ', Icons.lightbulb_outline, _aiRecommendations()),
            ],

            // 練習メニュー
            if ((_aiAnalysis!['practiceMenu'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              _aiSection('今日の練習メニュー', Icons.assignment, _aiPracticeMenu()),
            ],

            // 分析データ
            const SizedBox(height: 12),
            _aiSection('詳細データ', Icons.bar_chart, _aiStats()),
          ],
        ],
      ),
    );
  }

  Widget _aiSection(String title, IconData icon, Widget content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF7C3AED), size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _aiInsights() {
    final insights = (_aiAnalysis!['insights'] as List?) ?? [];
    if (insights.isEmpty) {
      return const Text('データが不足しています。録音を増やしましょう！', style: TextStyle(color: Colors.white54));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: insights.map((i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 16)),
            Expanded(child: Text('$i', style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4))),
          ],
        ),
      ),).toList(),
    );
  }

  Widget _aiRecommendations() {
    final recs = (_aiAnalysis!['recommendations'] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: recs.asMap().entries.map((entry) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F3460),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24, height: 24,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF7C3AED)),
              child: Center(child: Text('${entry.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('${entry.value}', style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4))),
          ],
        ),
      ),).toList(),
    );
  }

  Widget _aiPracticeMenu() {
    final menu = (_aiAnalysis!['practiceMenu'] as List?) ?? [];
    return Column(
      children: menu.asMap().entries.map((entry) {
        final item = entry.value is Map<String, dynamic> ? entry.value as Map<String, dynamic> : Map<String, dynamic>.from(entry.value as Map);
        final title = item['title'] as String? ?? '';
        final duration = item['duration'] as String? ?? '';
        final desc = item['description'] as String? ?? '';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F3460),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE94560),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(duration, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                ],
              ),
              const SizedBox(height: 6),
              Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _aiStats() {
    final analysis = _aiAnalysis!['analysis'] as Map<String, dynamic>? ?? {};
    final totalRec = analysis['totalRecordings'] as int? ?? 0;
    final totalMin = analysis['totalMinutes'] as int? ?? 0;
    final avgBpm = analysis['averageBpm'] as int? ?? 0;
    final streak = analysis['streak'] as int? ?? 0;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _miniStat('録音数', '$totalRec'),
        _miniStat('総時間', '$totalMin分'),
        _miniStat('平均BPM', '$avgBpm'),
        _miniStat('連続', '$streak日'),
      ],
    );
  }

  Widget _miniStat(String label, String value) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3460),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  String _presetLabel(String preset) {
    const labels = <String, String>{
      'acoustic_fingerpicking': 'アコースティック',
      'rock_rhythm': 'ロック',
      'blues_lead': 'ブルース',
      'jazz_clean': 'ジャズ',
      'metal_heavy': 'メタル',
      'classical': 'クラシック',
      'funk_rhythm': 'ファンク',
      'ambient': 'アンビエント',
    };
    return labels[preset] ?? preset;
  }
}

// ─── コードダイアグラム描画 ──────────────────────────────────────

class _ChordDiagramPainter extends CustomPainter {
  const _ChordDiagramPainter({
    required this.frets,
    required this.strings,
  });

  final List<int> frets;
  final List<String> strings;

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPad = 40.0;
    const double topPad = 40.0;
    const double cellW = 36.0;
    const double cellH = 32.0;
    const int rows = 5;
    const int cols = 6;

    final gridPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    final dotPaint = Paint()..color = const Color(0xFFE94560);
    const textStyle = TextStyle(color: Colors.white60, fontSize: 11);

    // 縦線
    for (int c = 0; c < cols; c++) {
      final x = leftPad + c * cellW;
      canvas.drawLine(
        Offset(x, topPad),
        Offset(x, topPad + (rows - 1) * cellH),
        gridPaint,
      );
    }
    // 横線
    for (int r = 0; r < rows; r++) {
      final y = topPad + r * cellH;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(leftPad + (cols - 1) * cellW, y),
        gridPaint,
      );
    }

    // 弦名ラベル
    for (int c = 0; c < strings.length && c < cols; c++) {
      final tp = TextPainter(
        text: TextSpan(text: strings[c], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          leftPad + c * cellW - tp.width / 2,
          topPad - tp.height - 4,
        ),
      );
    }

    // ドット描画
    for (int c = 0; c < frets.length && c < cols; c++) {
      final fret = frets[c];
      if (fret == -1) {
        final tp = TextPainter(
          text: const TextSpan(
            text: 'x',
            style: TextStyle(color: Colors.red, fontSize: 13),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            leftPad + c * cellW - tp.width / 2,
            topPad - tp.height - 2,
          ),
        );
      } else if (fret == 0) {
        canvas.drawCircle(
          Offset(leftPad + c * cellW, topPad - 10),
          7,
          Paint()
            ..color = Colors.white38
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      } else {
        final row = fret - 1;
        if (row < rows) {
          canvas.drawCircle(
            Offset(
              leftPad + c * cellW,
              topPad + row * cellH + cellH / 2,
            ),
            10,
            dotPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ChordDiagramPainter old) =>
      old.frets != frets || old.strings != strings;
}
