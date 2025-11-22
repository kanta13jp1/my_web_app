class Attachment {
  final int id; // String → int に変更
  final int noteId; // String → int に変更
  final String userId;
  final String fileName;
  final String filePath;
  final int fileSize;
  final String fileType;
  final String mimeType;
  final DateTime createdAt;

  Attachment({
    required this.id,
    required this.noteId,
    required this.userId,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.fileType,
    required this.mimeType,
    required this.createdAt,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as int, // 修正
      noteId: json['note_id'] as int, // 修正
      userId: json['user_id'] as String,
      fileName: json['file_name'] as String,
      filePath: json['file_path'] as String,
      fileSize: json['file_size'] as int,
      fileType: json['file_type'] as String,
      mimeType: json['mime_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'note_id': noteId,
      'user_id': userId,
      'file_name': fileName,
      'file_path': filePath,
      'file_size': fileSize,
      'file_type': fileType,
      'mime_type': mimeType,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // ファイルサイズを人間が読める形式に変換
  String get formattedSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  // ファイルタイプのアイコンを取得
  String get icon {
    if (fileType == 'image') {
      return '🖼️';
    } else if (fileType == 'pdf') {
      return '📄';
    } else {
      return '📎';
    }
  }

  // ファイルが画像かどうか
  bool get isImage => fileType == 'image';

  // ファイルがPDFかどうか
  bool get isPdf => fileType == 'pdf';
}
