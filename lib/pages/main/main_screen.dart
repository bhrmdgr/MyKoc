import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:mykoc/pages/home/homeView.dart';
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
      extendBody: true, // İçeriğin şeffaf kısımlardan görünmesi için açık kalmalı
      body: Stack(
        children: [
          // Sayfa içeriklerini sarıyoruz
          Padding(
            padding: const EdgeInsets.only(bottom: 100), // TabBar yüksekliği + boşluk
            child: _pages[_currentIndex],
          ),
          _buildHighContrastTabBar(),
        ],
      ),
    );
  }

  Widget _buildHighContrastTabBar() {
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          // Beyaz sayfada belirginlik için daha keskin bir border ve gölge
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
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildEliteNavItem(Icons.home_rounded, 'nav_home'.tr(), 0),
              _buildEliteNavItem(Icons.calendar_today_rounded, 'nav_calendar'.tr(), 1),
              _buildEliteNavItem(Icons.chat_bubble_rounded, 'nav_messages'.tr(), 2),
              _buildEliteNavItem(Icons.person_rounded, 'nav_profile'.tr(), 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEliteNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Mor Çizgi (Üstte)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              width: isSelected ? 24 : 0,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.4),
                    blurRadius: 8,
                  ),
                ]
                    : [],
              ),
            ),

            const SizedBox(height: 8),

            // İkon
            Icon(
              icon,
              size: 26,
              color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF9CA3AF),
            ),

            const SizedBox(height: 4),

            // Yazı (Her zaman görünür)
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}