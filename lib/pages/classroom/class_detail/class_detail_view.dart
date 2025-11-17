import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mykoc/pages/classroom/class_detail/class_detail_view_model.dart';
import 'package:mykoc/pages/classroom/class_model.dart';
import 'package:mykoc/pages/tasks/create_task_view.dart';
import 'package:mykoc/pages/classroom/class_detail/widgets/task_card.dart';


class ClassDetailView extends StatefulWidget {
  final ClassModel classData;

  const ClassDetailView({
    super.key,
    required this.classData,
  });

  @override
  State<ClassDetailView> createState() => _ClassDetailViewState();
}

class _ClassDetailViewState extends State<ClassDetailView>
    with SingleTickerProviderStateMixin {
  late ClassDetailViewModel _viewModel;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _viewModel = ClassDetailViewModel(classId: widget.classData.id);

    // Tab değişikliklerini dinle ve UI'ı güncelle
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // FAB görünürlüğünü güncelle
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildStatsCards(),
              _buildTabBar(),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTasksTab(),
                    _buildStudentsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: _tabController.index == 0
            ? FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChangeNotifierProvider.value(
                  value: _viewModel,
                  child: CreateTaskView(
                    classId: widget.classData.id,
                    students: _viewModel.students,
                  ),
                ),
              ),
            );

            if (result == true && mounted) {
              _viewModel.refresh();
            }
          },
          backgroundColor: const Color(0xFF6366F1),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'New Task',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        )
            : null,
      ),
    );
  }


  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color(widget.classData.getColorFromType()),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () {
                      // TODO: Show menu (edit, delete, etc.)
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        widget.classData.emoji ?? '📚',
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.classData.className,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Container(
      transform: Matrix4.translationValues(0, -30, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.check_circle_outline_rounded,
              iconColor: const Color(0xFF10B981),
              value: '1',
              label: 'Done',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              icon: Icons.access_time_rounded,
              iconColor: const Color(0xFFF59E0B),
              value: '2',
              label: 'Pending',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              icon: Icons.cancel_outlined,
              iconColor: const Color(0xFF6B7280),
              value: '0',
              label: 'Not Started',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              icon: Icons.people_outline_rounded,
              iconColor: const Color(0xFF6366F1),
              value: '${widget.classData.studentCount}',
              label: 'Students',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF6366F1),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF6B7280),
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.assignment_outlined, size: 20),
                SizedBox(width: 8),
                Text('Tasks'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.people_outline_rounded, size: 20),
                SizedBox(width: 8),
                Text('Students'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksTab() {
    return Consumer<ClassDetailViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading && viewModel.tasks.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (viewModel.tasks.isEmpty) {
          return _buildEmptyTasksState();
        }

        return RefreshIndicator(
          onRefresh: () => viewModel.refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: viewModel.tasks.length,
            itemBuilder: (context, index) {
              final task = viewModel.tasks[index];
              return TaskCard(
                task: task,
                onTap: () {
                  // TODO: Navigate to task detail
                  debugPrint('Task tapped: ${task.title}');
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyTasksState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
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
              size: 60,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Tasks Yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first task to get started',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

        ],
      ),
    );
  }

  Widget _buildTaskCard({
    required String title,
    required String dueText,
    required int completed,
    required int total,
    required int percentage,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              Text(
                '$completed/$total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dueText,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsTab() {
    return Consumer<ClassDetailViewModel>(
      builder: (context, viewModel, child) {
        // Eğer yükleniyor ve hiç öğrenci yoksa loading göster
        if (viewModel.isLoading && viewModel.students.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Students',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showInviteCodeDialog(),
                    icon: const Icon(Icons.person_add_outlined, size: 18),
                    label: const Text('Add Student'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      side: const BorderSide(color: Color(0xFF6366F1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: viewModel.students.isEmpty
                  ? _buildEmptyStudentsState()
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: viewModel.students.length,
                itemBuilder: (context, index) {
                  final student = viewModel.students[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildStudentCard(
                      name: student['name'] ?? 'Unknown',
                      email: student['email'] ?? '',
                      initials: _getInitials(student['name'] ?? 'U'),
                      color: _getColorForIndex(index),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyStudentsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No Students Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share your class code to invite students',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard({
    required String name,
    required String email,
    required String initials,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
            onPressed: () {
              // TODO: Show options (remove student, etc.)
            },
          ),
        ],
      ),
    );
  }

  void _showInviteCodeDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: Color(0xFF6366F1),
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Class Code',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ask your students to use this code during sign up',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.classData.classCode,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _copyCodeToClipboard(widget.classData.classCode);
                  },
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  label: const Text(
                    'Copy Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyCodeToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('Code copied to clipboard!'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color _getColorForIndex(int index) {
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
    ];
    return colors[index % colors.length];
  }
}