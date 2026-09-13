import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/user_knowledge_graph.dart';
import '../services/user_knowledge_graph_service.dart';

class UserKnowledgeGraphViewModel extends ChangeNotifier {
  final UserKnowledgeGraphRepository repository;
  final UserKnowledgeDocumentPicker documentPicker;

  UserKnowledgeGraphViewModel({
    required this.repository,
    this.documentPicker = const FilePickerUserKnowledgeDocumentPicker(),
  });

  bool isLoading = false;
  bool isUploading = false;
  bool isAsking = false;
  bool isDeleting = false;
  bool configured = false;
  bool graphReady = false;
  String? errorMessage;
  List<UserKnowledgeGraphDocument> documents =
      const <UserKnowledgeGraphDocument>[];
  final List<UserKnowledgeGraphMessage> messages =
      <UserKnowledgeGraphMessage>[];

  bool get canUpload => configured && !isUploading && !isDeleting;
  bool get canAsk =>
      configured && documents.isNotEmpty && !isAsking && !isDeleting;

  Future<void> initialize() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _reloadStatus();
    } catch (error) {
      errorMessage = _messageFor(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pickAndUpload() async {
    if (!canUpload) return;
    try {
      final upload = await documentPicker.pickDocument();
      if (upload != null) await uploadDocument(upload);
    } catch (error) {
      errorMessage = _messageFor(error);
      notifyListeners();
    }
  }

  Future<void> uploadText(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      errorMessage = '登録するテキストを入力してください。';
      notifyListeners();
      return;
    }
    await uploadDocument(
      UserKnowledgeGraphUpload(
        fileName: 'pasted-knowledge.txt',
        mimeType: 'text/plain',
        bytes: Uint8List.fromList(utf8.encode(normalized)),
      ),
    );
  }

  Future<void> uploadDocument(UserKnowledgeGraphUpload upload) async {
    if (!canUpload) return;
    isUploading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await repository.upload(upload);
      await _reloadStatus();
    } catch (error) {
      errorMessage = _messageFor(error);
    } finally {
      isUploading = false;
      notifyListeners();
    }
  }

  Future<void> ask(String question) async {
    final normalized = question.trim();
    if (normalized.isEmpty || !canAsk) return;
    messages.add(
      UserKnowledgeGraphMessage(
        role: UserKnowledgeGraphMessageRole.user,
        text: normalized,
      ),
    );
    isAsking = true;
    errorMessage = null;
    notifyListeners();
    try {
      final answer = await repository.ask(normalized);
      messages.add(
        UserKnowledgeGraphMessage(
          role: UserKnowledgeGraphMessageRole.assistant,
          text: answer.answer,
          citations: answer.citations,
        ),
      );
    } catch (error) {
      errorMessage = _messageFor(error);
    } finally {
      isAsking = false;
      notifyListeners();
    }
  }

  Future<void> deleteDocument(String documentId) async {
    if (documentId.isEmpty || isDeleting) return;
    isDeleting = true;
    errorMessage = null;
    notifyListeners();
    try {
      await repository.deleteDocument(documentId);
      await _reloadStatus();
    } catch (error) {
      errorMessage = _messageFor(error);
    } finally {
      isDeleting = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> _reloadStatus() async {
    final status = await repository.loadStatus();
    configured = status.configured;
    graphReady = status.graphReady;
    documents = status.documents;
  }

  String _messageFor(Object error) {
    if (error is UserKnowledgeGraphException) return error.message;
    return 'ナレッジグラフ処理に失敗しました。時間をおいて再試行してください。';
  }
}
