import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/philosophy_reading.dart';

abstract class ReadingRepository {
  String? get sessionKey;
  Stream<void> get authChanges;
  Future<List<ReadingRecord>> list();
  Future<List<PhilosophyAuthor>> authors();
  Future<ReadingRecord> add(String id, PhilosophyWork work);
  Future<ReadingRecord> save(ReadingRecord record);
  Future<PhilosophyAuthor> addAuthor(String id, PhilosophyAuthor author);
}

class SupabaseReadingRepository implements ReadingRepository {
  SupabaseReadingRepository(this.client);
  final SupabaseClient client;

  @override
  String? get sessionKey => client.auth.currentUser?.id;
  @override
  Stream<void> get authChanges => client.auth.onAuthStateChange.map((_) {});

  Future<ReadingJson> _invoke(String action, ReadingJson body) async {
    final user = sessionKey;
    if (user == null) throw StateError('ログインしてから記録してください');
    try {
      final response = await client.functions.invoke(
        'tools-hub',
        body: {'action': action, ...body},
      );
      if (sessionKey != user) throw StateError('ログイン状態が変わりました');
      final data = readingMap(response.data);
      if (data['success'] != true) throw StateError('保存できませんでした');
      return data;
    } on FunctionException catch (error) {
      final detail = readingMap(error.details)['error'];
      if (error.status == 409) {
        throw StateError('別の画面で更新されました。再読込してから保存してください');
      }
      throw StateError(
          detail is String ? detail : '通信に失敗しました。入力を確認して再試行してください',);
    }
  }

  @override
  Future<List<ReadingRecord>> list() async {
    final data = await _invoke('reading.list', {});
    return (data['items'] as List)
        .map((r) => ReadingRecord.fromHub(readingMap(r)))
        .toList();
  }

  @override
  Future<List<PhilosophyAuthor>> authors() async {
    final data = await _invoke('reading.authors', {});
    return (data['items'] as List)
        .map((r) => PhilosophyAuthor.fromJson(
              readingMap(readingMap(readingMap(r)['metadata'])['author_info']),
            ),)
        .toList();
  }

  @override
  Future<ReadingRecord> add(String id, PhilosophyWork work) async {
    final data =
        await _invoke('reading.add', {'id': id, 'work': work.toJson()});
    return ReadingRecord.fromHub(readingMap(data['item']));
  }

  @override
  Future<ReadingRecord> save(ReadingRecord record) async {
    final data = await _invoke('reading.save', record.savePayload());
    return ReadingRecord.fromHub(readingMap(data['item']));
  }

  @override
  Future<PhilosophyAuthor> addAuthor(String id, PhilosophyAuthor author) async {
    final data = await _invoke(
        'reading.author.add', {'id': id, 'author_info': author.toJson()},);
    return PhilosophyAuthor.fromJson(
      readingMap(
          readingMap(readingMap(data['item'])['metadata'])['author_info'],),
    );
  }
}
