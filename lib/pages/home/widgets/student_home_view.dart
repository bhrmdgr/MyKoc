import 'package:flutter/material.dart';
import 'package:mykoc/pages/home/homeModel.dart';
import 'package:mykoc/pages/home/homeViewModel.dart';
import 'package:mykoc/pages/classroom/class_detail/announcement_model.dart';
import 'package:mykoc/pages/tasks/task_model.dart';
import 'package:mykoc/pages/home/widgets/announcement_detail_dialog.dart';
import 'package:mykoc/pages/home/widgets/task_detail_dialog.dart';
import 'package:intl/intl.dart';

class StudentHomeView extends StatelessWidget {
  final HomeModel homeData;
  final HomeViewModel viewModel;

  const StudentHomeView({
    super.key,
    required this.homeData,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: RefreshIndicator(
        onRefresh: () => viewModel.refresh(),
        child: Stack(
          children: [
            // Ana içerik
            CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: _buildStudentHeader(),
                ),

                // Class Selector (eğer birden fazla sınıf varsa)
                if (viewModel.classes.length > 1)
                  SliverToBoxAdapter(
                    child: _buildClassSelector(context),
                  ),

                // Announcements Section
                if (viewModel.studentAnnouncements.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildAnnouncementsSection(context),
                  ),

                // My Tasks Section Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'My Tasks',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        if (viewModel.studentTasks.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${viewModel.studentTasks.length} tasks',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Loading State (Only Initial Load)
                if (viewModel.isLoading && viewModel.studentTasks.isEmpty && !viewModel.isSwitchingClass)
                  SliverToBoxAdapter(
                    child: _buildLoadingState(),
                  )
                // Empty State
                else if (viewModel.studentTasks.isEmpty && !viewModel.isSwitchingClass)
                  SliverToBoxAdapter(
                    child: _buildEmptyTasksState(),
                  )
                // Tasks List
                else if (viewModel.studentTasks.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final task = viewModel.studentTasks[index];
                            return _buildTaskCard(context, task);
                          },
                          childCount: viewModel.studentTasks.length,
                        ),
                      ),
                    ),

                // Bottom Padding
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),

            // Loading Overlay - Sadece sınıf değiştirirken göster
            if (viewModel.isSwitchingClass)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading ${viewModel.activeClass?.className}...',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(60),
      child: Column(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading tasks...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentHeader() {
    return Container(
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
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Text & Avatar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hello,',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white70,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          homeData.userName,
                          style: const TextStyle(
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        homeData.userInitials,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Progress Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.trending_up_rounded,
                              color: Colors.white.withOpacity(0.9),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Your Progress',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${_calculateProgress().toInt()}%',
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: _calculateProgress() / 100,
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_getCompletedTasksCount()} of ${viewModel.studentTasks.length} tasks completed',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassSelector(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Classes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: viewModel.isSwitchingClass
                  ? const NeverScrollableScrollPhysics()
                  : const ScrollPhysics(),
              itemCount: viewModel.classes.length,
              itemBuilder: (context, index) {
                final classItem = viewModel.classes[index];
                final isActive = viewModel.activeClass?.id == classItem.id;

                return GestureDetector(
                  onTap: viewModel.isSwitchingClass
                      ? null
                      : () {
                    if (!isActive) {
                      viewModel.switchActiveClass(classItem.id);
                    }
                  },
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: viewModel.isSwitchingClass && !isActive ? 0.5 : 1.0,
                    child: Container(
                      width: 200,
                      margin: EdgeInsets.only(
                        right: index < viewModel.classes.length - 1 ? 12 : 0,
                      ),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: isActive
                            ? LinearGradient(
                          colors: [
                            Color(classItem.getColorFromType()),
                            Color(classItem.getColorFromType()).withOpacity(0.7),
                          ],
                        )
                            : null,
                        color: isActive ? null : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isActive
                              ? Colors.transparent
                              : const Color(0xFFE5E7EB),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isActive
                                ? Color(classItem.getColorFromType()).withOpacity(0.3)
                                : Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                classItem.emoji ?? '📚',
                                style: const TextStyle(fontSize: 22),
                              ),
                              const Spacer(),
                              if (isActive)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                classItem.className,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? Colors.white : const Color(0xFF1F2937),
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                classItem.mentorName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isActive
                                      ? Colors.white.withOpacity(0.9)
                                      : Colors.grey[600],
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            'Announcements',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: viewModel.studentAnnouncements.length,
            itemBuilder: (context, index) {
              final announcement = viewModel.studentAnnouncements[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < viewModel.studentAnnouncements.length - 1 ? 12 : 0,
                ),
                child: _buildAnnouncementCard(context, announcement),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementCard(BuildContext context, AnnouncementModel announcement) {
    final formattedDate = DateFormat('MMM dd, HH:mm').format(announcement.createdAt);

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AnnouncementDetailDialog(
            announcement: announcement,
          ),
        );
      },
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF6366F1),
              Color(0xFF8B5CF6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.campaign,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const Spacer(),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              announcement.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                announcement.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, TaskModel task) {
    final taskStatus = task.status ?? 'not_started';
    final isOverdue = task.dueDate.isBefore(DateTime.now()) && taskStatus != 'completed';
    final daysUntilDue = task.dueDate.difference(DateTime.now()).inDays;
    final isUrgent = daysUntilDue <= 1 && !isOverdue && taskStatus != 'completed';

    String dueText;
    if (taskStatus == 'completed') {
      dueText = 'Completed';
    } else if (isOverdue) {
      dueText = 'Overdue';
    } else if (daysUntilDue == 0) {
      dueText = 'Due today';
    } else if (daysUntilDue == 1) {
      dueText = 'Due tomorrow';
    } else {
      dueText = 'Due in $daysUntilDue days';
    }

    Color priorityColor;
    Color borderColor;
    switch (task.priority.toLowerCase()) {
      case 'high':
        priorityColor = const Color(0xFFEF4444);
        borderColor = const Color(0xFFFEE2E2);
        break;
      case 'medium':
        priorityColor = const Color(0xFFF59E0B);
        borderColor = const Color(0xFFFEF3C7);
        break;
      default:
        priorityColor = const Color(0xFF3B82F6);
        borderColor = const Color(0xFFDCEEFB);
    }

    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (taskStatus) {
      case 'in_progress':
        statusText = 'In Progress';
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.pending_outlined;
        break;
      case 'completed':
        statusText = 'Completed';
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        break;
      default:
        statusText = 'Not Started';
        statusColor = const Color(0xFF6B7280);
        statusIcon = Icons.radio_button_unchecked;
    }

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => TaskDetailDialog(
            task: task,
            onTaskUpdated: () {
              // Cache'i temizle ve yeniden yükle
              if (viewModel.activeClass != null) {
                viewModel.refreshClass(viewModel.activeClass!.id);
              }
            },
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUrgent || isOverdue ? borderColor : const Color(0xFFE5E7EB),
            width: 2,
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: taskStatus == 'completed'
                      ? const Color(0xFF10B981)
                      : isOverdue
                      ? const Color(0xFFEF4444)
                      : isUrgent
                      ? const Color(0xFFF59E0B)
                      : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  dueText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: taskStatus == 'completed'
                        ? const Color(0xFF10B981)
                        : isOverdue
                        ? const Color(0xFFEF4444)
                        : isUrgent
                        ? const Color(0xFFF59E0B)
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTasksState() {
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
            child: const Icon(
              Icons.assignment_outlined,
              size: 40,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Tasks Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            viewModel.activeClass != null
                ? 'No tasks assigned in ${viewModel.activeClass!.className} yet'
                : 'Your mentor hasn\'t assigned any tasks yet',
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

  double _calculateProgress() {
    if (viewModel.studentTasks.isEmpty) return 0;
    final completedCount = _getCompletedTasksCount();
    return (completedCount / viewModel.studentTasks.length) * 100;
  }

  int _getCompletedTasksCount() {
    return viewModel.studentTasks
        .where((task) => (task.status ?? 'not_started') == 'completed')
        .length;
  }
}