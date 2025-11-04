import 'package:flutter/material.dart';
import '../models/attachment.dart';
import '../services/attachment_service.dart';
import 'attachment_preview_dialog.dart';

class AttachmentListWidget extends StatelessWidget {
  final List<Attachment> attachments;
  final Function(Attachment) onDelete;
  final bool isEditing;

  const AttachmentListWidget({
    super.key,
    required this.attachments,
    required this.onDelete,
    this.isEditing = true,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file, size: 18),
              const SizedBox(width: 8),
              Text(
                '添付ファイル (${attachments.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: attachments.map((attachment) {
              return _buildAttachmentChip(context, attachment);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentChip(BuildContext context, Attachment attachment) {
    return InkWell(
      onTap: () => _showPreview(context, attachment),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: attachment.isImage ? Colors.blue : Colors.orange,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // アイコン
            Text(
              attachment.icon,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            // ファイル名とサイズ
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    attachment.fileName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  attachment.formattedSize,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            // 削除ボタン
            if (isEditing) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _confirmDelete(context, attachment),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPreview(BuildContext context, Attachment attachment) {
    showDialog(
      context: context,
      builder: (context) => AttachmentPreviewDialog(attachment: attachment),
    );
  }

  void _confirmDelete(BuildContext context, Attachment attachment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添付ファイルを削除'),
        content: Text('「${attachment.fileName}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete(attachment);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}