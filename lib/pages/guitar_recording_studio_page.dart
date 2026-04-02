import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchStudioData();
    _fetchRecordings();
    _fetchPracticeStats();
  }

  @override
  void dispose() {
    _stopMetronome();
    _recordingTimer?.cancel();
    _mediaRecorder?.stop();
    _mediaStream?.getTracks().toDart.forEach((t) => t.stop());
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
        final list = data['recordings'];
        if (list is List) {
          setState(() {
            _recordings = list
                .map((r) => r is Map<String, dynamic> ? r : Map<String, dynamic>.from(r as Map))
                .toList();
          });
        }
      }
    } catch (_) {
      // 無視
    } finally {
      if (mounted) setState(() => _isLoadingRecordings = false);
    }
  }

  Future<void> _fetchPracticeStats() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final res = await _supabase.functions.invoke(
        'guitar-recording-studio',
        queryParameters: {'action': 'practice_stats', 'userId': user.id},
      );
      final data = _parseResponse(res.data);
      if (data != null) {
        setState(() => _practiceStats = data);
      }
    } catch (_) {}
  }

  Future<void> _deleteRecording(String recordingId) async {
    try {
      await _supabase.functions.invoke(
        'guitar-recording-studio',
        body: {'action': 'delete_recording', 'recordingId': recordingId},
      );
      await _fetchRecordings();
      await _fetchPracticeStats();
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
    setState(() => _errorMessage = null);
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
      }.jsify();
      final constraints = web.MediaStreamConstraints(
        audio: audioConstraints,
      );
      final stream = await mediaDevices.getUserMedia(constraints).toDart;
      _mediaStream = stream;
      _audioChunks.clear();

      // 高ビットレートで録音 (256kbps)
      final options = web.MediaRecorderOptions(
        mimeType: 'audio/webm;codecs=opus',
        audioBitsPerSecond: 256000,
      );
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
          final blobParts = _audioChunks.toJS;
          final blobInit = web.BlobPropertyBag(type: 'audio/webm');
          final blob = web.Blob(blobParts, blobInit);
          final url = web.URL.createObjectURL(blob);
          if (mounted) setState(() => _audioUrl = url);
        }.toJS,
      );

      _mediaRecorder!.start(100);

      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordingDuration = Duration.zero;
        _audioUrl = null;
        _savedSuccessfully = false;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_isRecording && !_isPaused) {
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
          });
        }
      });
    } catch (e) {
      setState(
        () => _errorMessage =
            'マイクへのアクセスに失敗しました。\n設定でマイクを許可してください。\n$e',
      );
    }
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
      _recordingDuration = Duration.zero;
      _savedSuccessfully = false;
    });
  }

  void _downloadRecording() {
    if (_audioUrl == null) return;
    final title = _titleController.text.trim();
    final fileName = title.isNotEmpty ? '$title.webm' : 'guitar-recording.webm';
    final anchor = web.HTMLAnchorElement()
      ..href = _audioUrl!
      ..download = fileName
      ..style.display = 'none';
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
  }

  Future<void> _saveRecording() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _errorMessage = 'ログインが必要です');
      return;
    }
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'タイトルを入力してください');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await _supabase.functions.invoke(
        'guitar-recording-studio',
        body: {
          'action': 'save_recording',
          'userId': user.id,
          'title': title,
          'durationSeconds': _recordingDuration.inSeconds,
          'preset': _selectedPreset,
          'tuning': _selectedTuning,
          'bpm': _bpm,
          'tracks': 1,
          'tags': _tagsController.text.trim().isEmpty
              ? <String>[]
              : _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
          'isPublic': _isPublic,
        },
      );
      setState(() => _savedSuccessfully = true);
      await _fetchRecordings();
      await _fetchPracticeStats();
      _titleController.clear();
      _tagsController.clear();
    } catch (e) {
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
            ],
          ),
        ),
      ),
      body: _buildTabContent(),
    );
  }

  Widget _tabButton(String label, int index) {
    final isSelected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
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
                  const Text(
                    '48kHz / ステレオ / 256kbps (WebM Opus)',
                    style: TextStyle(color: Colors.white24, fontSize: 11),
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

  Widget _buildDownloadButton() {
    return GestureDetector(
      onTap: _downloadRecording,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0F3460),
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
        child: const Row(
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
                activeColor: const Color(0xFFE94560),
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
          final tags = r['tags'] as List? ?? [];
          final recordingId = r['recordingId'] as String? ?? '';
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
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 4),
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
    if (_practiceStats == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE94560)),
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

    return SingleChildScrollView(
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
                hours > 0 ? '$hours時間${mins}分' : '$mins分',
                Icons.timer,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statCard('よく使うジャンル', _presetLabel(favoritePreset), Icons.album)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('平均録音時間', totalRecordings > 0
                  ? '${(totalMinutes / totalRecordings).round()}分'
                  : '-', Icons.av_timer)),
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
