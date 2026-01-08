import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mykoc/pages/home/homeView.dart';
import 'package:mykoc/pages/calendar/calendar_view.dart';
import 'package:mykoc/pages/communication/messages/messages_view.dart';
import 'package:mykoc/pages/profile/profile_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';
import 'dart:async'; // Stream birleştirme için gerekirse

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final LocalStorageService _storage = LocalStorageService();

  final List<Widget> _pages = [
    const HomeView(),
    const CalendarView(),
    const MessagesView(),
    const ProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    final String? uid = _storage.getUid();

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 100),
            child: _pages[_currentIndex],
          ),
          // StreamBuilder ile mesaj ve takvim bildirimlerini yönetiyoruz
          _buildNotificationListener(uid),
        ],
      ),
    );
  }

  Widget _buildNotificationListener(String? uid) {
    if (uid == null) return _buildHighContrastTabBar(0, false);

    return StreamBuilder<int>(
      stream: _getUnreadMessagesCount(uid),
      builder: (context, messageSnapshot) {
        return StreamBuilder<bool>(
          stream: _getTodayTaskStatus(uid),
          builder: (context, taskSnapshot) {
            final int unreadCount = messageSnapshot.data ?? 0;
            final bool hasTaskToday = taskSnapshot.data ?? false;

            return _buildHighContrastTabBar(unreadCount, hasTaskToday);
          },
        );
      },
    );
  }

  // MESAJLAR: chatRooms içindeki map yapısına göre okur
  Stream<int> _getUnreadMessagesCount(String uid) {
    return FirebaseFirestore.instance
        .collection('chatRooms')
        .where('participantIds', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final unreadMap = data['unreadCount'] as Map<String, dynamic>?;
        if (unreadMap != null && unreadMap.containsKey(uid)) {
          total += (unreadMap[uid] as num).toInt();
        }
      }
      return total;
    });
  }

  // TAKVİM: Bugün teslim tarihi olan bir task var mı?
  Stream<bool> _getTodayTaskStatus(String uid) {
    return FirebaseFirestore.instance
        .collection('tasks')
        .where('assignedTo', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      return snapshot.docs.any((doc) {
        final timestamp = doc.data()['dueDate'] as Timestamp?;
        if (timestamp == null) return false;
        final dueDate = timestamp.toDate();
        return dueDate.day == now.day &&
            dueDate.month == now.month &&
            dueDate.year == now.year;
      });
    });
  }

  Widget _buildHighContrastTabBar(int unreadMessages, bool showCalendarAlert) {
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildEliteNavItem(Icons.home_rounded, 'nav_home'.tr(), 0),
              _buildEliteNavItem(
                  Icons.calendar_today_rounded, 'nav_calendar'.tr(), 1,
                  hasAlert: showCalendarAlert),
              _buildEliteNavItem(Icons.chat_bubble_rounded, 'nav_messages'.tr(), 2,
                  badgeCount: unreadMessages),
              _buildEliteNavItem(Icons.person_rounded, 'nav_profile'.tr(), 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEliteNavItem(IconData icon, String label, int index,
      {int badgeCount = 0, bool hasAlert = false}) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              width: isSelected ? 24 : 0,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 8),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 26,
                  color: isSelected
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF9CA3AF),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        badgeCount > 9 ? '9+' : badgeCount.toString(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                if (hasAlert && !isSelected)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}