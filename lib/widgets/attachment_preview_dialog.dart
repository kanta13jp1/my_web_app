import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/attachment.dart';
import '../services/attachment_service.dart';

class AttachmentPreviewDialog extends StatefulWidget {
  final Attachment attachment;

  const AttachmentPreviewDialog({
    super.key,
    required this.attachment,
  });

  @override
  State<AttachmentPreviewDialog> createState() =>
      _AttachmentPreviewDialogState();
}

class _AttachmentPreviewDialogState extends State<AttachmentPreviewDialog> {
  String? _signedUrl;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  Future<void> _loadSignedUrl() async {
    try {
      final url = await AttachmentService.getSignedUrl(widget.attachment.filePath);
      if (mounted) {
        setState(() {
          _signedUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ヘッダー
            Row(
              children: [
                Text(
                  widget.attachment.icon,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.attachment.fileName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.attachment.formattedSize,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            // プレビュー
            Expanded(
              child: _buildPreview(),
            ),
            const SizedBox(height: 16),
            // ダウンロードボタン
            if (_signedUrl != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('ダウンロード'),
                onPressed: () => _downloadFile(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('エラー: $_error'),
          ],
        ),
      );
    }

    if (_signedUrl == null) {
      return const Center(
        child: Text('プレビューを読み込めません'),
      );
    }

    // 画像の場合
    if (widget.attachment.isImage) {
      return Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            _signedUrl!,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('画像を読み込めません'),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    // PDFの場合
    if (widget.attachment.isPdf) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
            const SizedBox(height: 24),
            Text(
              widget.attachment.fileName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.attachment.formattedSize,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('新しいタブで開く'),
              onPressed: () => _openInNewTab(),
            ),
            const SizedBox(height: 16),
            Text(
              'ブラウザでPDFを表示します',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return const Center(
      child: Text('プレビューできないファイル形式です'),
    );
  }

  Future<void> _openInNewTab() async {
    if (_signedUrl != null) {
      final uri = Uri.parse(_signedUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _downloadFile() async {
    if (_signedUrl != null) {
      final uri = Uri.parse(_signedUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}