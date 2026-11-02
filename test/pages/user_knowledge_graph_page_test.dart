import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/user_knowledge_graph.dart';
import 'package:my_web_app/pages/user_knowledge_graph_page.dart';
import 'package:my_web_app/services/user_knowledge_graph_service.dart';
import 'package:my_web_app/view_models/user_knowledge_graph_view_model.dart';

void main() {
  testWidgets('shows server configuration and cited chat answer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeRepository();
    final viewModel = UserKnowledgeGraphViewModel(repository: repository);

    await tester.pumpWidget(
      MaterialApp(home: UserKnowledgeGraphPage(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Writer API 接続済み'), findsOneWidget);
    expect(find.text('roadmap.txt'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('userKgQuestionInput')),
      'リリースはいつですか？',
    );
    await tester.tap(find.byKey(const Key('userKgAskButton')));
    await tester.pumpAndSettle();

    expect(repository.lastQuestion, 'リリースはいつですか？');
    expect(find.text('10月です [1]'), findsOneWidget);
    expect(find.text('10月にリリース予定です。'), findsOneWidget);
  });

  testWidgets('stacks panels on a narrow viewport without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final viewModel = UserKnowledgeGraphViewModel(
      repository: _FakeRepository(configured: false, documents: const []),
    );

    await tester.pumpWidget(
      MaterialApp(home: UserKnowledgeGraphPage(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Writer API の設定が必要です'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('userKgUploadTextButton')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeRepository implements UserKnowledgeGraphRepository {
  final bool configured;
  List<UserKnowledgeGraphDocument> documents;
  String? lastQuestion;

  _FakeRepository({
    this.configured = true,
    List<UserKnowledgeGraphDocument>? documents,
  }) : documents = documents ??
            <UserKnowledgeGraphDocument>[
              const UserKnowledgeGraphDocument(
                id: 'document-1',
                fileName: 'roadmap.txt',
                mimeType: 'text/plain',
                sizeBytes: 1024,
                processingStatus: 'completed',
                createdAt: null,
              ),
            ];

  @override
  Future<UserKnowledgeGraphStatus> loadStatus() async {
    return UserKnowledgeGraphStatus(
      configured: configured,
      graphReady: documents.isNotEmpty,
      documents: documents,
    );
  }

  @override
  Future<UserKnowledgeGraphDocument> upload(
    UserKnowledgeGraphUpload document,
  ) async {
    final created = UserKnowledgeGraphDocument(
      id: 'document-${documents.length + 1}',
      fileName: document.fileName,
      mimeType: document.mimeType,
      sizeBytes: document.bytes.length,
      processingStatus: 'in_progress',
      createdAt: null,
    );
    documents = <UserKnowledgeGraphDocument>[created, ...documents];
    return created;
  }

  @override
  Future<UserKnowledgeGraphAnswer> ask(String question) async {
    lastQuestion = question;
    return const UserKnowledgeGraphAnswer(
      answer: '10月です [1]',
      citations: <UserKnowledgeGraphCitation>[
        UserKnowledgeGraphCitation(
          index: 1,
          documentId: 'document-1',
          fileName: 'roadmap.txt',
          snippet: '10月にリリース予定です。',
        ),
      ],
    );
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    documents = documents
        .where((document) => document.id != documentId)
        .toList(growable: false);
  }
}
