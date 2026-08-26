import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/knowledge_graph_rag.dart';
import 'package:my_web_app/services/knowledge_graph_rag_service.dart';
import 'package:my_web_app/view_models/knowledge_graph_rag_view_model.dart';

void main() {
  test('queries selected sources and exposes the citation answer', () async {
    final gateway = _FakeGateway(answer: _answer);
    final viewModel = KnowledgeGraphRagViewModel(gateway: gateway);
    addTearDown(viewModel.dispose);

    viewModel.setSourceSelected('issues', false);
    viewModel.setUseLlm(false);

    expect(await viewModel.search('優先事項は？'), isTrue);
    expect(gateway.lastQuery, '優先事項は？');
    expect(gateway.lastSources, isNot(contains('issues')));
    expect(gateway.lastUseLlm, isFalse);
    expect(viewModel.answer, _answer);
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.isLoading, isFalse);
  });

  test('maps an authentication failure to a safe login message', () async {
    final viewModel = KnowledgeGraphRagViewModel(
      gateway: _FakeGateway(
        error: const KnowledgeGraphRagException(
          'unauthorized',
          requiresLogin: true,
        ),
      ),
    );
    addTearDown(viewModel.dispose);

    expect(await viewModel.search('根拠は？'), isFalse);
    expect(viewModel.requiresLogin, isTrue);
    expect(viewModel.errorMessage, contains('ログイン'));
    expect(viewModel.answer, isNull);
  });
}

const _answer = KnowledgeGraphRagAnswer(
  query: '優先事項は？',
  answer: '公開準備です [1]。',
  status: 'ok',
  traceId: 'trace-1',
  citations: <KnowledgeGraphRagCitation>[],
);

class _FakeGateway implements KnowledgeGraphRagGateway {
  _FakeGateway({this.answer, this.error});

  final KnowledgeGraphRagAnswer? answer;
  final KnowledgeGraphRagException? error;
  String? lastQuery;
  Set<String>? lastSources;
  bool? lastUseLlm;

  @override
  Future<KnowledgeGraphRagAnswer> query({
    required String query,
    required Set<String> sources,
    required bool useLlm,
  }) async {
    lastQuery = query;
    lastSources = Set<String>.from(sources);
    lastUseLlm = useLlm;
    if (error != null) throw error!;
    return answer!;
  }
}
