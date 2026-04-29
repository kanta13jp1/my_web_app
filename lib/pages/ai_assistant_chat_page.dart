// lib/pages/ai_assistant_chat_page.dart
// Voice AI チャットページ — Web Speech API + ai-hub my_agent.chat
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop'
    // ignore: uri_does_not_exist
    if (dart.library.io) 'package:my_web_app/utils/js_interop_vm_stub.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

class AiAssistantChatPage extends StatefulWidget {
  const AiAssistantChatPage({super.key});

  @override
  State<AiAssistantChatPage> createState() => _AiAssistantChatPageState();
}

class _AiAssistantChatPageState extends State<AiAssistantChatPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<_ChatMessage> _messages = [];
  _ChatImageAttachment? _selectedImage;
  bool _preferVideoResponse = false;
  String _selectedAgentProvider = 'gemini';
  bool _isLoading = false;
  bool _isListening = false;
  bool _speechSupported = true;
  String _interimText = '';
  web.SpeechRecognition? _recognition;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  static const _bg = Color(0xFF0A0A0A);
  static const _card = Color(0xFF1A1A2E);
  static const _orange = Color(0xFFFF6B35);
  static const _userBubble = Color(0xFFFF6B35);
  static const _aiBubble = Color(0xFF1E1E1E); // surface2

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseCtrl.stop();
    _initSpeech();
    _loadHistory();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    _recognition?.abort();
    super.dispose();
  }

  void _initSpeech() {
    try {
      final recognition = web.SpeechRecognition();
      recognition.lang = 'ja-JP';
      recognition.continuous = false;
      recognition.interimResults = true;
      recognition.maxAlternatives = 1;

      recognition.onresult = ((web.SpeechRecognitionEvent event) {
        final results = event.results;
        if (results.length == 0) return;
        final lastResult = results.item(results.length - 1);
        final transcript = lastResult.item(0).transcript;
        if (lastResult.isFinal) {
          setState(() {
            _inputCtrl.text = transcript;
            _interimText = '';
            _isListening = false;
          });
          _pulseCtrl.stop();
          _pulseCtrl.reset();
        } else {
          setState(() => _interimText = transcript);
        }
      }).toJS;

      recognition.onend = (() {
        if (mounted && _isListening) {
          setState(() {
            _isListening = false;
            _interimText = '';
          });
          _pulseCtrl.stop();
          _pulseCtrl.reset();
        }
      }).toJS;

      recognition.onerror = ((web.SpeechRecognitionErrorEvent event) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _interimText = '';
          });
          _pulseCtrl.stop();
          _pulseCtrl.reset();
        }
      }).toJS;

      _recognition = recognition;
    } catch (_) {
      _speechSupported = false;
    }
  }

  Future<void> _loadHistory() async {
    if (_supabase.auth.currentUser == null) return;
    try {
      final res = await _supabase.functions.invoke(
        'ai-hub',
        body: {'action': 'my_agent.history'},
      );
      final data = res.data as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        final history = data['history'] as List<dynamic>? ?? [];
        final msgs = <_ChatMessage>[];
        for (final rawItem in history.reversed) {
          final item = rawItem as Map<String, dynamic>;
          final meta = item['metadata'] as Map<String, dynamic>? ?? {};
          final msg = meta['message'] as String? ?? '';
          final resp = meta['response'] as String? ?? '';
          final hasImage = meta['has_image'] == true;
          final imageName = meta['image_name']?.toString();
          if (msg.isNotEmpty) {
            msgs.add(
              _ChatMessage(
                role: 'user',
                content: msg,
                attachmentName: hasImage ? imageName : null,
              ),
            );
          }
          if (resp.isNotEmpty) {
            msgs.add(
              _ChatMessage(
                role: 'assistant',
                content: resp,
                videoUrl: meta['video_url']?.toString() ??
                    meta['video_download_url']?.toString() ??
                    meta['video_preview_url']?.toString(),
                videoPreviewUrl: meta['video_preview_url']?.toString(),
                videoDownloadUrl: meta['video_download_url']?.toString(),
                videoStatus: meta['video_status']?.toString(),
                videoProvider: meta['video_provider']?.toString(),
                videoReason: meta['video_reason']?.toString(),
                agentProvider: meta['agent_provider']?.toString(),
                manusTaskId: meta['manus_task_id']?.toString(),
                manusTaskUrl: meta['manus_task_url']?.toString(),
              ),
            );
          }
        }
        if (mounted) setState(() => _messages = msgs);
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('history load error: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    final image = _selectedImage;
    if ((text.isEmpty && image == null) || _isLoading) return;
    final displayText = text.isEmpty ? 'この画像を分析してください' : text;

    setState(() {
      _messages.add(
        _ChatMessage(
          role: 'user',
          content: displayText,
          attachmentName: image?.name,
          imageBytes: image?.bytes,
        ),
      );
      _inputCtrl.clear();
      _selectedImage = null;
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final res = await _supabase.functions.invoke(
        'ai-hub',
        body: {
          'action': 'my_agent.chat',
          'message': displayText,
          'response_mode': _preferVideoResponse ? 'video' : 'text',
          'provider': _preferVideoResponse ? 'gemini' : _selectedAgentProvider,
          if (image != null) ...{
            'imageBase64': image.base64,
            'mimeType': image.mimeType,
            'imageName': image.name,
          },
        },
      );
      final data = res.data as Map<String, dynamic>?;
      final video = data?['video'] as Map<String, dynamic>?;
      final manus = data?['manus'] as Map<String, dynamic>?;
      final response = data?['response'] as String? ?? 'エラーが発生しました。';
      if (mounted) {
        setState(() {
          _messages.add(
            _ChatMessage(
              role: 'assistant',
              content: response,
              videoUrl: video?['video_url']?.toString() ??
                  video?['download_url']?.toString() ??
                  video?['preview_url']?.toString(),
              videoPreviewUrl: video?['preview_url']?.toString(),
              videoDownloadUrl: video?['download_url']?.toString(),
              videoStatus: video?['status']?.toString(),
              videoProvider: video?['provider']?.toString(),
              videoReason: video?['reason']?.toString(),
              agentProvider: data?['provider']?.toString(),
              manusTaskId: manus?['task_id']?.toString(),
              manusTaskUrl: manus?['task_url']?.toString(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            _ChatMessage(role: 'assistant', content: 'エラーが発生しました: $e'),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _pickImage() async {
    if (_isLoading) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null || bytes.isEmpty) return;
      const maxBytes = 4 * 1024 * 1024;
      if (bytes.length > maxBytes) {
        _showSnackBar('4MB以下の画像を選択してください');
        return;
      }
      setState(() {
        _selectedImage = _ChatImageAttachment(
          name: file.name,
          mimeType: _detectMimeType(file),
          bytes: bytes,
          base64: base64Encode(bytes),
        );
      });
    } catch (e) {
      _showSnackBar('画像を選択できませんでした: $e');
    }
  }

  String _detectMimeType(PlatformFile file) {
    final extension = file.extension?.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }

  void _toggleVoice() {
    if (_recognition == null || !_speechSupported) {
      _showSnackBar('このブラウザは音声入力に対応していません');
      return;
    }
    if (_isListening) {
      _recognition!.stop();
      setState(() {
        _isListening = false;
        _interimText = '';
      });
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    } else {
      setState(() {
        _isListening = true;
        _interimText = '';
      });
      _pulseCtrl.repeat(reverse: true);
      try {
        _recognition!.start();
      } catch (e) {
        if (!mounted) return;
        setState(() => _isListening = false);
        _pulseCtrl.stop();
        _pulseCtrl.reset();
        _showSnackBar('音声入力を開始できませんでした');
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF1A1A2E)),
    );
  }

  Future<void> _openExternalUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      _showSnackBar('動画URLを開けませんでした');
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!launched) {
      _showSnackBar('動画URLを開けませんでした');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        title: Row(
          children: [
            const Icon(Icons.smart_toy, color: _orange, size: 22),
            const SizedBox(width: 8),
            const Text(
              'AI アシスタント',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            if (_isListening) ...[
              const SizedBox(width: 8),
              ScaleTransition(
                scale: _pulseAnim,
                child:
                    const Icon(Icons.mic, color: Color(0xFFE53935), size: 16),
              ),
            ],
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white54),
            tooltip: '履歴クリア',
            onPressed: () => setState(() => _messages.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isListening)
            Container(
              width: double.infinity,
              color: const Color(0xFFE53935).withAlpha(20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.mic, color: Color(0xFFE53935), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _interimText.isEmpty ? '音声を認識中...' : _interimText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _messages.isEmpty && !_isLoading
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _messages.length) {
                        return _buildTypingIndicator();
                      }
                      final msg = _messages[i];
                      return _buildMessageBubble(
                        msg,
                        isUser: msg.role == 'user',
                      );
                    },
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.smart_toy_outlined, size: 64, color: Colors.white12),
          const SizedBox(height: 16),
          const Text(
            'AI アシスタントと話しましょう',
            style: TextStyle(color: Colors.white38, fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: 8),
          Text(
            _speechSupported
                ? 'テキスト入力またはマイクボタンで話しかけてください'
                : 'テキストを入力して送信してください',
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message, {required bool isUser}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF1F2041),
              child: Icon(Icons.smart_toy, size: 18, color: _orange),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUser ? _userBubble : _aiBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.imageBytes != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          message.imageBytes!,
                          width: 220,
                          height: 128,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else if (message.attachmentName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.image_outlined,
                            size: 16,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              message.attachmentName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!isUser &&
                      (message.videoStatus != null ||
                          message.videoUrl != null ||
                          message.videoReason != null))
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.videocam_outlined,
                                size: 16,
                                color: _orange,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  message.videoProvider == null
                                      ? '動画回答'
                                      : '動画回答 (${message.videoProvider})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              if (message.videoStatus != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _orange.withAlpha(30),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    message.videoStatus!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (message.videoReason != null &&
                              message.videoReason!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              message.videoReason!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                          if (message.videoUrl != null &&
                              message.videoUrl!.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _openExternalUrl(message.videoUrl!),
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('動画を開く'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (!isUser &&
                      ((message.agentProvider ?? '').toLowerCase() == 'manus' ||
                          (message.manusTaskId ?? '').isNotEmpty ||
                          (message.manusTaskUrl ?? '').isNotEmpty))
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.route_outlined,
                                size: 16,
                                color: _orange,
                              ),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'Manus task',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              if ((message.manusTaskId ?? '').isNotEmpty)
                                Flexible(
                                  child: Text(
                                    message.manusTaskId!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if ((message.manusTaskUrl ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _openExternalUrl(message.manusTaskUrl!),
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('Open Manus'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  Text(
                    message.content,
                    style: TextStyle(
                      color:
                          isUser ? Colors.white : Colors.white.withAlpha(230),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF2A2A2A), // surface3
              child: Icon(Icons.person, size: 18, color: _orange),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF1F2041),
            child: Icon(Icons.smart_toy, size: 18, color: _orange),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              color: _aiBubble,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedImage != null) ...[
              _buildSelectedImagePreview(_selectedImage!),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                const Icon(
                  Icons.psychology_alt_outlined,
                  color: Colors.white54,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'gemini',
                        icon: Icon(Icons.chat_bubble_outline, size: 16),
                        label: Text('Gemini'),
                      ),
                      ButtonSegment(
                        value: 'manus',
                        icon: Icon(Icons.route_outlined, size: 16),
                        label: Text('Manus'),
                      ),
                    ],
                    selected: {_selectedAgentProvider},
                    onSelectionChanged: _isLoading || _preferVideoResponse
                        ? null
                        : (selection) => setState(
                              () => _selectedAgentProvider = selection.first,
                            ),
                    style: ButtonStyle(
                      foregroundColor:
                          WidgetStateProperty.resolveWith((states) {
                        return states.contains(WidgetState.selected)
                            ? Colors.white
                            : Colors.white70;
                      }),
                      backgroundColor:
                          WidgetStateProperty.resolveWith((states) {
                        return states.contains(WidgetState.selected)
                            ? _orange.withAlpha(52)
                            : Colors.white10;
                      }),
                      side: const WidgetStatePropertyAll(
                        BorderSide(color: Colors.white12),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('テキスト回答'),
                  selected: !_preferVideoResponse,
                  onSelected: _isLoading
                      ? null
                      : (_) => setState(() => _preferVideoResponse = false),
                  selectedColor: _orange.withAlpha(38),
                  backgroundColor: Colors.white10,
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.4,
                  ),
                  side: const BorderSide(color: Colors.white12),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('動画回答'),
                  selected: _preferVideoResponse,
                  onSelected: _isLoading
                      ? null
                      : (_) => setState(() => _preferVideoResponse = true),
                  selectedColor: _orange.withAlpha(52),
                  backgroundColor: Colors.white10,
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.4,
                  ),
                  side: const BorderSide(color: Colors.white12),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '画像添付時はアバター動画の素材として使います',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: _isLoading ? null : _pickImage,
                  tooltip: '画像を添付',
                  icon: const Icon(Icons.image_outlined, color: Colors.white54),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: _selectedImage == null
                          ? 'メッセージを入力...'
                          : '画像について質問...',
                      hintStyle:
                          const TextStyle(color: Colors.white38, height: 1.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            const BorderSide(color: _orange, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF2A2A2A), // surface3
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                if (_speechSupported)
                  ScaleTransition(
                    scale: _isListening
                        ? _pulseAnim
                        : const AlwaysStoppedAnimation(1.0),
                    child: IconButton(
                      onPressed: _toggleVoice,
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening
                            ? const Color(0xFFE53935)
                            : Colors.white54,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: _isListening
                            ? const Color(0xFFE53935).withAlpha(30)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: _orange,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: _orange),
                  style: IconButton.styleFrom(
                    backgroundColor: _orange.withAlpha(20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedImagePreview(_ChatImageAttachment image) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(
            image.bytes,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            image.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
        IconButton(
          onPressed:
              _isLoading ? null : () => setState(() => _selectedImage = null),
          tooltip: '添付を削除',
          icon: const Icon(Icons.close, color: Colors.white54, size: 18),
        ),
      ],
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.role,
    required this.content,
    this.attachmentName,
    this.imageBytes,
    this.videoUrl,
    this.videoPreviewUrl,
    this.videoDownloadUrl,
    this.videoStatus,
    this.videoProvider,
    this.videoReason,
    this.agentProvider,
    this.manusTaskId,
    this.manusTaskUrl,
  });

  final String role;
  final String content;
  final String? attachmentName;
  final Uint8List? imageBytes;
  final String? videoUrl;
  final String? videoPreviewUrl;
  final String? videoDownloadUrl;
  final String? videoStatus;
  final String? videoProvider;
  final String? videoReason;
  final String? agentProvider;
  final String? manusTaskId;
  final String? manusTaskUrl;
}

class _ChatImageAttachment {
  const _ChatImageAttachment({
    required this.name,
    required this.mimeType,
    required this.bytes,
    required this.base64,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;
  final String base64;
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<int> _dotCount;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _dotCount = IntTween(begin: 1, end: 3).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dotCount,
      builder: (_, __) {
        return Text(
          '●' * _dotCount.value,
          style:
              const TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
        );
      },
    );
  }
}
