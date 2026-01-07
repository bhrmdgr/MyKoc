import 'package:easy_localization/easy_localization.dart'; // ← Eklendi
import 'package:flutter/material.dart';
import 'package:mykoc/pages/profile/profile_model.dart';
import 'package:mykoc/pages/profile/profile_view_model.dart';
import 'package:mykoc/pages/classroom/class_model.dart';
import 'package:mykoc/pages/tasks/task_model.dart';
import 'package:mykoc/pages/main/main_screen.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';
import 'package:mykoc/pages/classroom/class_detail/class_detail_view.dart';
import 'package:intl/intl.dart';
import 'package:mykoc/pages/settings/settings_view.dart';
import 'package:mykoc/firebase/messaging/messaging_service.dart';
import 'package:mykoc/pages/communication/chat_room/chat_room_view.dart';

class StudentProfileView extends StatelessWidget {
  final ProfileModel profileData;
  final ProfileViewModel viewModel;

  const StudentProfileView({
    super.key,
    required this.profileData,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildStatsCards(),
            const SizedBox(height: 16),

            if (!viewModel.isMentorViewing)
              _buildJoinClassButton(context),

            if (!viewModel.isMentorViewing)
              const SizedBox(height: 16),

            _buildTabSelector(),
            const SizedBox(height: 16),

            if (viewModel.selectedTab == 'classes')
              _buildClassesList(context)
            else
              _buildTasksList(context),

            const SizedBox(height: 16),

            if (!viewModel.isMentorViewing)

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
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
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // ⚙️ Sağ Üst Ayarlar Butonu
            if (!viewModel.isMentorViewing)
              Positioned(
                top: 0,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 28),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsView()),
                  ),
                ),
              ),

            // 👤 Profil İçeriği (Tam Genişlik ve Merkezi Hizalama)
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // --- Avatar / Profil Resmi ---
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: (profileData.profileImageUrl != null && profileData.profileImageUrl!.isNotEmpty)
                          ? ClipOval(
                        child: Image.network(
                          profileData.profileImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                profileData.userInitials,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                          : Center(
                        child: Text(
                          profileData.userInitials,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Kullanıcı Adı ---
                    Text(
                      profileData.userName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // --- Kullanıcı Rolü ---
                    Text(
                      'profile_student'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),

                    // --- Mentör İzliyorsa Mesaj Butonu ---
                    if (viewModel.isMentorViewing) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 45,
                        child: ElevatedButton.icon(
                          onPressed: () => _openDirectChat(context),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                          label: Text(
                            "send_message".tr(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF6366F1),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final double offsetY = viewModel.isMentorViewing ? -40 : -80;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      transform: Matrix4.translationValues(0, offsetY, 0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => viewModel.switchTab('classes'),
              child: _buildStatCard(
                icon: Icons.school_outlined,
                label: 'stats_classes'.tr(), // ✅ GÜNCELLENDİ
                value: '${profileData.totalClasses ?? 0}',
                color: const Color(0xFF6366F1),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => viewModel.switchTab('tasks'),
              child: _buildStatCard(
                icon: Icons.assignment_outlined,
                label: 'stats_tasks'.tr(), // ✅ GÜNCELLENDİ
                value: '${profileData.totalTasks ?? 0}',
                color: const Color(0xFF8B5CF6),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              child: _buildStatCard(
                icon: Icons.check_circle_outline,
                label: 'stats_completed'.tr(), // ✅ GÜNCELLENDİ
                value: '${profileData.completedTasks ?? 0}',
                color: const Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinClassButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      transform: Matrix4.translationValues(0, -60, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showJoinClassDialog(context),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'join_new_class'.tr(), // ✅ GÜNCELLENDİ
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    final double offsetY = viewModel.isMentorViewing ? -20 : -60;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      transform: Matrix4.translationValues(0, offsetY, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              label: 'tab_classes'.tr(), // ✅ GÜNCELLENDİ
              icon: Icons.school_outlined,
              isSelected: viewModel.selectedTab == 'classes',
              onTap: () => viewModel.switchTab('classes'),
            ),
          ),
          Expanded(
            child: _buildTabButton(
              label: 'tab_tasks'.tr(), // ✅ GÜNCELLENDİ
              icon: Icons.assignment_outlined,
              isSelected: viewModel.selectedTab == 'tasks',
              onTap: () => viewModel.switchTab('tasks'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassesList(BuildContext context) {
    final double offsetY = viewModel.isMentorViewing ? -20 : -60;

    if (viewModel.classes.isEmpty) {
      return Transform.translate(
        offset: Offset(0, offsetY),
        child: _buildEmptyState(
          icon: Icons.school_outlined,
          title: 'no_classes_joined'.tr(), // ✅ GÜNCELLENDİ
          subtitle: viewModel.isMentorViewing
              ? 'no_classes_mentor_view'.tr() // ✅ GÜNCELLENDİ
              : 'no_classes_joined_subtitle'.tr(), // ✅ GÜNCELLENDİ
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      transform: Matrix4.translationValues(0, offsetY, 0),
      child: Column(
        children: viewModel.classes
            .map((classItem) => _buildClassCard(context, classItem))
            .toList(),
      ),
    );
  }

  Widget _buildClassCard(BuildContext context, ClassModel classItem) {
    return GestureDetector(
      onTap: () async {
        if (viewModel.isMentorViewing) return;

        await LocalStorageService().saveActiveClassId(classItem.id);

        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
                (route) => false,
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(classItem.getColorFromType()),
                    Color(classItem.getColorFromType()).withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  classItem.emoji ?? '📚',
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classItem.className,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'mentor_label'.tr(args: [classItem.mentorName]), // ✅ GÜNCELLENDİ
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        'students_count'.tr(args: [classItem.studentCount.toString()]), // ✅ GÜNCELLENDİ
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!viewModel.isMentorViewing)
              PopupMenuButton(
                icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    onTap: () {
                      Future.delayed(
                        const Duration(milliseconds: 100),
                            () => _showLeaveClassDialog(context, classItem),
                      );
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.exit_to_app, color: Color(0xFFEF4444), size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'leave_class'.tr(), // ✅ GÜNCELLENDİ
                          style: const TextStyle(color: Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksList(BuildContext context) {
    final double offsetY = viewModel.isMentorViewing ? -20 : -60;

    if (viewModel.tasks.isEmpty) {
      return Transform.translate(
        offset: Offset(0, offsetY),
        child: _buildEmptyState(
          icon: Icons.assignment_outlined,
          title: 'no_tasks_student'.tr(), // ✅ GÜNCELLENDİ
          subtitle: viewModel.isMentorViewing
              ? 'no_tasks_mentor_view'.tr() // ✅ GÜNCELLENDİ
              : 'no_tasks_student_subtitle'.tr(), // ✅ GÜNCELLENDİ
        ),
      );
    }

    final notStarted = viewModel.tasks.where((t) => (t.status ?? 'not_started') == 'not_started').toList();
    final inProgress = viewModel.tasks.where((t) => t.status == 'in_progress').toList();
    final completed = viewModel.tasks.where((t) => t.status == 'completed').toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      transform: Matrix4.translationValues(0, offsetY, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notStarted.isNotEmpty) ...[
            _buildTaskSectionHeader('task_status_todo'.tr(), notStarted.length, const Color(0xFF6B7280)), // ✅ GÜNCELLENDİ
            ...notStarted.map((task) => _buildTaskCard(task)),
            const SizedBox(height: 16),
          ],
          if (inProgress.isNotEmpty) ...[
            _buildTaskSectionHeader('task_status_progress'.tr(), inProgress.length, const Color(0xFFF59E0B)), // ✅ GÜNCELLENDİ
            ...inProgress.map((task) => _buildTaskCard(task)),
            const SizedBox(height: 16),
          ],
          if (completed.isNotEmpty) ...[
            _buildTaskSectionHeader('task_status_done'.tr(), completed.length, const Color(0xFF10B981)), // ✅ GÜNCELLENDİ
            ...completed.map((task) => _buildTaskCard(task)),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskSectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTaskClassName(String classId) {
    try {
      final foundClass = viewModel.classes.firstWhere((c) => c.id == classId);
      return foundClass.className;
    } catch (e) {
      return 'Unknown Class';
    }
  }

  Widget _buildTaskCard(TaskModel task) {
    final isOverdue = task.dueDate.isBefore(DateTime.now()) && task.status != 'completed';
    final formattedDate = DateFormat('MMM dd, yyyy').format(task.dueDate);
    final className = _getTaskClassName(task.classId);

    Color priorityColor;
    switch (task.priority.toLowerCase()) {
      case 'high':
        priorityColor = const Color(0xFFEF4444);
        break;
      case 'medium':
        priorityColor = const Color(0xFFF59E0B);
        break;
      default:
        priorityColor = const Color(0xFF3B82F6);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue ? const Color(0xFFFEE2E2) : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school_outlined, size: 12, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    className,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  task.priority.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: priorityColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: isOverdue ? const Color(0xFFEF4444) : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 13,
                  color: isOverdue ? const Color(0xFFEF4444) : Colors.grey[600],
                  fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (isOverdue) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'overdue_label'.tr(), // ✅ GÜNCELLENDİ
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.1),
                  const Color(0xFF8B5CF6).withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: const Color(0xFF6366F1)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }





  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1, color: Colors.grey[200]),
    );
  }

  Future<void> _openDirectChat(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
        ),
      ),
    );

    try {
      final localStorage = LocalStorageService();
      final currentUserId = localStorage.getUid();
      final currentUserData = localStorage.getUserData();
      final currentUserRole = localStorage.getUserRole();

      if (currentUserId == null || currentUserData == null) {
        throw Exception('User not logged in');
      }

      final studentId = viewModel.viewedStudentId!;
      final studentName = profileData.userName;
      final studentImageUrl = profileData.profileImageUrl;

      final messagingService = MessagingService();
      String? chatRoomId;

      if (currentUserRole == 'mentor') {
        chatRoomId = await messagingService.getOrCreateDirectChatRoomId(
          mentorId: currentUserId,
          studentId: studentId,
        );
      } else {
        final ids = [currentUserId, studentId]..sort();
        chatRoomId = await messagingService.getOrCreateDirectChatRoomId(
          mentorId: ids[0],
          studentId: ids[1],
        );
      }

      if (!context.mounted) return;
      Navigator.pop(context);

      if (chatRoomId != null) {
        final isTemporary = chatRoomId.startsWith('direct_');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomView(
              chatRoomId: chatRoomId!,
              chatRoomName: studentName,
              isGroup: false,
              otherUserName: isTemporary ? studentName : null,
              otherUserImageUrl: isTemporary ? studentImageUrl : null,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('failed_start_chat'.tr()), // ✅ GÜNCELLENDİ
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error opening chat: $e');
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('failed_start_chat'.tr() + ': ${e.toString()}'), // ✅ GÜNCELLENDİ
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showJoinClassDialog(BuildContext context) {
    final classCodeController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school_outlined, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'join_class_title'.tr(), // ✅ GÜNCELLENDİ
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'join_class_subtitle'.tr(), // ✅ GÜNCELLENDİ
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: classCodeController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Class Code',
                    hintText: 'ABC123',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF6366F1),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: Text('cancel'.tr()), // ✅ GÜNCELLENDİ
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                    final code = classCodeController.text.trim();
                    if (code.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('enter_class_code'.tr()), // ✅ GÜNCELLENDİ
                          backgroundColor: const Color(0xFFEF4444),
                        ),
                      );
                      return;
                    }

                    setState(() => isLoading = true);
                    final success = await viewModel.joinClass(code);
                    setState(() => isLoading = false);

                    if (context.mounted) {
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                success ? Icons.check_circle : Icons.error_outline,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(success
                                    ? 'join_class_success'.tr() // ✅ GÜNCELLENDİ
                                    : 'join_class_failed'.tr()), // ✅ GÜNCELLENDİ
                              ),
                            ],
                          ),
                          backgroundColor: success
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  },
                  child: isLoading
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text(
                    'join_class_button'.tr(), // ✅ GÜNCELLENDİ
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLeaveClassDialog(BuildContext context, ClassModel classItem) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('leave_class_title'.tr()), // ✅ GÜNCELLENDİ
        content: Text(
          'leave_class_confirm'.tr(args: [classItem.className]), // ✅ GÜNCELLENDİ
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()), // ✅ GÜNCELLENDİ
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final success = await viewModel.leaveClass(classItem.id);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          success ? Icons.check_circle : Icons.error_outline,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(success
                              ? 'leave_class_success'.tr() // ✅ GÜNCELLENDİ
                              : 'leave_class_failed'.tr()), // ✅ GÜNCELLENDİ
                        ),
                      ],
                    ),
                    backgroundColor: success
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            child: Text(
              'leave_class'.tr(), // ✅ GÜNCELLENDİ (Görsel tutarlılık için)
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }


}