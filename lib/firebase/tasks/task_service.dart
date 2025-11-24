import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mykoc/pages/tasks/task_model.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Task oluştur
  Future<String?> createTask({
    required String classId,
    required String mentorId,
    required String title,
    required String description,
    required String priority,
    required DateTime dueDate,
    List<String>? attachments,
    List<String>? assignedStudents, // Boş ise tüm sınıfa atanır
  }) async {
    try {
      final taskData = {
        'classId': classId,
        'mentorId': mentorId,
        'title': title,
        'description': description,
        'priority': priority,
        'dueDate': Timestamp.fromDate(dueDate),
        'createdAt': FieldValue.serverTimestamp(),
        'attachments': attachments,
        'assignedStudents': assignedStudents ?? [],
      };

      // Task'ı oluştur
      final taskRef = await _firestore.collection('tasks').add(taskData);

      // Öğrencilere task ata
      if (assignedStudents != null && assignedStudents.isNotEmpty) {
        // Belirli öğrencilere ata
        for (var studentId in assignedStudents) {
          await _firestore
              .collection('students')
              .doc(studentId)
              .collection('tasks')
              .doc(taskRef.id)
              .set({
            'status': 'not_started',
            'assignedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Tüm sınıfa ata - sınıftaki tüm öğrencileri çek
        final classStudents = await _firestore
            .collection('classes')
            .doc(classId)
            .collection('students')
            .get();

        final studentIds = <String>[];
        for (var studentDoc in classStudents.docs) {
          studentIds.add(studentDoc.id);
          await _firestore
              .collection('students')
              .doc(studentDoc.id)
              .collection('tasks')
              .doc(taskRef.id)
              .set({
            'status': 'not_started',
            'assignedAt': FieldValue.serverTimestamp(),
          });
        }

        // assignedStudents listesini güncelle
        await _firestore.collection('tasks').doc(taskRef.id).update({
          'assignedStudents': studentIds,
        });
      }

      // Sınıfın task sayısını artır
      await _firestore.collection('classes').doc(classId).update({
        'taskCount': FieldValue.increment(1),
      });

      debugPrint('✅ Task created: ${taskRef.id}');
      return taskRef.id;
    } catch (e) {
      debugPrint('❌ Error creating task: $e');
      return null;
    }
  }

  /// Öğrencinin görevlerini çek (status bilgisi ile)
  Future<List<TaskModel>> getStudentTasks(String studentId) async {
    try {
      debugPrint('🔍 Fetching tasks for student: $studentId');

      // Öğrencinin tasks sub-collection'ındaki tüm task ID'lerini al
      final studentTasksSnapshot = await _firestore
          .collection('students')
          .doc(studentId)
          .collection('tasks')
          .get();

      final tasks = <TaskModel>[];

      for (var studentTaskDoc in studentTasksSnapshot.docs) {
        final taskId = studentTaskDoc.id;

        // Ana task verisini çek
        final taskDoc = await _firestore.collection('tasks').doc(taskId).get();

        if (!taskDoc.exists) continue;

        final task = TaskModel.fromFirestore(taskDoc);
        final statusData = studentTaskDoc.data();

        debugPrint('📋 Task: ${task.title}');
        debugPrint('   Status from Firestore: "${statusData['status']}"');

        // Status bilgisini ekle
        final taskWithStatus = task.copyWith(
          status: statusData['status'] ?? 'not_started',
          completedAt: statusData['completedAt'] != null
              ? (statusData['completedAt'] as Timestamp).toDate()
              : null,
          completionNote: statusData['completionNote'],
          completionAttachments: statusData['completionAttachments'] != null
              ? List<String>.from(statusData['completionAttachments'])
              : null,
        );

        debugPrint('   Final status in model: "${taskWithStatus.status}"');
        tasks.add(taskWithStatus);
      }

      // Due date'e göre sırala
      tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));

      debugPrint('✅ Found ${tasks.length} tasks for student');
      return tasks;
    } catch (e) {
      debugPrint('❌ Error fetching student tasks: $e');
      return [];
    }
  }

  /// Sınıfın görevlerini çek
  Future<List<TaskModel>> getClassTasks(String classId) async {
    try {
      final snapshot = await _firestore
          .collection('tasks')
          .where('classId', isEqualTo: classId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TaskModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching class tasks: $e');
      return [];
    }
  }

  /// Task'ı başlat
  Future<bool> startTask({
    required String taskId,
    required String studentId,
  }) async {
    try {
      await _firestore
          .collection('students')
          .doc(studentId)
          .collection('tasks')
          .doc(taskId)
          .update({
        'status': 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Task started');
      return true;
    } catch (e) {
      debugPrint('❌ Error starting task: $e');
      return false;
    }
  }

  /// Task'ı tamamla
  Future<bool> completeTask({
    required String taskId,
    required String studentId,
    String? completionNote,
    List<String>? completionAttachments,
  }) async {
    try {
      final updateData = {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (completionNote != null) {
        updateData['completionNote'] = completionNote;
      }

      if (completionAttachments != null && completionAttachments.isNotEmpty) {
        updateData['completionAttachments'] = completionAttachments;
      }

      await _firestore
          .collection('students')
          .doc(studentId)
          .collection('tasks')
          .doc(taskId)
          .update(updateData);

      debugPrint('✅ Task completed');
      return true;
    } catch (e) {
      debugPrint('❌ Error completing task: $e');
      return false;
    }
  }

  /// Tek bir task'ın detayını çek (öğrenci için - status bilgisi ile)
  Future<TaskModel?> getTaskDetail({
    required String taskId,
    required String studentId,
  }) async {
    try {
      // Ana task verisini çek
      final taskDoc = await _firestore.collection('tasks').doc(taskId).get();

      if (!taskDoc.exists) {
        debugPrint('❌ Task not found');
        return null;
      }

      final task = TaskModel.fromFirestore(taskDoc);

      // Öğrencinin status bilgisini çek
      final studentTaskDoc = await _firestore
          .collection('students')
          .doc(studentId)
          .collection('tasks')
          .doc(taskId)
          .get();

      if (studentTaskDoc.exists) {
        final statusData = studentTaskDoc.data()!;
        return task.copyWith(
          status: statusData['status'] ?? 'not_started',
          completedAt: statusData['completedAt'] != null
              ? (statusData['completedAt'] as Timestamp).toDate()
              : null,
          completionNote: statusData['completionNote'],
          completionAttachments: statusData['completionAttachments'] != null
              ? List<String>.from(statusData['completionAttachments'])
              : null,
        );
      }

      return task.copyWith(status: 'not_started');
    } catch (e) {
      debugPrint('❌ Error fetching task detail: $e');
      return null;
    }
  }

  /// Mentor için: Task detayını tüm öğrenci durumları ile çek
  /// Mentor için: Task detayını tüm öğrenci durumları ile çek
  Future<TaskDetailWithStudents?> getTaskDetailWithStudents({
    required String taskId,
  }) async {
    try {
      debugPrint('📋 Fetching task detail with students: $taskId');

      // 1. Ana task verisini çek
      final taskDoc = await _firestore.collection('tasks').doc(taskId).get();

      if (!taskDoc.exists) {
        debugPrint('❌ Task not found');
        return null;
      }

      final task = TaskModel.fromFirestore(taskDoc);
      final assignedStudents = List<String>.from(task.assignedStudents ?? []);

      debugPrint('👥 Assigned Students Count: ${assignedStudents.length}');

      final studentStatuses = <StudentTaskStatus>[];

      for (var studentId in assignedStudents) {
        try {
          // ============================================================
          // DÜZELTME BURADA: Profil bilgisini 'users' koleksiyonundan çek
          // ============================================================

          DocumentSnapshot userDoc = await _firestore.collection('users').doc(studentId).get();

          // Eğer users'da bulamazsa (belki eski veri) fallback yap
          Map<String, dynamic> userData;
          if (userDoc.exists) {
            userData = userDoc.data() as Map<String, dynamic>;
          } else {
            // Users'da yoksa students'a bak (nadiren gerekir)
            final fallbackDoc = await _firestore.collection('students').doc(studentId).get();
            userData = fallbackDoc.exists ? (fallbackDoc.data() as Map<String, dynamic>) : {};
          }

          final studentName = userData['name'] ?? 'Unknown Student';
          final studentEmail = userData['email'] ?? '';
          // ============================================================

          // Öğrencinin task status'ünü çek (Burası DOĞRU, durum 'students' altında)
          final studentTaskDoc = await _firestore
              .collection('students')
              .doc(studentId)
              .collection('tasks')
              .doc(taskId)
              .get();

          String status = 'not_started';
          DateTime? completedAt;
          String? completionNote;
          List<String>? completionAttachments;

          if (studentTaskDoc.exists) {
            final statusData = studentTaskDoc.data()!;
            status = statusData['status'] ?? 'not_started';
            completedAt = statusData['completedAt'] != null
                ? (statusData['completedAt'] as Timestamp).toDate()
                : null;
            completionNote = statusData['completionNote'];
            completionAttachments = statusData['completionAttachments'] != null
                ? List<String>.from(statusData['completionAttachments'])
                : null;
          }

          studentStatuses.add(StudentTaskStatus(
            studentId: studentId,
            studentName: studentName, // Artık users'dan geliyor
            studentEmail: studentEmail, // Artık users'dan geliyor
            status: status,
            completedAt: completedAt,
            completionNote: completionNote,
            completionAttachments: completionAttachments,
          ));

        } catch (e) {
          debugPrint('❌ Error fetching student $studentId status: $e');
          continue;
        }
      }

      debugPrint('✅ Fetched task with ${studentStatuses.length} student statuses');

      return TaskDetailWithStudents(
        task: task,
        studentStatuses: studentStatuses,
      );

    } catch (e) {
      debugPrint('❌ Error fetching task detail with students: $e');
      return null;
    }
  }

  /// Görevi güncelle
  Future<bool> updateTask({
    required String taskId,
    String? title,
    String? description,
    DateTime? dueDate,
    String? priority,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (dueDate != null) updates['dueDate'] = Timestamp.fromDate(dueDate);
      if (priority != null) updates['priority'] = priority;

      if (updates.isEmpty) return false;

      await _firestore.collection('tasks').doc(taskId).update(updates);

      debugPrint('✅ Task updated successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating task: $e');
      return false;
    }
  }

  /// Görevi sil
  Future<bool> deleteTask(String taskId, String classId) async {
    try {
      // Task verisini al
      final task = await _firestore.collection('tasks').doc(taskId).get();
      final assignedStudents = List<String>.from(task.data()?['assignedStudents'] ?? []);

      final batch = _firestore.batch();

      // Her öğrencinin task kaydını sil
      for (var studentId in assignedStudents) {
        final studentTaskRef = _firestore
            .collection('students')
            .doc(studentId)
            .collection('tasks')
            .doc(taskId);
        batch.delete(studentTaskRef);
      }

      // Task'ı sil
      batch.delete(_firestore.collection('tasks').doc(taskId));

      // Class'ın task count'unu azalt
      batch.update(_firestore.collection('classes').doc(classId), {
        'taskCount': FieldValue.increment(-1),
      });

      await batch.commit();

      debugPrint('✅ Task deleted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting task: $e');
      return false;
    }
  }

  /// Görev durumunu güncelle (genel)
  Future<bool> updateTaskStatus({
    required String taskId,
    required String studentId,
    required String status,
  }) async {
    try {
      await _firestore
          .collection('students')
          .doc(studentId)
          .collection('tasks')
          .doc(taskId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Task status updated');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating task status: $e');
      return false;
    }
  }
}

// ==================== HELPER MODELS ====================

/// Öğrencinin task durumu
class StudentTaskStatus {
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String status;
  final DateTime? completedAt;
  final String? completionNote;
  final List<String>? completionAttachments;

  StudentTaskStatus({
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.status,
    this.completedAt,
    this.completionNote,
    this.completionAttachments,
  });
}

/// Task detayı + öğrenci durumları
class TaskDetailWithStudents {
  final TaskModel task;
  final List<StudentTaskStatus> studentStatuses;

  TaskDetailWithStudents({
    required this.task,
    required this.studentStatuses,
  });

  // İstatistikler
  int get notStartedCount => studentStatuses.where((s) => s.status == 'not_started' || s.status == null).length;
  int get inProgressCount => studentStatuses.where((s) => s.status == 'in_progress').length;
  int get completedCount => studentStatuses.where((s) => s.status == 'completed').length;
  int get totalStudents => studentStatuses.length;
}