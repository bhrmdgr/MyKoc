import 'package:flutter/material.dart';
import 'package:mykoc/pages/tasks/task_model.dart';
import 'package:intl/intl.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;
  final int? notStartedCount;
  final int? inProgressCount;
  final int? completedCount;
  final String assigneeLabel; // YENİ: "Ahmet Yılmaz" veya "3 Students" yazısı buraya gelecek

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    this.notStartedCount,
    this.inProgressCount,
    this.completedCount,
    required this.assigneeLabel, // Zorunlu alan
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F2937).withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER (Priority & Date) ---
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        task.priority.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        _formatDueDate(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // --- TITLE ---
            Text(
              task.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                task.description,
                style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 16),

            // --- STATS SECTION (HER ZAMAN GÖRÜNÜR - ZIPLAMAYI ENGELLER) ---
            Row(
              children: [
                Expanded(
                  child: _buildCompactStat(
                    label: 'Done',
                    count: completedCount,
                    color: const Color(0xFF10B981),
                    icon: Icons.check_circle_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactStat(
                    label: 'Working',
                    count: inProgressCount,
                    color: const Color(0xFFF59E0B),
                    icon: Icons.access_time_filled_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactStat(
                    label: 'Todo',
                    count: notStartedCount,
                    color: const Color(0xFF6B7280),
                    icon: Icons.radio_button_unchecked,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // --- FOOTER (ÖĞRENCİ İSMİ / SAYISI) ---
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF6366F1)),
                      const SizedBox(width: 6),
                      Text(
                        assigneeLabel, // Hesaplanan isim veya sayı burada
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStat({
    required String label,
    required int? count,
    required Color color,
    required IconData icon,
  }) {
    // Veri yoksa '-' göstererek yer tutuyoruz
    final displayValue = count != null ? count.toString() : '-';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              "$label: $displayValue",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor() {
    switch (task.priority) {
      case 'high': return const Color(0xFFEF4444);
      case 'medium': return const Color(0xFFF59E0B);
      default: return const Color(0xFF10B981);
    }
  }

  String _formatDueDate() {
    final now = DateTime.now();
    final difference = task.dueDate.difference(now).inDays;
    if (difference < 0) return 'Overdue';
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference <= 7) return '$difference days';
    return DateFormat('MMM dd').format(task.dueDate);
  }
}