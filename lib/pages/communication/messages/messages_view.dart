import 'package:flutter/material.dart';

class MessagesView extends StatelessWidget {
  const MessagesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: const Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // Conversations List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildConversationItem(
                  emoji: '📚',
                  title: 'English Literature',
                  subtitle: 'Sarah: Don\'t forget about ...',
                  time: '10 min ago',
                  unreadCount: 3,
                  color: const Color(0xFF3B82F6),
                  hasGroup: true,
                ),
                _buildConversationItem(
                  initials: 'SJ',
                  title: 'Sarah Johnson',
                  subtitle: 'Great work on your essay!',
                  time: '1 hour ago',
                  color: const Color(0xFF9CA3AF),
                ),
                _buildConversationItem(
                  emoji: '🎨',
                  title: 'Design Fundament...',
                  subtitle: 'Alex: Here\'s my logo con...',
                  time: '2 hours ago',
                  unreadCount: 1,
                  color: const Color(0xFF8B5CF6),
                  hasGroup: true,
                ),
                _buildConversationItem(
                  emoji: '💻',
                  title: 'Web Development',
                  subtitle: 'Michael: Check out this tut...',
                  time: 'Yesterday',
                  color: const Color(0xFF10B981),
                  hasGroup: true,
                ),
                _buildConversationItem(
                  initials: 'EC',
                  title: 'Dr. Emily Chen',
                  subtitle: 'Can we schedule a meetin...',
                  time: '2 days ago',
                  color: const Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationItem({
    String? emoji,
    String? initials,
    required String title,
    required String subtitle,
    required String time,
    int? unreadCount,
    required Color color,
    bool hasGroup = false,
  }) {
    return InkWell(
      onTap: () {
        // TODO: Navigate to chat detail
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: emoji != null
                        ? Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    )
                        : Text(
                      initials ?? '',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
                // Unread badge
                if (unreadCount != null && unreadCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Center(
                        child: Text(
                          unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (emoji != null) ...[
                        Text(
                          emoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasGroup) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.people_outline_rounded,
                          size: 16,
                          color: Colors.grey[500],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: unreadCount != null && unreadCount > 0
                          ? const Color(0xFF6B7280)
                          : Colors.grey[500],
                      fontWeight: unreadCount != null && unreadCount > 0
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Time
            Text(
              time,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}