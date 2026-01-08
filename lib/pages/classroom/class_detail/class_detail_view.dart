import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mykoc/pages/premium/premium_view.dart';
import 'package:provider/provider.dart';
import 'package:mykoc/pages/classroom/class_detail/class_detail_view_model.dart';
import 'package:mykoc/pages/classroom/class_model.dart';
import 'package:mykoc/pages/tasks/create_task_view.dart';
import 'package:mykoc/pages/classroom/class_detail/widgets/announcements_section.dart';
import 'package:mykoc/pages/classroom/class_detail/widgets/announcement_dialog.dart';
import 'package:mykoc/pages/classroom/class_detail/announcement_model.dart';
import 'package:mykoc/pages/classroom/class_detail/widgets/expandable_tasks_section.dart';
import 'package:mykoc/pages/tasks/mentor_task_detail_view.dart';
import 'package:mykoc/pages/tasks/task_model.dart'; // TaskModel erişimi için
import 'package:mykoc/services/storage/local_storage_service.dart';
import 'package:mykoc/firebase/tasks/task_service.dart';
import 'package:mykoc/pages/profile/student_profile_page.dart'; // EKLENDİ

// Sıralama Seçenekleri
enum TaskSortOption { upcoming, newest, oldest, priority }

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
  final LocalStorageService _localStorage = LocalStorageService();
  final TaskService _taskService = TaskService();

  // Her görevin istatistiklerini (Done/Working/Todo) tutan harita
  Map<String, Map<String, int>> _taskStats = {};

  // Seçili sıralama yöntemi (Varsayılan: Yaklaşan)
  TaskSortOption _selectedSort = TaskSortOption.upcoming;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _viewModel = ClassDetailViewModel(classId: widget.classData.id);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    // ViewModel güncellemelerini dinle (Yeni task geldiğinde stats çekmek için)
    _viewModel.addListener(_onViewModelUpdated);

    // Sayfa açıldığında verileri başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.initialize().then((_) {
        if (mounted) {
          _loadTaskStats();
        }
      });
    });
  }

  // Öğrenci limiti dolduğunda gösterilecek Premium uyarısı
  void _showStudentLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 28),
            const SizedBox(width: 12),
            Text('limit_reached'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('student_limit_info'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr(), style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Önce diyaloğu kapat
              // Premium sayfasına yönlendiriyoruz
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PremiumView()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
                'upgrade_now'.tr(),
                style: const TextStyle(color: Colors.white)
            ),
          ),
        ],
      ),
    );
  }

  // ViewModel değiştiğinde tetiklenir
  void _onViewModelUpdated() {
    if (!mounted) return;

    // Sadece loading bittiğinde ve elimizde task varken,
    // ama henüz stats doldurulmamışsa bir kez tetikle.
    if (!_viewModel.isLoading &&
        _viewModel.tasks.isNotEmpty &&
        _taskStats.isEmpty) {
      _loadTaskStats();
    }
  }

  // Görevlerin istatistiklerini (Kaç kişi tamamladı vs.) çeker
  Future<void> _loadTaskStats() async {
    final tasks = _viewModel.tasks;
    if (tasks.isEmpty) return;

    bool hasChanged = false;
    // Yerel bir kopya üzerinden çalış
    final currentStats = Map<String, Map<String, int>>.from(_taskStats);

    for (var task in tasks) {
      if (currentStats.containsKey(task.id)) continue;

      try {
        final detail = await _taskService.getTaskDetailWithStudents(taskId: task.id);
        if (detail != null) {
          currentStats[task.id] = {
            'notStarted': detail.notStartedCount,
            'inProgress': detail.inProgressCount,
            'completed': detail.completedCount,
          };
          hasChanged = true;
        }
      } catch (e) {
        debugPrint('Error: $e');
      }
    }

    // Döngü bittikten sonra TEK BİR setState
    if (mounted && hasChanged) {
      setState(() {
        _taskStats = currentStats;
      });
    }
  }

  // Görevleri seçilen opsiyona göre sıralar
  List<TaskModel> _getSortedTasks() {
    List<TaskModel> sortedList = List.from(_viewModel.tasks);

    switch (_selectedSort) {
      case TaskSortOption.upcoming:
      // Tarihi en yakın olan (DueDate)
        sortedList.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        break;
      case TaskSortOption.newest:
      // Eklenme tarihi en yeni olan (CreatedAt Desc)
        sortedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case TaskSortOption.oldest:
      // Eklenme tarihi en eski olan (CreatedAt Asc)
        sortedList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case TaskSortOption.priority:
      // Öncelik sırası (High > Medium > Low)
        sortedList.sort((a, b) {
          final pA = _getPriorityValue(a.priority);
          final pB = _getPriorityValue(b.priority);
          return pB.compareTo(pA);
        });
        break;
    }
    return sortedList;
  }

  int _getPriorityValue(String priority) {
    switch (priority.toLowerCase()) {
      case 'high': return 3;
      case 'medium': return 2;
      default: return 1;
    }
  }

  // Sınıfın genel başarı oranını hesaplar
  double _calculateOverallProgress() {
    if (_taskStats.isEmpty) return 0.0;

    int totalAssignments = 0;
    int totalCompleted = 0;

    _taskStats.forEach((_, stats) {
      int taskStudentCount = (stats['completed'] ?? 0) +
          (stats['inProgress'] ?? 0) +
          (stats['notStarted'] ?? 0);

      totalAssignments += taskStudentCount;
      totalCompleted += (stats['completed'] ?? 0);
    });

    if (totalAssignments == 0) return 0.0;
    return (totalCompleted / totalAssignments);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelUpdated);
    _tabController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildStatsCards(), // Güncellenen 3'lü istatistik alanı
              Consumer<ClassDetailViewModel>(
                builder: (context, viewModel, child) {
                  return AnnouncementsSection(
                    announcements: viewModel.announcements,
                    onAddPressed: _showCreateAnnouncementDialog,
                    onAnnouncementTap: _showEditAnnouncementDialog,
                  );
                },
              ),
              _buildTabBar(),
              Consumer<ClassDetailViewModel>(
                builder: (context, viewModel, child) {
                  return AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _tabController.index == 0
                        ? _buildTasksContent(viewModel)
                        : _buildStudentsContent(viewModel),
                  );
                },
              ),
              const SizedBox(height: 100),
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
              // Yeni görev eklendi, listeyi yenile
              await _viewModel.refresh();
              // Listener sayesinde _loadTaskStats otomatik çalışacak
            }
          },
          backgroundColor: const Color(0xFF6366F1),
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            'new_task'.tr(),
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

  // --- GÜNCELLENEN 3'LÜ İSTATİSTİK KARTLARI ---
  // --- GÜNCELLENEN 3'LÜ İSTATİSTİK KARTLARI ---
  Widget _buildStatsCards() {
    // Consumer kullanarak ViewModel'i dinliyoruz
    return Consumer<ClassDetailViewModel>(
      builder: (context, viewModel, child) {
        return Container(
          transform: Matrix4.translationValues(0, -30, 0),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              // 1. Öğrenci Sayısı
              Expanded(
                child: _buildStatCard(
                  icon: Icons.groups_rounded,
                  iconColor: const Color(0xFF6366F1),
                  value: viewModel.currentStudentCount.toString(),
                  label: 'students'.tr(),
                ),
              ),
              const SizedBox(width: 12),

              // 2. Toplam Görev Sayısı
              Expanded(
                child: _buildStatCard(
                  icon: Icons.assignment_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  value: viewModel.totalTaskCount.toString(), // Provider'a bağlandı
                  label: 'total_tasks'.tr(),
                ),
              ),
              const SizedBox(width: 12),

              // 3. Başarı Oranı (Completion)
              Expanded(
                child: _buildStatCard(
                  icon: Icons.pie_chart_rounded,
                  iconColor: const Color(0xFF10B981),
                  value: viewModel.overallCompletionPercentage, // Provider'a bağlandı
                  label: 'completion'.tr(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget  _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F2937).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- GÜNCELLENEN GÖREV LİSTESİ İÇERİĞİ ---
  Widget _buildTasksContent(ClassDetailViewModel viewModel) {
    if (viewModel.isLoading && viewModel.tasks.isEmpty) {
      return Container(
        height: 200,
        color: const Color(0xFFF9FAFB),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Sıralanmış listeyi al
    final sortedTasks = _getSortedTasks();

    return ExpandableTasksSection(
      tasks: sortedTasks, // Sıralı listeyi gönder
      taskStats: _taskStats, // İstatistikleri gönder
      students: viewModel.students, // Öğrenci listesini gönder (İsim bulmak için)
      currentSort: _selectedSort, // Mevcut sıralama seçeneği
      onSortChanged: (newSort) { // Sıralama değiştiğinde tetiklenir
        setState(() {
          _selectedSort = newSort;
        });
      },
      onTaskTap: (task) async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MentorTaskDetailView(taskId: task.id),
          ),
        );

        if (result == true && mounted) {
          await _viewModel.refresh();
          // Detaydan dönünce o task'ın verisini sil ki yeniden güncelini çeksin
          setState(() {
            _taskStats.remove(task.id);
          });
          _loadTaskStats();
        }
      },
    );
  }

  // --- ÖĞRENCİ LİSTESİ İÇERİĞİ (Değişmedi) ---
  Widget _buildStudentsContent(ClassDetailViewModel viewModel) {
    if (viewModel.isLoading && viewModel.students.isEmpty) {
      return Container(
        height: 200,
        color: const Color(0xFFF9FAFB),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'students'.tr(),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  // Butona basıldığında limit kontrolü yapıyoruz
                  final bool canAddMore = await viewModel.checkStudentLimit();

                  if (mounted) {
                    if (canAddMore) {
                      // Limit uygunsa kodu göster
                      _showInviteCodeDialog();
                    } else {
                      // Limit dolmuşsa Premium uyarısını/yönlendirmesini göster
                      _showStudentLimitDialog();
                    }
                  }
                },
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: Text('add_student'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Listenin geri kalanı aynı...
        viewModel.students.isEmpty
            ? _buildEmptyStudentsState()
            : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: viewModel.students.map((student) {
              final index = viewModel.students.indexOf(student);
              final studentId = student['uid'] ?? student['id'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    if (studentId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentProfilePage(studentId: studentId),
                        ),
                      );
                    }
                  },
                  child: _buildStudentCard(
                    name: student['name'] ?? 'Unknown',
                    email: student['email'] ?? '',
                    initials: _getInitials(student['name'] ?? 'U'),
                    color: _getColorForIndex(index),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- HEADER ---
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
                      // TODO: Show menu
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

  // --- TAB BAR ---
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
        onTap: (index) {
          setState(() {});
        },
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined, size: 20),
                SizedBox(width: 8),
                Text('tasks'.tr()),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline_rounded, size: 20),
                SizedBox(width: 8),
                Text('students'.tr()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS & DIALOGS ---

  Widget _buildEmptyStudentsState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'no_students_yet'.tr(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'share_code_invite'.tr(),
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
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  void _showCreateAnnouncementDialog() {
    showDialog(
      context: context,
      builder: (context) => AnnouncementDialog(
        onSave: (title, description) async {
          final mentorId = _localStorage.getUid();
          if (mentorId == null) {
            throw 'User not logged in';
          }

          final success = await _viewModel.createAnnouncement(
            mentorId: mentorId,
            title: title,
            description: description,
          );

          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Text('success_announcement_created'.tr()),
                  ],
                ),
                backgroundColor: Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildStudentLimitBanner(ClassDetailViewModel viewModel) {
    // Kullanıcı zaten premium ise banner'ı gizle
    if (viewModel.isPremium) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () {
          // TODO: PremiumView sayfasına yönlendir
          // Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumView()));
        },
        child: Row(
          children: [
            const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Color(0xFF92400E), fontSize: 12),
                  children: [
                    TextSpan(
                        text: 'student_limit_banner_info'
                            .tr(args: [viewModel.maxStudentLimit.toString()])),
                    TextSpan(
                      text: ' ${'upgrade_now'.tr()}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAnnouncementDialog(AnnouncementModel announcement) {
    showDialog(
      context: context,
      builder: (context) => AnnouncementDialog(
        announcement: announcement,
        onSave: (title, description) async {
          final success = await _viewModel.updateAnnouncement(
            announcementId: announcement.id,
            title: title,
            description: description,
          );

          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Text('success_announcement_updated'.tr()),
                  ],
                ),
                backgroundColor: Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        onDelete: () async {
          final success = await _viewModel.deleteAnnouncement(announcement.id);

          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Text('success_announcement_deleted'.tr()),
                  ],
                ),
                backgroundColor: Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  void _showInviteCodeDialog() {
    // ViewModel üzerinden güncel limit bilgilerini alıyoruz
    final bool isPremium = _viewModel.isPremium;
    final int maxLimit = _viewModel.maxStudentLimit;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF6366F1), size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'class_code'.tr(),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 8),

              // --- GÜNCELLENEN BİLGİ ALANI ---
              if (!isPremium) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'free_plan_student_limit_info'.tr(args: [maxLimit.toString()]),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumView()));
                        },
                        child: Text(
                          'upgrade_for_unlimited'.tr(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // ------------------------------

              Text(
                'ask_students_code'.tr(),
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3), width: 2),
                ),
                child: Text(
                  widget.classData.classCode,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF6366F1), letterSpacing: 4),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _copyCodeToClipboard(widget.classData.classCode),
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  label: Text('copy_code'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('close'.tr(), style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
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
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text('code_copied'.tr()),
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