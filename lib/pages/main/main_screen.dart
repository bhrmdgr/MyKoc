import 'package:flutter/material.dart';
import 'package:mykoc/pages/home/homeView.dart'; // ← Değişti
import 'package:mykoc/pages/calendar/calendar_view.dart';
import 'package:mykoc/pages/communication/messages/messages_view.dart';
import 'package:mykoc/pages/profile/profile_view.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeView(),
    const CalendarView(),
    const MessagesView(),
    const ProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // ← 8'den 4'e düştü
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.calendar_today_rounded,
                  label: 'Calendar',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Messages',
                  index: 2,
                ),
                _buildNavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  index: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // ← Padding azaltıldı
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active indicator
            Container(
              height: 2, // ← 3'ten 2'ye düştü
              width: 32, // ← 40'tan 32'ye düştü
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6), // ← 8'den 6'ya düştü
            // Icon
            Icon(
              icon,
              size: 26, // ← 26'dan 24'e düştü
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 2), // ← 4'ten 2'ye düştü
            // Label
            Text(
              label,
              style: TextStyle(
                fontSize: 11, // ← 12'den 11'e düştü
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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