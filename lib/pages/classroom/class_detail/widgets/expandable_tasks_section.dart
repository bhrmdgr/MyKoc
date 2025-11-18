import 'package:flutter/material.dart';
import 'package:mykoc/pages/tasks/task_model.dart';
import 'package:mykoc/pages/classroom/class_detail/widgets/task_card.dart';

class ExpandableTasksSection extends StatefulWidget {
  final List<TaskModel> tasks;
  final Function(TaskModel) onTaskTap;

  const ExpandableTasksSection({
    super.key,
    required this.tasks,
    required this.onTaskTap,
  });

  @override
  State<ExpandableTasksSection> createState() => _ExpandableTasksSectionState();
}

class _ExpandableTasksSectionState extends State<ExpandableTasksSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.tasks.isEmpty) {
      return _buildEmptyState();
    }

    // Task'ları due date'e göre sırala
    final sortedTasks = List<TaskModel>.from(widget.tasks)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    // Gösterilecek task'ları belirle
    final tasksToShow = _isExpanded
        ? sortedTasks
        : sortedTasks.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isExpanded ? 'All Tasks' : 'Upcoming Tasks',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              if (widget.tasks.length > 2)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                  label: Text(_isExpanded ? 'Show Less' : 'View All'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: tasksToShow.map((task) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TaskCard(
                  task: task,
                  onTap: () => widget.onTaskTap(task),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
          ),
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
            const Text(
              'No Tasks Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first task to get started',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}