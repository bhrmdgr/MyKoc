import 'package:flutter/material.dart';
import 'package:mykoc/pages/tasks/task_model.dart';
import 'package:mykoc/pages/classroom/class_detail/widgets/task_card.dart';
import 'package:mykoc/pages/classroom/class_detail/class_detail_view.dart'; // Enum için import

class ExpandableTasksSection extends StatelessWidget {
  final List<TaskModel> tasks;
  final Map<String, Map<String, int>>? taskStats;
  final List<Map<String, dynamic>> students;
  final Function(TaskModel) onTaskTap;
  // YENİ: Sıralama için gerekli parametreler
  final TaskSortOption currentSort;
  final Function(TaskSortOption) onSortChanged;

  const ExpandableTasksSection({
    super.key,
    required this.tasks,
    this.taskStats,
    required this.students,
    required this.onTaskTap,
    required this.currentSort, // Zorunlu
    required this.onSortChanged, // Zorunlu
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- BAŞLIK VE SIRALAMA ---
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tasks',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              // Sıralama Butonu
              PopupMenuButton<TaskSortOption>(
                onSelected: onSortChanged,
                initialValue: currentSort,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort_rounded, size: 18, color: Colors.grey[700]),
                      const SizedBox(width: 4),
                      Text(
                        _getSortText(currentSort),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  _buildPopupItem(TaskSortOption.upcoming, 'Upcoming', Icons.calendar_today_rounded),
                  _buildPopupItem(TaskSortOption.newest, 'Newest First', Icons.access_time_rounded),
                  _buildPopupItem(TaskSortOption.oldest, 'Oldest First', Icons.history_rounded),
                  _buildPopupItem(TaskSortOption.priority, 'Priority (High)', Icons.flag_rounded),
                ],
              ),
            ],
          ),
        ),

        // --- GÖREV LİSTESİ ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: tasks.map<Widget>((task) {

              // 1. İstatistikleri çek
              final stats = taskStats?[task.id];

              // 2. Öğrenci etiketini hesapla (NULL SAFETY ile)
              String assigneeLabel = 'Unknown';
              final assignedStudents = task.assignedStudents ?? []; // Null ise boş liste

              if (assignedStudents.isEmpty) {
                assigneeLabel = 'No Students';
              } else if (assignedStudents.length == 1) {
                final studentId = assignedStudents.first;
                final studentMap = students.firstWhere(
                      (s) => (s['uid'] == studentId) || (s['id'] == studentId),
                  orElse: () => {'name': 'Unknown Student'},
                );
                assigneeLabel = studentMap['name'] ?? 'Unknown';
              } else {
                assigneeLabel = '${assignedStudents.length} Students';
              }

              // 3. TaskCard'ı döndür
              return TaskCard(
                task: task,
                onTap: () => onTaskTap(task),
                notStartedCount: stats?['notStarted'],
                inProgressCount: stats?['inProgress'],
                completedCount: stats?['completed'],
                assigneeLabel: assigneeLabel,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  PopupMenuItem<TaskSortOption> _buildPopupItem(TaskSortOption value, String text, IconData icon) {
    final isSelected = currentSort == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFF6366F1) : Colors.grey[600]
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: isSelected ? const Color(0xFF6366F1) : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _getSortText(TaskSortOption option) {
    switch (option) {
      case TaskSortOption.upcoming: return 'Upcoming';
      case TaskSortOption.newest: return 'Newest';
      case TaskSortOption.oldest: return 'Oldest';
      case TaskSortOption.priority: return 'Priority';
    }
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No Tasks Yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Text('Create your first task to get started', style: TextStyle(fontSize: 14, color: Colors.grey[500]), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}