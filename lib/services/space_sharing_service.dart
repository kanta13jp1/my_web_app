import 'package:supabase_flutter/supabase_flutter.dart';

enum SpacePermission {
  owner,
  fullAccess,
  edit,
  view;

  String get databaseValue => switch (this) {
        SpacePermission.owner => 'owner',
        SpacePermission.fullAccess => 'full_access',
        SpacePermission.edit => 'edit',
        SpacePermission.view => 'view',
      };

  String get label => switch (this) {
        SpacePermission.owner => '所有者',
        SpacePermission.fullAccess => 'フルアクセス',
        SpacePermission.edit => '編集可',
        SpacePermission.view => '閲覧のみ',
      };

  bool get canEdit => this != SpacePermission.view;
  bool get canManage =>
      this == SpacePermission.owner || this == SpacePermission.fullAccess;

  static SpacePermission fromDatabase(String value) => switch (value) {
        'owner' => SpacePermission.owner,
        'full_access' => SpacePermission.fullAccess,
        'edit' => SpacePermission.edit,
        'view' => SpacePermission.view,
        _ => throw FormatException('Unsupported Space permission: $value'),
      };
}

class SpaceMemberRecord {
  const SpaceMemberRecord({
    required this.userId,
    required this.email,
    required this.permission,
  });

  final String userId;
  final String email;
  final SpacePermission permission;

  factory SpaceMemberRecord.fromJson(Map<String, dynamic> json) =>
      SpaceMemberRecord(
        userId: json['member_user_id']?.toString() ?? '',
        email: json['member_email']?.toString() ?? '',
        permission: SpacePermission.fromDatabase(
          json['permission']?.toString() ?? '',
        ),
      );
}

class SpaceInvitationRecord {
  const SpaceInvitationRecord({
    required this.id,
    required this.spaceId,
    required this.spaceName,
    required this.email,
    required this.permission,
  });

  final String id;
  final int spaceId;
  final String spaceName;
  final String email;
  final SpacePermission permission;

  factory SpaceInvitationRecord.fromJson(Map<String, dynamic> json) {
    final spaceId = int.tryParse(json['space_id']?.toString() ?? '');
    if (spaceId == null) {
      throw StateError('Space invitation is missing its Space id.');
    }
    return SpaceInvitationRecord(
      id: json['id']?.toString() ?? '',
      spaceId: spaceId,
      spaceName: json['space_name']?.toString() ?? '',
      email: json['invitee_email']?.toString() ?? '',
      permission: SpacePermission.fromDatabase(
        json['permission']?.toString() ?? '',
      ),
    );
  }
}

class SpaceNotebookRecord {
  const SpaceNotebookRecord({required this.id, required this.name});

  final int id;
  final String name;
}

class SpaceNoteRecord {
  const SpaceNoteRecord({
    required this.id,
    required this.title,
    required this.createdBy,
    required this.updatedAt,
    this.notebookId,
  });

  final int id;
  final String title;
  final String createdBy;
  final DateTime updatedAt;
  final int? notebookId;

  factory SpaceNoteRecord.fromJson(Map<String, dynamic> json) {
    final id = int.tryParse(json['id']?.toString() ?? '');
    if (id == null) throw StateError('Shared note id is missing.');
    return SpaceNoteRecord(
      id: id,
      title: json['title']?.toString() ?? '',
      createdBy: json['created_by']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      notebookId:
          int.tryParse(json['notebook_collection_id']?.toString() ?? ''),
    );
  }
}

class SpaceAccessRecord {
  const SpaceAccessRecord({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.permission,
    required this.members,
    required this.pendingInvitations,
    required this.notebooks,
    required this.notes,
  });

  final int id;
  final String ownerId;
  final String name;
  final String description;
  final SpacePermission permission;
  final List<SpaceMemberRecord> members;
  final List<SpaceInvitationRecord> pendingInvitations;
  final List<SpaceNotebookRecord> notebooks;
  final List<SpaceNoteRecord> notes;
}

class SpaceSharingSnapshot {
  const SpaceSharingSnapshot({
    required this.spaces,
    required this.incomingInvitations,
    required this.currentUserId,
  });

  final List<SpaceAccessRecord> spaces;
  final List<SpaceInvitationRecord> incomingInvitations;
  final String currentUserId;
}

abstract class SpaceSharingDataSource {
  Future<SpaceSharingSnapshot> load();

  Future<void> invite({
    required int spaceId,
    required String email,
    required SpacePermission permission,
  });

  Future<void> acceptInvitation(String invitationId);

  Future<void> declineInvitation(String invitationId);

  Future<void> revokeInvitation(String invitationId);

  Future<void> updateMemberPermission({
    required int spaceId,
    required String memberUserId,
    required SpacePermission permission,
  });

  Future<void> removeMember({
    required int spaceId,
    required String memberUserId,
  });

  Future<int> createDirectNote({
    required int spaceId,
    String title,
    String content,
  });

  Future<void> moveNote({
    required int noteId,
    int? destinationNotebookId,
  });
}

class SupabaseSpaceSharingDataSource implements SpaceSharingDataSource {
  SupabaseSpaceSharingDataSource(this._client);

  static const int _pageSize = 500;
  final SupabaseClient _client;

  @override
  Future<SpaceSharingSnapshot> load() async {
    final currentUserId = _requireUserId();
    final results = await Future.wait<List<Map<String, dynamic>>>([
      _fetchPaged(
        'note_collections',
        'id,user_id,parent_id,collection_type,name,description',
      ),
      _fetchPaged(
        'note_space_members',
        'space_id,member_user_id,member_email,permission',
      ),
      _fetchPaged(
        'note_space_invitations',
        'id,space_id,space_name,invitee_email,permission,status',
      ),
      _fetchPaged(
        'notes',
        'id,created_by,title,notebook_collection_id,space_collection_id,'
            'updated_at,is_archived',
      ),
    ]);

    final collections = results[0];
    final members = results[1];
    final invitations = results[2]
        .where((row) => row['status'] == 'pending')
        .map(SpaceInvitationRecord.fromJson)
        .toList(growable: false);
    final spaces = collections
        .where((row) => row['collection_type'] == 'space')
        .toList(growable: false);
    final parentById = <int, int?>{};
    final typeById = <int, String>{};
    for (final row in collections) {
      final id = int.tryParse(row['id']?.toString() ?? '');
      if (id == null) continue;
      parentById[id] = int.tryParse(row['parent_id']?.toString() ?? '');
      typeById[id] = row['collection_type']?.toString() ?? '';
    }

    int? resolveSpaceId(Map<String, dynamic> row) {
      var id = int.tryParse(row['id']?.toString() ?? '');
      final visited = <int>{};
      while (id != null && visited.add(id)) {
        if (typeById[id] == 'space') return id;
        id = parentById[id];
      }
      return null;
    }

    final records = <SpaceAccessRecord>[];
    for (final space in spaces) {
      final id = int.tryParse(space['id']?.toString() ?? '');
      if (id == null) continue;
      final ownerId = space['user_id']?.toString() ?? '';
      final spaceMembers = members
          .where((row) => int.tryParse(row['space_id']?.toString() ?? '') == id)
          .map(SpaceMemberRecord.fromJson)
          .toList(growable: false)
        ..sort((left, right) => left.email.compareTo(right.email));
      final member = spaceMembers
          .where((item) => item.userId == currentUserId)
          .firstOrNull;
      final permission =
          ownerId == currentUserId ? SpacePermission.owner : member?.permission;
      if (permission == null) continue;

      final notebooks = collections
          .where(
            (row) =>
                row['collection_type'] == 'notebook' &&
                resolveSpaceId(row) == id,
          )
          .map(
            (row) => SpaceNotebookRecord(
              id: int.parse(row['id'].toString()),
              name: row['name']?.toString() ?? '',
            ),
          )
          .toList(growable: false)
        ..sort((left, right) => left.name.compareTo(right.name));
      final notes = results[3]
          .where(
            (row) =>
                row['is_archived'] != true &&
                int.tryParse(row['space_collection_id']?.toString() ?? '') ==
                    id,
          )
          .map(SpaceNoteRecord.fromJson)
          .toList(growable: false)
        ..sort((left, right) {
          final updated = right.updatedAt.compareTo(left.updatedAt);
          return updated != 0 ? updated : right.id.compareTo(left.id);
        });
      records.add(
        SpaceAccessRecord(
          id: id,
          ownerId: ownerId,
          name: space['name']?.toString() ?? '',
          description: space['description']?.toString() ?? '',
          permission: permission,
          members: List<SpaceMemberRecord>.unmodifiable(spaceMembers),
          pendingInvitations: List<SpaceInvitationRecord>.unmodifiable(
            invitations.where((item) => item.spaceId == id),
          ),
          notebooks: List<SpaceNotebookRecord>.unmodifiable(notebooks),
          notes: List<SpaceNoteRecord>.unmodifiable(notes),
        ),
      );
    }
    records.sort((left, right) => left.name.compareTo(right.name));

    final visibleSpaceIds = records.map((item) => item.id).toSet();
    return SpaceSharingSnapshot(
      spaces: List<SpaceAccessRecord>.unmodifiable(records),
      incomingInvitations: List<SpaceInvitationRecord>.unmodifiable(
        invitations.where((item) => !visibleSpaceIds.contains(item.spaceId)),
      ),
      currentUserId: currentUserId,
    );
  }

  @override
  Future<void> invite({
    required int spaceId,
    required String email,
    required SpacePermission permission,
  }) async {
    if (!permission.canManage && permission != SpacePermission.edit) {
      if (permission != SpacePermission.view) {
        throw ArgumentError('The owner permission cannot be assigned.');
      }
    }
    if (permission == SpacePermission.owner) {
      throw ArgumentError('The owner permission cannot be assigned.');
    }
    final normalized = email.trim().toLowerCase();
    if (!_emailPattern.hasMatch(normalized) || normalized.length > 320) {
      throw ArgumentError('有効なメールアドレスを入力してください。');
    }
    await _client.rpc(
      'invite_to_note_space',
      params: <String, dynamic>{
        'p_space_id': spaceId,
        'p_invitee_email': normalized,
        'p_permission': permission.databaseValue,
      },
    );
  }

  @override
  Future<void> acceptInvitation(String invitationId) async {
    await _client.rpc(
      'accept_note_space_invitation',
      params: <String, dynamic>{'p_invitation_id': invitationId},
    );
  }

  @override
  Future<void> declineInvitation(String invitationId) async {
    await _client.rpc(
      'decline_note_space_invitation',
      params: <String, dynamic>{'p_invitation_id': invitationId},
    );
  }

  @override
  Future<void> revokeInvitation(String invitationId) async {
    await _client.rpc(
      'revoke_note_space_invitation',
      params: <String, dynamic>{'p_invitation_id': invitationId},
    );
  }

  @override
  Future<void> updateMemberPermission({
    required int spaceId,
    required String memberUserId,
    required SpacePermission permission,
  }) async {
    if (permission == SpacePermission.owner) {
      throw ArgumentError('The owner permission cannot be assigned.');
    }
    await _client.rpc(
      'update_note_space_member_permission',
      params: <String, dynamic>{
        'p_space_id': spaceId,
        'p_member_user_id': memberUserId,
        'p_permission': permission.databaseValue,
      },
    );
  }

  @override
  Future<void> removeMember({
    required int spaceId,
    required String memberUserId,
  }) async {
    await _client.rpc(
      'remove_note_space_member',
      params: <String, dynamic>{
        'p_space_id': spaceId,
        'p_member_user_id': memberUserId,
      },
    );
  }

  @override
  Future<int> createDirectNote({
    required int spaceId,
    String title = '',
    String content = '',
  }) async {
    final response = await _client.rpc(
      'create_note_in_space',
      params: <String, dynamic>{
        'p_space_id': spaceId,
        'p_title': title.trim(),
        'p_content': content,
        'p_notebook_collection_id': null,
      },
    );
    final id = int.tryParse(response?.toString() ?? '');
    if (id == null) throw StateError('共有ノートを作成できませんでした。');
    return id;
  }

  @override
  Future<void> moveNote({
    required int noteId,
    int? destinationNotebookId,
  }) async {
    await _client.rpc(
      'move_note_within_space',
      params: <String, dynamic>{
        'p_note_id': noteId,
        'p_destination_notebook_id': destinationNotebookId,
      },
    );
  }

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.trim().isEmpty) {
      throw StateError('Spaceを管理するにはサインインしてください。');
    }
    return id;
  }

  Future<List<Map<String, dynamic>>> _fetchPaged(
    String table,
    String columns,
  ) async {
    final result = <Map<String, dynamic>>[];
    for (var from = 0;; from += _pageSize) {
      final response = await _client
          .from(table)
          .select(columns)
          .range(from, from + _pageSize - 1);
      final page = List<Map<String, dynamic>>.from(response);
      result.addAll(page);
      if (page.length < _pageSize) break;
    }
    return result;
  }

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
