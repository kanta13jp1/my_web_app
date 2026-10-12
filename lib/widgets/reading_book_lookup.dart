import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/services/reading_book_search.dart';
import '../domain/models/philosophy_reading.dart';

class ReadingBookLookup extends StatefulWidget {
  const ReadingBookLookup({
    super.key,
    required this.onSelected,
    this.search,
    this.initialQuery = '',
  });
  final String initialQuery;
  final ValueChanged<ReadingEdition> onSelected;
  final Future<List<ReadingBookResult>> Function(String)? search;
  @override
  State<ReadingBookLookup> createState() => _ReadingBookLookupState();
}

class _ReadingBookLookupState extends State<ReadingBookLookup> {
  final _query = TextEditingController();
  bool _loading = false;
  int _request = 0;
  String? _message;
  List<ReadingBookResult> _results = [];
  @override
  void initState() {
    super.initState();
    _query.text = widget.initialQuery.trim();
    if (_query.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search();
      });
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search({bool external = false}) async {
    if (_loading) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _message = null;
      _results = [];
    });
    try {
      final results = widget.search != null
          ? await widget.search!(_query.text)
          : await const ReadingBookSearch().search(
              _query.text,
              external: external,
            );
      if (!mounted || request != _request) return;
      setState(() {
        _results = results;
        if (results.isEmpty) {
          _message = '見つかりませんでした。書名を短くするか、ISBNで検索してください。手入力もできます。';
        }
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _message = '書籍情報を取得できませんでした。再検索または手入力できます。');
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _select(ReadingBookResult book) async {
    final selected = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この書籍情報を設定しますか？'),
        content: Text(
          '${book.title}\n${book.edition.publisher} / ${book.edition.year}\n訳者: ${book.edition.translator}\nページ数: ${book.edition.totalPages ?? '不明'}\nISBN: ${book.edition.isbn}\n出典: ${book.edition.sourceUrl}\n\n現在の版情報を置き換えます。取得できない項目は空欄になります。設定後に確認・修正してください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('書籍情報を設定'),
          ),
        ],
      ),
    );
    if (selected == true && mounted) widget.onSelected(book.edition);
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _query,
            onChanged: (_) => setState(() {
              _request++;
              _loading = false;
              _message = null;
              _results = [];
            }),
            decoration: const InputDecoration(labelText: '書籍情報を検索（書名・ISBN）'),
            onSubmitted: (_) => _search(),
          ),
          TextButton(
            onPressed: _loading ? null : () => _search(),
            child: Text(_loading ? '書籍情報を検索中…' : '書籍情報を検索'),
          ),
          const Text('書名は目録を検索し、候補がなければ国立国会図書館サーチから取得します。ISBNはopenBDで検索できます。'),
          TextButton(
            onPressed: _loading ? null : () => _search(external: true),
            child: const Text('外部の版も検索'),
          ),
          const Text(
            '外部検索は最大20件です。関連資料も含まれるため、書名・出版社・訳者・巻を確認して版を選んでください。購入リンクはAmazonの検索で、在庫は販売先で確認できます。',
          ),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse('https://ndlsearch.ndl.go.jp/help/api/provider'),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('外部書名検索の出典: 国立国会図書館サーチ（国立国会図書館蔵書）／CC BY 4.0'),
          ),
          if (_message != null) Text(_message!),
          ..._results.map(
            (book) => ListTile(
              title: Text(book.title),
              subtitle: Text(
                '${book.edition.publisher} / ${book.edition.year} / ${book.edition.translator}\n巻: ${book.edition.volume} / ${book.edition.totalPages ?? '不明'}ページ\nISBN: ${book.edition.isbn}',
              ),
              onTap: () => _select(book),
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
}
