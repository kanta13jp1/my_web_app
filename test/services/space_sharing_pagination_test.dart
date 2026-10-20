import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/space_sharing_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('sharing loads all four tables past server-capped pages', () async {
    const owner = '11111111-1111-4111-8111-111111111111';
    final offsets = <String, List<int>>{};
    final client = SupabaseClient(
      'https://sharing-fixture.invalid',
      'fixture-key',
      httpClient: MockClient((request) async {
        Object response;
        if (request.url.path.contains('/auth/')) {
          response = <String, dynamic>{
            'access_token': 'fixture-token',
            'refresh_token': 'fixture-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': <String, dynamic>{
              'id': owner,
              'aud': 'authenticated',
              'email': 'owner@example.invalid',
              'app_metadata': <String, dynamic>{},
              'user_metadata': <String, dynamic>{},
              'created_at': '2026-01-01T00:00:00Z',
            },
          };
        } else {
          final table = request.url.pathSegments.last;
          expect(
            <String>[
              'note_collections',
              'note_space_members',
              'note_space_invitations',
              'notes',
            ],
            contains(table),
          );
          expect(
            request.url.queryParameters['order'],
            table == 'note_space_members'
                ? 'space_id.asc,member_user_id.asc'
                : 'id.asc',
          );
          final offset = int.parse(request.url.queryParameters['offset']!);
          expect(request.url.queryParameters['limit'], '500');
          offsets.putIfAbsent(table, () => <int>[]).add(offset);
          final remaining = 120 - offset;
          final count = remaining > 50 ? 50 : remaining;
          response = List<Map<String, dynamic>>.generate(count, (index) {
            final id = offset + index + 1;
            return switch (table) {
              'note_collections' => <String, dynamic>{
                  'id': id,
                  'user_id': owner,
                  'collection_type': 'space',
                  'name': 'Space $id',
                },
              'note_space_members' => <String, dynamic>{
                  'space_id': 1,
                  'member_user_id': 'member-$id',
                  'member_email': 'member-$id@example.invalid',
                  'permission': 'view',
                },
              'note_space_invitations' => <String, dynamic>{
                  'id': 'invitation-$id',
                  'space_id': 1,
                  'space_name': 'Space 1',
                  'invitee_email': 'invite-$id@example.invalid',
                  'permission': 'view',
                  'status': 'pending',
                },
              _ => <String, dynamic>{
                  'id': id,
                  'created_by': owner,
                  'title': 'Note $id',
                  'space_collection_id': 1,
                  'updated_at': '2026-01-01T00:00:00Z',
                  'is_archived': false,
                },
            };
          });
        }
        return http.Response(
          jsonEncode(response),
          200,
          request: request,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(
      email: 'owner@example.invalid',
      password: 'fixture-only',
    );

    final result = await SupabaseSpaceSharingDataSource(client).load();

    expect(result.spaces, hasLength(120));
    final space = result.spaces.singleWhere((item) => item.id == 1);
    expect(space.members, hasLength(120));
    expect(space.pendingInvitations, hasLength(120));
    expect(space.notes, hasLength(120));
    expect(space.notes.any((item) => item.id == 120), isTrue);
    expect(offsets, hasLength(4));
    for (final pages in offsets.values) {
      expect(pages, <int>[0, 50, 100, 120]);
    }
  });
}
