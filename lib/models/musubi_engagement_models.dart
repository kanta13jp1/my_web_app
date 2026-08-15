enum MusubiRealtimeState { preview, connecting, connected, degraded }

const String musubiFirstUserCohort = 'first-user-2026-08';
const String musubiResearchConsentVersion = '2026-08-13-v1';

enum MusubiSearchKind { post, person, community }

class MusubiSearchResult {
  const MusubiSearchResult({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.highlight,
    this.authorId,
    this.postId,
  });

  final String id;
  final MusubiSearchKind kind;
  final String title;
  final String subtitle;
  final String? highlight;
  final String? authorId;
  final String? postId;
}

class MusubiConversation {
  const MusubiConversation({
    required this.id,
    required this.title,
    required this.handle,
    required this.avatarLabel,
    required this.lastMessage,
    required this.updatedAt,
    this.participantId,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  final String id;
  final String title;
  final String handle;
  final String avatarLabel;
  final String lastMessage;
  final DateTime updatedAt;
  final String? participantId;
  final int unreadCount;
  final bool isOnline;
}

enum MusubiMessageDelivery { sending, sent, failed }

class MusubiDirectMessage {
  const MusubiDirectMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.isMine,
    this.delivery = MusubiMessageDelivery.sent,
  });

  final String id;
  final String threadId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final bool isMine;
  final MusubiMessageDelivery delivery;

  MusubiDirectMessage copyWith({MusubiMessageDelivery? delivery}) {
    return MusubiDirectMessage(
      id: id,
      threadId: threadId,
      senderId: senderId,
      body: body,
      createdAt: createdAt,
      isMine: isMine,
      delivery: delivery ?? this.delivery,
    );
  }
}

enum MusubiReportReason {
  harassment,
  hate,
  misinformation,
  impersonation,
  spam,
  selfHarm,
  other,
}

enum MusubiModerationStatus { open, reviewing, resolved, dismissed }

class MusubiModerationCase {
  const MusubiModerationCase({
    required this.id,
    required this.targetPostId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.details = '',
    this.targetExcerpt = '',
    this.reportCount = 1,
  });

  final String id;
  final String targetPostId;
  final MusubiReportReason reason;
  final MusubiModerationStatus status;
  final DateTime createdAt;
  final String details;
  final String targetExcerpt;
  final int reportCount;

  MusubiModerationCase copyWith({MusubiModerationStatus? status}) {
    return MusubiModerationCase(
      id: id,
      targetPostId: targetPostId,
      reason: reason,
      status: status ?? this.status,
      createdAt: createdAt,
      details: details,
      targetExcerpt: targetExcerpt,
      reportCount: reportCount,
    );
  }
}

class MusubiResearchFeedback {
  const MusubiResearchFeedback({
    required this.fatigue,
    required this.trust,
    required this.belonging,
    required this.consentToResearch,
    this.comment = '',
    this.cohort = musubiFirstUserCohort,
    this.consentVersion = musubiResearchConsentVersion,
  });

  final int fatigue;
  final int trust;
  final int belonging;
  final bool consentToResearch;
  final String comment;
  final String cohort;
  final String consentVersion;
}

class MusubiResearchConsent {
  const MusubiResearchConsent({
    required this.cohort,
    required this.consentVersion,
    required this.consentedAt,
  });

  final String cohort;
  final String consentVersion;
  final DateTime consentedAt;
}

class MusubiResearchEvent {
  const MusubiResearchEvent({
    required this.name,
    this.properties = const <String, Object?>{},
    this.cohort = musubiFirstUserCohort,
    this.consentVersion = musubiResearchConsentVersion,
  });

  final String name;
  final Map<String, Object?> properties;
  final String cohort;
  final String consentVersion;
}
