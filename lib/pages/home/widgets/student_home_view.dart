import 'package:flutter/material.dart';
import 'package:mykoc/pages/home/homeModel.dart';
import 'package:mykoc/pages/home/homeViewModel.dart';

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
      body: RefreshIndicator(
        onRefresh: () => viewModel.refresh(),
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: _buildStudentHeader(),
            ),
            // My Tasks Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Filter tasks
                      },
                      icon: const Icon(Icons.filter_list_rounded, size: 18),
                      label: const Text('Filter'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Task Filters
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    _buildFilterChip('All', true),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending', false),
                    const SizedBox(width: 8),
                    _buildFilterChip('Completed', false),
                  ],
                ),
              ),
            ),
            // Tasks List
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    return _buildTaskCard(
                      title: index == 0
                          ? 'Read Chapter 5: Shakespearean Sonnets'
                          : 'Design a Logo Concept',
                      className: index == 0 ? '📚 English Literature' : '🎨 Design Fundamentals',
                      dueText: index == 0 ? 'Due in about 24 hours' : 'Due in 2 days',
                      priority: index == 0 ? 'High Priority' : 'Medium Priority',
                      isHighPriority: index == 0,
                    );
                  },
                  childCount: 2, // TODO: Dynamic olacak
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
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
                          '${homeData.progressPercentage.toInt()}%',
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
                            widthFactor: homeData.progressPercentage / 100,
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
                      '${homeData.completedTasks} of ${homeData.totalTasks} tasks completed',
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

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? const Color(0xFF6366F1) : Colors.grey[300]!,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _buildTaskCard({
    required String title,
    required String className,
    required String dueText,
    required String priority,
    required bool isHighPriority,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighPriority
              ? const Color(0xFFFEF3C7)
              : const Color(0xFFE5E7EB),
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
      child: Row(
        children: [
          // Checkbox
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[400]!, width: 2),
            ),
          ),
          const SizedBox(width: 12),
          // Task Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  className,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: isHighPriority
                          ? const Color(0xFFEA580C)
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dueText,
                      style: TextStyle(
                        fontSize: 13,
                        color: isHighPriority
                            ? const Color(0xFFEA580C)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHighPriority
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFDCEEFB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    priority,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isHighPriority
                          ? const Color(0xFFEA580C)
                          : const Color(0xFF3B82F6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}