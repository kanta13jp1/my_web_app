import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/musubi_engagement_models.dart';
import 'package:my_web_app/models/musubi_social_models.dart';
import 'package:my_web_app/services/musubi_engagement_controllers.dart';
import 'package:my_web_app/services/musubi_engagement_repository.dart';
import 'package:my_web_app/services/musubi_social_controller.dart';
import 'package:my_web_app/services/musubi_social_repository.dart';

void main() {
  group('MUSUBI realtime and engagement ViewModels', () {
    test('realtime feed moves from connecting to connected', () async {
      final realtime = _FakeRealtimeRepository();
      final controller = MusubiSocialController(
        repository: PreviewMusubiSocialRepository(),
        realtimeRepository: realtime,
      );
      addTearDown(() async {
        controller.dispose();
        await realtime.close();
      });

      await controller.initialize();
      expect(controller.realtimeState, MusubiRealtimeState.connecting);

      realtime.add(<MusubiPost>[
        _post(id: 'live-1', content: 'リアルタイムで届いた投稿'),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(controller.realtimeState, MusubiRealtimeState.connected);
      expect(
        controller.visiblePosts.map((post) => post.id),
        contains('live-1'),
      );
    });

    test('discovery searches public context instead of ad profiles', () async {
      final preview = PreviewMusubiEngagementRepository();
      final controller = MusubiDiscoveryController(repository: preview);

      await controller.search('防災');

      expect(controller.results, hasLength(1));
      expect(controller.results.single.postId, 'preview-3');
      expect(controller.notice, isNull);
    });

    test('messages load a thread and append a sent message', () async {
      final preview = PreviewMusubiEngagementRepository();
      final controller = MusubiMessagesController(repository: preview);
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(controller.activeConversation, isNotNull);
      final before = controller.messages.length;

      expect(await controller.sendMessage('確認ありがとうございます'), isTrue);
      expect(controller.messages, hasLength(before + 1));
      expect(controller.messages.last.body, '確認ありがとうございます');
      expect(controller.messages.last.isMine, isTrue);
    });

    test('reports enter the moderation queue and can be resolved', () async {
      final preview = PreviewMusubiEngagementRepository();
      final controller = MusubiTrustController(repository: preview);

      expect(
        await controller.reportPost(
          postId: 'preview-1',
          reason: MusubiReportReason.spam,
        ),
        isTrue,
      );
      expect(controller.queue, hasLength(1));
      expect(controller.queue.single.status, MusubiModerationStatus.open);

      await controller.resolveCase(
        controller.queue.single.id,
        MusubiModerationStatus.resolved,
      );
      expect(controller.queue.single.status, MusubiModerationStatus.resolved);
    });

    test('research feedback is blocked until explicit consent', () async {
      final repository = _RecordingResearchRepository();
      final controller = MusubiResearchController(repository: repository);

      await controller.initialize();
      await controller.record('musubi.opened');
      expect(repository.events, isEmpty);

      expect(await controller.submit('まだ同意していない'), isFalse);
      expect(repository.feedback, isNull);

      controller.setConsent(true);
      controller.setFatigue(2);
      controller.setTrust(5);
      expect(await controller.submit('安心して読めた'), isTrue);

      expect(repository.feedback?.fatigue, 2);
      expect(repository.feedback?.trust, 5);
      expect(repository.feedback?.consentToResearch, isTrue);
      expect(repository.feedback?.cohort, musubiFirstUserCohort);
      expect(
        repository.feedback?.consentVersion,
        musubiResearchConsentVersion,
      );
      expect(controller.hasActiveConsent, isTrue);

      await controller.record('musubi.destination.opened');
      expect(repository.events, hasLength(1));
      expect(repository.events.single.cohort, musubiFirstUserCohort);

      await controller.withdraw();
      expect(repository.withdrawn, isTrue);
      expect(controller.consent, isFalse);
      expect(controller.hasActiveConsent, isFalse);
      expect(repository.events, isEmpty);

      await controller.record('musubi.opened');
      expect(repository.events, isEmpty);
    });

    test('withdrawal stops new events before remote deletion completes',
        () async {
      final deletionGate = Completer<void>();
      final repository = _RecordingResearchRepository(
        persistedConsent: MusubiResearchConsent(
          cohort: musubiFirstUserCohort,
          consentVersion: musubiResearchConsentVersion,
          consentedAt: DateTime(2026, 8, 13),
        ),
        deletionGate: deletionGate,
      );
      final controller = MusubiResearchController(repository: repository);

      await controller.initialize();
      expect(controller.hasActiveConsent, isTrue);

      final withdrawal = controller.withdraw();
      await controller.record('musubi.withdrawal.race');
      expect(repository.events, isEmpty);

      deletionGate.complete();
      await withdrawal;
      expect(controller.hasActiveConsent, isFalse);
    });
  });
}

MusubiPost _post({required String id, required String content}) {
  return MusubiPost(
    id: id,
    authorName: 'Live User',
    handle: '@live',
    avatarLabel: 'L',
    content: content,
    createdAt: DateTime.now(),
    community: 'パブリック',
    lenses: const <MusubiFeedLens>{MusubiFeedLens.resonance},
    resonance: 90,
  );
}

class _FakeRealtimeRepository implements MusubiRealtimeRepository {
  final _controller = StreamController<List<MusubiPost>>();

  @override
  bool get isPreview => false;

  @override
  Stream<List<MusubiPost>> watchFeed() => _controller.stream;

  void add(List<MusubiPost> posts) => _controller.add(posts);

  Future<void> close() => _controller.close();
}

class _RecordingResearchRepository implements MusubiResearchRepository {
  _RecordingResearchRepository({this.persistedConsent, this.deletionGate});

  MusubiResearchFeedback? feedback;
  final MusubiResearchConsent? persistedConsent;
  final Completer<void>? deletionGate;
  bool withdrawn = false;
  final List<MusubiResearchEvent> events = <MusubiResearchEvent>[];

  @override
  Future<MusubiResearchConsent?> loadConsent() async => persistedConsent;

  @override
  Future<void> recordEvent(MusubiResearchEvent event) async {
    events.add(event);
  }

  @override
  Future<void> submitFeedback(MusubiResearchFeedback feedback) async {
    this.feedback = feedback;
  }

  @override
  Future<void> withdrawResearchData() async {
    await deletionGate?.future;
    withdrawn = true;
    feedback = null;
    events.clear();
  }
}
