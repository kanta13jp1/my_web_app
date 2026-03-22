import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum DigestItemStatus {
  active,
  backlog,
  completed,
}

class DigestProgressEntry {
  const DigestProgressEntry({
    required this.note,
    required this.createdAt,
  });

  final String note;
  final DateTime createdAt;

  factory DigestProgressEntry.fromJson(Map<String, dynamic> json) {
    return DigestProgressEntry(
      note: json['note']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'note': note,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

class DigestQueueItem {
  const DigestQueueItem({
    required this.id,
    required this.title,
    required this.domain,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.note,
    required this.progressEntries,
  });

  final String id;
  final String title;
  final String domain;
  final DigestItemStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String note;
  final List<DigestProgressEntry> progressEntries;

  bool get isActive => status == DigestItemStatus.active;
  bool get isBacklog => status == DigestItemStatus.backlog;
  bool get isCompleted => status == DigestItemStatus.completed;

  DigestProgressEntry? get latestProgress =>
      progressEntries.isEmpty ? null : progressEntries.last;

  factory DigestQueueItem.fromJson(Map<String, dynamic> json) {
    return DigestQueueItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      domain: json['domain']?.toString() ?? DigestQueueService.otherDomain,
      status: DigestQueueService.parseStatus(json['status']?.toString()),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      note: json['note']?.toString() ?? '',
      progressEntries: ((json['progress_entries'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map(
            (entry) => DigestProgressEntry.fromJson(
              Map<String, dynamic>.from(entry),
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'domain': domain,
      'status': status.name,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'note': note,
      'progress_entries': progressEntries
          .map((entry) => entry.toJson())
          .toList(),
    };
  }

  DigestQueueItem copyWith({
    String? id,
    String? title,
    String? domain,
    DigestItemStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? note,
    List<DigestProgressEntry>? progressEntries,
  }) {
    return DigestQueueItem(
      id: id ?? this.id,
      title: title ?? this.title,
      domain: domain ?? this.domain,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      note: note ?? this.note,
      progressEntries: progressEntries ?? this.progressEntries,
    );
  }
}

class DigestAddResult {
  const DigestAddResult({
    required this.items,
    required this.item,
    required this.queued,
  });

  final List<DigestQueueItem> items;
  final DigestQueueItem item;
  final bool queued;
}

class DigestQueueService {
  const DigestQueueService({
    this.nowProvider,
  });

  static const String otherDomain = 'その他';

  static const List<String> builtinDomains = <String>[
    '読書',
    '勉強',
    '講座',
    '動画',
    '記事',
    otherDomain,
  ];

  static const String _storageKey = 'digest_queue_items_v1';

  final DateTime Function()? nowProvider;

  DateTime _now() => nowProvider?.call() ?? DateTime.now();

  static DigestItemStatus parseStatus(String? raw) {
    return DigestItemStatus.values.firstWhere(
      (status) => status.name == raw,
      orElse: () => DigestItemStatus.backlog,
    );
  }

  Future<List<DigestQueueItem>> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const <DigestQueueItem>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <DigestQueueItem>[];
      }

      final items = decoded
          .whereType<Map>()
          .map(
            (entry) => DigestQueueItem.fromJson(
              Map<String, dynamic>.from(entry),
            ),
          )
          .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
          .toList();
      return sortItems(items);
    } catch (_) {
      return const <DigestQueueItem>[];
    }
  }

  Future<DigestAddResult> addItem({
    required String title,
    required String domain,
    String note = '',
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('title must not be empty');
    }

    final normalizedDomain = domain.trim().isEmpty ? otherDomain : domain.trim();
    final now = _now();
    final current = await loadItems();
    final hasActiveInDomain = current.any(
      (item) => item.domain == normalizedDomain && item.isActive,
    );

    final created = DigestQueueItem(
      id: 'digest_${now.microsecondsSinceEpoch}_${current.length}',
      title: trimmedTitle,
      domain: normalizedDomain,
      status: hasActiveInDomain
          ? DigestItemStatus.backlog
          : DigestItemStatus.active,
      createdAt: now,
      updatedAt: now,
      note: note.trim(),
      progressEntries: const <DigestProgressEntry>[],
    );

    final nextItems = sortItems(<DigestQueueItem>[
      ...current,
      created,
    ]);
    await _saveItems(nextItems);

    return DigestAddResult(
      items: nextItems,
      item: created,
      queued: hasActiveInDomain,
    );
  }

  Future<List<DigestQueueItem>> recordProgress(
    String itemId,
    String note,
  ) async {
    final trimmedNote = note.trim();
    if (trimmedNote.isEmpty) {
      throw ArgumentError('note must not be empty');
    }

    final now = _now();
    final current = await loadItems();
    final nextItems = current.map((item) {
      if (item.id != itemId) {
        return item;
      }
      return item.copyWith(
        updatedAt: now,
        progressEntries: <DigestProgressEntry>[
          ...item.progressEntries,
          DigestProgressEntry(note: trimmedNote, createdAt: now),
        ],
      );
    }).toList();

    final sorted = sortItems(nextItems);
    await _saveItems(sorted);
    return sorted;
  }

  Future<List<DigestQueueItem>> completeItem(
    String itemId, {
    String note = '',
  }) async {
    final now = _now();
    final current = await loadItems();
    DigestQueueItem? target;

    final updated = current.map((item) {
      if (item.id != itemId) {
        return item;
      }
      target = item;
      final progressEntries = note.trim().isEmpty
          ? item.progressEntries
          : <DigestProgressEntry>[
              ...item.progressEntries,
              DigestProgressEntry(note: note.trim(), createdAt: now),
            ];
      return item.copyWith(
        status: DigestItemStatus.completed,
        updatedAt: now,
        progressEntries: progressEntries,
      );
    }).toList();

    if (target == null) {
      return current;
    }

    final promoted = _promoteNextBacklog(
      updated,
      domain: target!.domain,
      now: now,
    );
    final sorted = sortItems(promoted);
    await _saveItems(sorted);
    return sorted;
  }

  Future<List<DigestQueueItem>> activateBacklogItem(String itemId) async {
    final now = _now();
    final current = await loadItems();
    DigestQueueItem? target;
    for (final item in current) {
      if (item.id == itemId) {
        target = item;
        break;
      }
    }

    if (target == null || !target.isBacklog) {
      return current;
    }

    final targetDomain = target.domain;
    final hasActiveInDomain = current.any(
      (item) => item.domain == targetDomain && item.isActive,
    );
    if (hasActiveInDomain) {
      throw StateError('active item already exists in this domain');
    }

    final updated = current.map((item) {
      if (item.id != itemId) {
        return item;
      }
      return item.copyWith(
        status: DigestItemStatus.active,
        updatedAt: now,
      );
    }).toList();

    final sorted = sortItems(updated);
    await _saveItems(sorted);
    return sorted;
  }

  Future<List<DigestQueueItem>> deleteItem(String itemId) async {
    final now = _now();
    final current = await loadItems();
    DigestQueueItem? removed;
    for (final item in current) {
      if (item.id == itemId) {
        removed = item;
        break;
      }
    }

    if (removed == null) {
      return current;
    }

    final updated = current.where((item) => item.id != itemId).toList();
    final promoted = removed.isActive
        ? _promoteNextBacklog(
            updated,
            domain: removed.domain,
            now: now,
          )
        : updated;
    final sorted = sortItems(promoted);
    await _saveItems(sorted);
    return sorted;
  }

  static DigestQueueItem? findActiveForDomain(
    Iterable<DigestQueueItem> items,
    String domain,
  ) {
    for (final item in items) {
      if (item.domain == domain && item.isActive) {
        return item;
      }
    }
    return null;
  }

  static List<DigestQueueItem> backlogItems(Iterable<DigestQueueItem> items) {
    return items.where((item) => item.isBacklog).toList();
  }

  static List<DigestQueueItem> completedItems(Iterable<DigestQueueItem> items) {
    return items.where((item) => item.isCompleted).toList();
  }

  static List<DigestQueueItem> sortItems(Iterable<DigestQueueItem> items) {
    final sorted = items.toList()
      ..sort((a, b) {
        final statusRank = _statusRank(a.status).compareTo(_statusRank(b.status));
        if (statusRank != 0) {
          return statusRank;
        }
        if (a.status == DigestItemStatus.completed) {
          return b.updatedAt.compareTo(a.updatedAt);
        }
        return a.createdAt.compareTo(b.createdAt);
      });
    return sorted;
  }

  Future<void> _saveItems(List<DigestQueueItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  List<DigestQueueItem> _promoteNextBacklog(
    List<DigestQueueItem> items, {
    required String domain,
    required DateTime now,
  }) {
    final nextIndex = items.indexWhere(
      (item) => item.domain == domain && item.isBacklog,
    );
    if (nextIndex == -1) {
      return items;
    }

    final nextItems = List<DigestQueueItem>.from(items);
    final next = nextItems[nextIndex];
    nextItems[nextIndex] = next.copyWith(
      status: DigestItemStatus.active,
      updatedAt: now,
    );
    return nextItems;
  }

  static int _statusRank(DigestItemStatus status) {
    switch (status) {
      case DigestItemStatus.active:
        return 0;
      case DigestItemStatus.backlog:
        return 1;
      case DigestItemStatus.completed:
        return 2;
    }
  }
}
