import 'package:flutter/material.dart';
import '../data/services/reading_book_search.dart';
import '../domain/models/philosophy_reading.dart';

class ReadingBookLookup extends StatefulWidget {
  const ReadingBookLookup({super.key, required this.onSelected, this.search});
  final ValueChanged<ReadingEdition> onSelected;
  final Future<List<ReadingBookResult>> Function(String)? search;
  @override
  State<ReadingBookLookup> createState() => _ReadingBookLookupState();
}

class _ReadingBookLookupState extends State<ReadingBookLookup> {
  final _query = TextEditingController();
  bool _loading = false;
  String? _message;
  List<ReadingBookResult> _results = [];
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _message = null;
      _results = [];
    });
    try {
      final results = await (widget.search ??
          const ReadingBookSearch().search)(_query.text);
      if (!mounted) return;
      setState(() {
        _results = results;
        if (results.isEmpty) {
          _message = '見つかりませんでした。目録にない本はISBNで検索するか、手入力してください。';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _message = '書籍情報を取得できませんでした。再検索または手入力できます。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(ReadingBookResult book) async {
    final selected = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この書籍情報を設定しますか？'),
        content: Text(
          '${book.title}\n${book.edition.publisher}\nISBN: ${book.edition.isbn}\n\n現在の版情報を置き換えます。取得できない項目は空欄になります。設定後に確認・修正してください。',
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
            enabled: !_loading,
            decoration: const InputDecoration(labelText: '書籍情報を検索（書名・ISBN）'),
            onSubmitted: (_) => _search(),
          ),
          TextButton(
            onPressed: _loading ? null : _search,
            child: Text(_loading ? '書籍情報を検索中…' : '書籍情報を検索'),
          ),
          const Text('書名は共有目録を検索します。目録にない本はISBNからopenBDで取得します。'),
          if (_message != null) Text(_message!),
          ..._results.map(
            (book) => ListTile(
              title: Text(book.title),
              subtitle: Text(
                '${book.edition.publisher} / ${book.edition.translator}\nISBN: ${book.edition.isbn}',
              ),
              onTap: () => _select(book),
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
}
