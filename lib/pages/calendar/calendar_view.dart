import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:mykoc/pages/tasks/task_model.dart';
import 'package:mykoc/pages/calendar/calendar_note_model.dart';
import 'package:mykoc/pages/calendar/calendar_view_model.dart';
import 'package:mykoc/pages/tasks/mentor_task_detail_view.dart';

class CalendarView extends StatelessWidget {
  const CalendarView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CalendarViewModel()..initialize(),
      child: const _CalendarViewContent(),
    );
  }
}

class _CalendarViewContent extends StatefulWidget {
  const _CalendarViewContent();

  @override
  State<_CalendarViewContent> createState() => _CalendarViewContentState();
}

class _CalendarViewContentState extends State<_CalendarViewContent> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CalendarViewModel>();

    // Edit modunda değilsek ve not içeriği değiştiyse güncelle
    if (!viewModel.isEditingNote && _noteController.text != viewModel.currentDayNoteContent) {
      _noteController.text = viewModel.currentDayNoteContent;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: viewModel.isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              child: Column(
                children: [
                  _buildCalendar(context, viewModel),
                  const SizedBox(height: 20),
                  _buildNoteSection(context, viewModel),
                  const SizedBox(height: 20),
                  _buildTaskList(context, viewModel),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'calendar_title'.tr(),
                style: TextStyle(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'calendar_subtitle'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar(BuildContext context, CalendarViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.all(20),
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
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: viewModel.focusedDay,
        calendarFormat: viewModel.calendarFormat,
        selectedDayPredicate: (day) => isSameDay(viewModel.selectedDay, day),

        // Veri yükleyici
        eventLoader: (day) => viewModel.getEventsForDay(day),

        // --- TASARIM AYARLARI ---
        calendarBuilders: CalendarBuilders(

          // 1. SİYAH NOKTALARI KALDIRAN KOD BURASI
          markerBuilder: (context, day, events) {
            return const SizedBox(); // Hiçbir şey çizme (Noktaları yok et)
          },

          // 2. GÜNLERİN TASARIMI (Renkli Daireler)
          defaultBuilder: (context, day, focusedDay) {
            final events = viewModel.getEventsForDay(day);

            // Eğer o gün boşsa varsayılan görünümü kullan
            if (events.isEmpty) return null;

            // Event tiplerini kontrol et
            final tasks = events.whereType<TaskModel>().toList();
            final notes = events.whereType<CalendarNoteModel>().toList();
            final hasTask = tasks.isNotEmpty;
            final hasNote = notes.isNotEmpty;

            // Tasarımı belirle
            BoxDecoration decoration;
            if (hasTask && hasNote) {
              // Hem Task Hem Not: Turuncu zemin, Mor çerçeve
              decoration = BoxDecoration(
                color: const Color(0xFFF59E0B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.purple.shade400, width: 2.5),
              );
            } else if (hasTask) {
              // Sadece Task: Turuncu zemin
              decoration = const BoxDecoration(
                color: Color(0xFFF59E0B),
                shape: BoxShape.circle,
              );
            } else {
              // Sadece Not: Mor zemin
              decoration = BoxDecoration(
                color: Colors.purple.shade300,
                shape: BoxShape.circle,
              );
            }

            return Center(
              child: Container(
                margin: const EdgeInsets.all(6.0),
                alignment: Alignment.center,
                decoration: decoration,
                child: Text(
                  '${day.day}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          },

          // 3. BUGÜN TASARIMI
          todayBuilder: (context, day, focusedDay) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(6.0),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.2), // Hafif Mavi
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF6366F1)),
                ),
                child: Text(
                  '${day.day}',
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          },
        ),
        // -----------------------------------------------

        onDaySelected: (selectedDay, focusedDay) {
          viewModel.onDaySelected(selectedDay, focusedDay);
          _noteController.text = viewModel.currentDayNoteContent;
        },
        onFormatChanged: (format) => viewModel.onFormatChanged(format),
        onPageChanged: (focusedDay) => viewModel.onPageChanged(focusedDay),

        calendarStyle: const CalendarStyle(
          // Marker (nokta) sayısını 0 yaparak tamamen kapatıyoruz
          markersMaxCount: 0,

          // Seçili gün stili (Koyu Mavi Daire)
          selectedDecoration: BoxDecoration(
            color: Color(0xFF6366F1),
            shape: BoxShape.circle,
          ),
          selectedTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          todayDecoration: BoxDecoration(
            shape: BoxShape.circle,
          ),
        ),

        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
      ),
    );
  }

  Widget _buildNoteSection(BuildContext context, CalendarViewModel viewModel) {
    final hasNote = viewModel.currentDayNoteContent.isNotEmpty;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: Colors.purple.shade400),
                  const SizedBox(width: 8),
                  Text(
                    'daily_note'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              if (!viewModel.isEditingNote)
                IconButton(
                  icon: Icon(hasNote ? Icons.edit : Icons.add, color: const Color(0xFF6366F1)),
                  onPressed: () {
                    _noteController.text = viewModel.currentDayNoteContent;
                    viewModel.toggleEditingNote();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (viewModel.isEditingNote) ...[
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'add_note_hint'.tr(),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    _noteController.text = viewModel.currentDayNoteContent;
                    viewModel.toggleEditingNote();
                  },
                  child: Text('cancel'.tr(), style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final success = await viewModel.saveNote(_noteController.text);
                    if (success && context.mounted) {
                      FocusScope.of(context).unfocus();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('note_saved_success'.tr()), backgroundColor: Color(0xFF10B981)),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('save'.tr(), style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ] else ...[
            if (hasNote)
              Text(
                viewModel.currentDayNoteContent,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5),
              )
            else
              Text(
                'no_note_today'.tr(),
                style: TextStyle(fontSize: 14, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskList(BuildContext context, CalendarViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'tasks_due_date'.tr(args: [
                viewModel.selectedDay != null
                    ? DateFormat('MMM dd').format(viewModel.selectedDay!)
                    : ''
              ]),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          if (viewModel.selectedDayTasks.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.event_available, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text(
                    'no_tasks_due_today'.tr(),
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          else
            ...viewModel.selectedDayTasks.map((task) => _buildTaskItem(context, task)).toList(),
        ],
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, TaskModel task) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MentorTaskDetailView(taskId: task.id),
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
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getPriorityColor(task.priority).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.assignment_outlined,
                color: _getPriorityColor(task.priority),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF10B981);
    }
  }
}