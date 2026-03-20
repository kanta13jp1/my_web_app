import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class NotePromptTemplate {
  final String id;
  final String title;
  final String prompt;
  final DateTime updatedAt;

  const NotePromptTemplate({
    required this.id,
    required this.title,
    required this.prompt,
    required this.updatedAt,
  });

  factory NotePromptTemplate.fromJson(Map<String, dynamic> json) {
    return NotePromptTemplate(
      id: (json['id'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
      prompt: (json['prompt'] as String? ?? '').trim(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, String> toJson() {
    return <String, String>{
      'id': id,
      'title': title,
      'prompt': prompt,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  NotePromptTemplate copyWith({
    String? id,
    String? title,
    String? prompt,
    DateTime? updatedAt,
  }) {
    return NotePromptTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      prompt: prompt ?? this.prompt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class NotePromptLibraryService {
  static const String _storageKey = 'note_prompt_library_v1';

  const NotePromptLibraryService();

  Future<List<NotePromptTemplate>> loadTemplates({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final encoded = store.getString(_storageKey);
    if (encoded == null || encoded.trim().isEmpty) {
      return const <NotePromptTemplate>[];
    }

    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      return const <NotePromptTemplate>[];
    }

    final templates = <NotePromptTemplate>[];
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      final template = NotePromptTemplate.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (template.id.isEmpty ||
          template.title.isEmpty ||
          template.prompt.isEmpty) {
        continue;
      }
      templates.add(template);
    }

    return _sortTemplates(templates);
  }

  Future<List<NotePromptTemplate>> saveTemplate(
    NotePromptTemplate template, {
    SharedPreferences? prefs,
  }) async {
    final current = await loadTemplates(prefs: prefs);
    final normalized = template.copyWith(
      id: template.id.trim(),
      title: template.title.trim(),
      prompt: template.prompt.trim(),
      updatedAt: template.updatedAt,
    );

    if (normalized.id.isEmpty ||
        normalized.title.isEmpty ||
        normalized.prompt.isEmpty) {
      return current;
    }

    final next = <NotePromptTemplate>[
      for (final item in current)
        if (item.id != normalized.id) item,
      normalized,
    ];

    return _persistTemplates(next, prefs: prefs);
  }

  Future<List<NotePromptTemplate>> deleteTemplate(
    String templateId, {
    SharedPreferences? prefs,
  }) async {
    final current = await loadTemplates(prefs: prefs);
    final next = current.where((item) => item.id != templateId).toList();
    return _persistTemplates(next, prefs: prefs);
  }

  Future<List<NotePromptTemplate>> _persistTemplates(
    List<NotePromptTemplate> templates, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final sorted = _sortTemplates(templates);
    final encoded = jsonEncode(
      sorted.map((template) => template.toJson()).toList(),
    );
    await store.setString(_storageKey, encoded);
    return sorted;
  }

  List<NotePromptTemplate> _sortTemplates(List<NotePromptTemplate> templates) {
    final sorted = List<NotePromptTemplate>.from(templates);
    sorted.sort((a, b) {
      final updatedCompare = b.updatedAt.compareTo(a.updatedAt);
      if (updatedCompare != 0) {
        return updatedCompare;
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return sorted;
  }
}
