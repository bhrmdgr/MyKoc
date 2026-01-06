import 'package:easy_localization/easy_localization.dart'; // ← Eklendi
import 'package:flutter/material.dart';
import 'package:mykoc/pages/profile/profile_model.dart';
import 'package:mykoc/pages/profile/profile_view_model.dart';
import 'package:mykoc/pages/classroom/class_model.dart';
import 'package:mykoc/pages/classroom/class_detail/class_detail_view.dart';
import 'package:mykoc/pages/profile/student_profile_page.dart';
import 'package:mykoc/pages/settings/settings_view.dart';
import 'package:mykoc/firebase/messaging/messaging_service.dart';
import 'package:mykoc/pages/communication/chat_room/chat_room_view.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';
import 'package:flutter/foundation.dart';

class MentorProfileView extends StatelessWidget {
  final ProfileModel profileData;
  final ProfileViewModel viewModel;

  const MentorProfileView({
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
            _buildStatsOverview(),
            const SizedBox(height: 16),

            if (viewModel.isLoading)
              const Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(),
              )
            else
              _buildDynamicContent(context),

            const SizedBox(height: 16),
            _buildMenuOptions(context),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            children: [
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
                child: (profileData.profileImageUrl != null &&
                    profileData.profileImageUrl!.isNotEmpty)
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
              Text(
                profileData.userName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'profile_mentor'.tr(), // ✅ GÜNCELLENDİ
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),

              if (viewModel.isStudentViewing) ...[
                const SizedBox(height: 20),
                SizedBox(
                  height: 45,
                  child: ElevatedButton.icon(
                    onPressed: () => _openDirectChat(context),
                    icon: const Icon(
                        Icons.chat_bubble_outline_rounded, size: 20),
                    label: Text(
                      "send_message".tr(), // ✅ GÜNCELLENDİ
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
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
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
        throw Exception('error_user_not_found'.tr());
      }

      final mentorId = viewModel.viewedMentorId;
      if (mentorId == null) {
        throw Exception('Mentor ID not found');
      }

      final mentorName = profileData.userName;
      final mentorImageUrl = profileData.profileImageUrl;

      final messagingService = MessagingService();
      String? chatRoomId;

      if (currentUserRole == 'student') {
        chatRoomId = await messagingService.getOrCreateDirectChatRoomId(
          mentorId: mentorId,
          studentId: currentUserId,
        );
      } else {
        throw Exception('Cannot message another mentor');
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
              chatRoomName: mentorName,
              isGroup: false,
              otherUserName: isTemporary ? mentorName : null,
              otherUserImageUrl: isTemporary ? mentorImageUrl : null,
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
            content: Text('error_with_message'.tr(args: [e.toString()])), // ✅ GÜNCELLENDİ
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Widget _buildStatsOverview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'overview'.tr(), // ✅ GÜNCELLENDİ
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => viewModel.setMentorFilter('classes'),
                  child: _buildStatBox(
                    icon: Icons.school_outlined,
                    value: '${profileData.classCount ?? 0}',
                    label: 'classes'.tr(), // ✅ GÜNCELLENDİ
                    color: const Color(0xFF6366F1),
                    isSelected: viewModel.mentorFilter == 'classes',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => viewModel.setMentorFilter('students'),
                  child: _buildStatBox(
                    icon: Icons.people_outline,
                    value: '${profileData.studentCount ?? 0}',
                    label: 'students'.tr(), // ✅ GÜNCELLENDİ
                    color: const Color(0xFF10B981),
                    isSelected: viewModel.mentorFilter == 'students',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatBox(
            icon: Icons.assignment_outlined,
            value: '${profileData.activeTasks ?? 0}',
            label: 'total_tasks_created'.tr(), // ✅ GÜNCELLENDİ
            color: const Color(0xFF8B5CF6),
            isFullWidth: true,
            isSelected: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    bool isFullWidth = false,
    required bool isSelected,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.1) : Colors.grey.withOpacity(
            0.05),
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(color: color, width: 2)
            : Border.all(color: Colors.transparent, width: 2),
      ),
      child: isFullWidth
          ? Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.2) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? color.withOpacity(0.8) : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      )
          : Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.2) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isSelected ? color.withOpacity(0.8) : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicContent(BuildContext context) {
    switch (viewModel.mentorFilter) {
      case 'students':
        return _buildStudentsList(context);
      case 'classes':
      default:
        return _buildClassesSection(context);
    }
  }

  Widget _buildStudentsList(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'all_students'.tr(), // ✅ GÜNCELLENDİ
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          if (viewModel.allStudents.isEmpty)
            _buildEmptyClassesState(
              icon: Icons.people_outline,
              title: 'no_student_data'.tr(), // ✅ GÜNCELLENDİ
              subtitle: 'sync_student_info'.tr(), // ✅ GÜNCELLENDİ
            )
          else
            ...viewModel.allStudents.map((student) {
              final displayClassName = student['displayClassName'] ??
                  'Unknown Class';
              final studentId = student['uid'] ?? student['id'];

              return GestureDetector(
                onTap: () {
                  if (studentId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            StudentProfilePage(studentId: studentId),
                      ),
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
                      CircleAvatar(
                        backgroundColor: const Color(0xFF10B981).withOpacity(
                            0.1),
                        child: Text(
                          (student['name'] as String? ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            if (student['email'] != null)
                              Text(
                                student['email'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          displayClassName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildClassesSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'my_classes'.tr(), // ✅ GÜNCELLENDİ
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          if (viewModel.classes.isEmpty)
            _buildEmptyClassesState(
              title: 'no_classes_title'.tr(), // ✅ GÜNCELLENDİ
              subtitle: 'no_classes_subtitle'.tr(), // ✅ GÜNCELLENDİ
              icon: Icons.school_outlined,
            )
          else
            ...viewModel.classes
                .map((classItem) => _buildClassCard(context, classItem))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildClassCard(BuildContext context, ClassModel classItem) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClassDetailView(classData: classItem),
          ),
        );
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
                    classItem.classType,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.people_outline, size: 14,
                          color: Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      Text(
                        '${classItem.studentCount} ${'students'.tr()}', // ✅ GÜNCELLENDİ
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.vpn_key_outlined, size: 14,
                          color: Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      Text(
                        classItem.classCode,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              itemBuilder: (context) =>
              [
                PopupMenuItem(
                  onTap: () {
                    Future.delayed(
                      const Duration(milliseconds: 100),
                          () => _showDeleteClassDialog(context, classItem),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline, color: Color(0xFFEF4444),
                          size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'delete_class'.tr(), // ✅ GÜNCELLENDİ
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

  Widget _buildEmptyClassesState({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
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
            child: Icon(
              icon,
              size: 40,
              color: const Color(0xFF6366F1),
            ),
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

  Widget _buildMenuOptions(BuildContext context) {
    if (viewModel.isStudentViewing) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
          _buildMenuItem(
            icon: Icons.settings_outlined,
            title: 'settings'.tr(), // ✅ GÜNCELLENDİ
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsView()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.logout_rounded,
            title: 'logout'.tr(), // ✅ GÜNCELLENDİ
            isDestructive: true,
            onTap: () {
              _showLogoutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? const Color(0xFFEF4444) : const Color(
                  0xFF6B7280),
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDestructive ? const Color(0xFFEF4444) : const Color(
                    0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1, color: Colors.grey[200]),
    );
  }

  void _showDeleteClassDialog(BuildContext context, ClassModel classItem) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_outlined,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text('delete_class'.tr()), // ✅ GÜNCELLENDİ
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'delete_class_confirm_desc'.tr(args: [classItem.className]), // ✅ GÜNCELLENDİ
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'delete_class_warning_title'.tr(), // ✅ GÜNCELLENDİ
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'delete_class_warning_list'.tr(), // ✅ GÜNCELLENDİ
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('cancel'.tr()), // ✅ GÜNCELLENDİ
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextButton(
                  onPressed: () async {
                    Navigator.pop(context);

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) =>
                      const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white),
                        ),
                      ),
                    );

                    final success = await viewModel.deleteClass(classItem.id);

                    if (context.mounted) {
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                success ? Icons.check_circle : Icons
                                    .error_outline,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(success
                                    ? 'class_deleted_success'.tr() // ✅ GÜNCELLENDİ
                                    : 'class_deleted_failed'.tr()), // ✅ GÜNCELLENDİ
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
                    'delete'.tr(), // ✅ GÜNCELLENDİ
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
  }



  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) =>
          AlertDialog(
            title: Text('logout_confirm_title'.tr()), // ✅ GÜNCELLENDİ
            content: Text('logout_confirm_desc'.tr()), // ✅ GÜNCELLENDİ
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('cancel'.tr()), // ✅ GÜNCELLENDİ
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  viewModel.logout(context);
                },
                child: Text(
                  'logout'.tr(), // ✅ GÜNCELLENDİ
                  style: const TextStyle(color: Color(0xFFEF4444)),
                ),
              ),
            ],
          ),
    );
  }
}