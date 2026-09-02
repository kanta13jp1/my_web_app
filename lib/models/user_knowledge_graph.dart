import 'dart:typed_data';

class UserKnowledgeGraphUpload {
  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  const UserKnowledgeGraphUpload({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });
}

class UserKnowledgeGraphDocument {
  final String id;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String processingStatus;
  final DateTime? createdAt;

  const UserKnowledgeGraphDocument({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.processingStatus,
    required this.createdAt,
  });

  factory UserKnowledgeGraphDocument.fromMap(Map<String, dynamic> map) {
    return UserKnowledgeGraphDocument(
      id: map['id']?.toString() ?? '',
      fileName: map['file_name']?.toString() ?? 'Uploaded document',
      mimeType: map['mime_type']?.toString() ?? 'application/octet-stream',
      sizeBytes: _asInt(map['size_bytes']),
      processingStatus: map['processing_status']?.toString() ?? 'unknown',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }
}

class UserKnowledgeGraphCitation {
  final int index;
  final String? documentId;
  final String fileName;
  final String snippet;

  const UserKnowledgeGraphCitation({
    required this.index,
    required this.documentId,
    required this.fileName,
    required this.snippet,
  });

  factory UserKnowledgeGraphCitation.fromMap(Map<String, dynamic> map) {
    return UserKnowledgeGraphCitation(
      index: _asInt(map['index']),
      documentId: map['document_id']?.toString(),
      fileName: map['file_name']?.toString() ?? 'Uploaded document',
      snippet: map['snippet']?.toString() ?? '',
    );
  }
}

class UserKnowledgeGraphAnswer {
  final String answer;
  final List<UserKnowledgeGraphCitation> citations;

  const UserKnowledgeGraphAnswer({
    required this.answer,
    required this.citations,
  });
}

class UserKnowledgeGraphStatus {
  final bool configured;
  final bool graphReady;
  final List<UserKnowledgeGraphDocument> documents;

  const UserKnowledgeGraphStatus({
    required this.configured,
    required this.graphReady,
    required this.documents,
  });
}

enum UserKnowledgeGraphMessageRole { user, assistant }

class UserKnowledgeGraphMessage {
  final UserKnowledgeGraphMessageRole role;
  final String text;
  final List<UserKnowledgeGraphCitation> citations;

  const UserKnowledgeGraphMessage({
    required this.role,
    required this.text,
    this.citations = const <UserKnowledgeGraphCitation>[],
  });
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
