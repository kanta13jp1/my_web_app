import 'package:flutter/material.dart';

import '../models/chat_subsession.dart';

class ChatSubsessionTabBar extends StatelessWidget {
  const ChatSubsessionTabBar({
    super.key,
    required this.sessions,
    required this.activeSessionId,
    required this.onSelectSession,
    required this.onCreateSubsession,
  });

  final List<ChatSubsession> sessions;
  final String activeSessionId;
  final ValueChanged<String> onSelectSession;
  final VoidCallback onCreateSubsession;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('chat_subsession_tab_bar'),
      width: double.infinity,
      color: const Color(0xFF141423),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final session in sessions)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Semantics(
                        button: true,
                        selected: session.id == activeSessionId,
                        label: session.isChildSession
                            ? '${session.title} (親セッションからの派生)'
                            : session.title,
                        child: ChoiceChip(
                          key: Key('ai_chat_subsession_tab_${session.id}'),
                          selected: session.id == activeSessionId,
                          avatar: Icon(
                            session.isChildSession
                                ? Icons.subdirectory_arrow_right
                                : Icons.chat_bubble_outline,
                            size: 14,
                            color: session.id == activeSessionId
                                ? Colors.white
                                : Colors.white70,
                          ),
                          label: Text(
                            '${session.title} (${session.messages.length})',
                            style: TextStyle(
                              fontSize: 12,
                              color: session.id == activeSessionId
                                  ? Colors.white
                                  : Colors.white70,
                            ),
                          ),
                          selectedColor: const Color(0xFFFF6B35),
                          backgroundColor: const Color(0xFF1E1E32),
                          side: BorderSide(
                            color: session.id == activeSessionId
                                ? const Color(0xFFFF6B35)
                                : Colors.white24,
                          ),
                          onSelected: (_) => onSelectSession(session.id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          ActionChip(
            key: const Key('ai_chat_create_subsession_button'),
            avatar: const Icon(
              Icons.add,
              size: 16,
              color: Color(0xFFFF6B35),
            ),
            label: const Text(
              'サブセッション',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: const Color(0xFF262642),
            side: const BorderSide(color: Color(0xFFFF6B35)),
            onPressed: onCreateSubsession,
          ),
        ],
      ),
    );
  }
}
