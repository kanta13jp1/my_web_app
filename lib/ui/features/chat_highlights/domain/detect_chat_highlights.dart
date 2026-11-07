import 'dart:math' as math;

import 'chat_highlight_models.dart';

class DetectChatHighlights {
  const DetectChatHighlights();

  List<ChatHighlightCandidate> call(
    List<ChatHighlightEvent> input,
    ChatHighlightSettings settings, {
    Duration? sourceDuration,
  }) {
    final keywords = settings.keywords
        .map((keyword) => keyword.trim().toLowerCase())
        .where((keyword) => keyword.isNotEmpty)
        .toSet();
    final byId = <String, ChatHighlightEvent>{};
    for (final event in input) {
      if (event.id.isNotEmpty && event.offset >= Duration.zero) {
        byId.putIfAbsent(event.id, () => event);
      }
    }
    final events = byId.values.toList()
      ..sort((left, right) {
        final offsetOrder = left.offset.compareTo(right.offset);
        return offsetOrder != 0 ? offsetOrder : left.id.compareTo(right.id);
      });
    if (events.isEmpty) return const <ChatHighlightCandidate>[];

    final raw = <ChatHighlightCandidate>[];
    var left = 0;
    for (var right = 0; right < events.length; right++) {
      final windowStart =
          events[right].offset - Duration(seconds: settings.windowSeconds);
      while (left < right && events[left].offset < windowStart) {
        left++;
      }
      final window = events.sublist(left, right + 1);
      final matched = <String>{};
      var keywordEvents = 0;
      for (final event in window) {
        final message = event.message.toLowerCase();
        final eventMatches = keywords.where(message.contains).toSet();
        if (eventMatches.isNotEmpty) keywordEvents++;
        matched.addAll(eventMatches);
      }
      final triggers = <ChatHighlightTrigger>{};
      if (window.length >= settings.minimumComments) {
        triggers.add(ChatHighlightTrigger.commentBurst);
      }
      if (keywordEvents >= settings.minimumKeywordEvents) {
        triggers.add(ChatHighlightTrigger.keywordBurst);
      }
      if (triggers.isEmpty) continue;

      final startMs = math.max(
        0,
        window.first.offset.inMilliseconds - settings.preRollSeconds * 1000,
      );
      var endMs =
          events[right].offset.inMilliseconds + settings.postRollSeconds * 1000;
      if (sourceDuration != null) {
        endMs = math.min(endMs, sourceDuration.inMilliseconds);
      }
      if (endMs <= startMs) continue;
      final commentRatio = window.length / settings.minimumComments;
      final keywordRatio = keywordEvents / settings.minimumKeywordEvents;
      raw.add(
        ChatHighlightCandidate(
          start: Duration(milliseconds: startMs),
          end: Duration(milliseconds: endMs),
          peakCommentCount: window.length,
          peakKeywordEventCount: keywordEvents,
          matchedKeywords: matched,
          triggers: triggers,
          score: math.max(commentRatio, keywordRatio),
        ),
      );
    }

    final merged = <ChatHighlightCandidate>[];
    for (final candidate in raw) {
      if (merged.isEmpty || candidate.start > merged.last.end) {
        merged.add(candidate);
        continue;
      }
      final previous = merged.removeLast();
      merged.add(
        ChatHighlightCandidate(
          start: previous.start,
          end: candidate.end > previous.end ? candidate.end : previous.end,
          peakCommentCount: math.max(
            previous.peakCommentCount,
            candidate.peakCommentCount,
          ),
          peakKeywordEventCount: math.max(
            previous.peakKeywordEventCount,
            candidate.peakKeywordEventCount,
          ),
          matchedKeywords: <String>{
            ...previous.matchedKeywords,
            ...candidate.matchedKeywords,
          },
          triggers: <ChatHighlightTrigger>{
            ...previous.triggers,
            ...candidate.triggers,
          },
          score: math.max(previous.score, candidate.score),
        ),
      );
    }
    return List<ChatHighlightCandidate>.unmodifiable(merged);
  }
}
