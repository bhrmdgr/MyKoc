import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mykoc/pages/tasks/task_model.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Görev oluştur
  Future<String?> createTask({
    required String classId,
    required String mentorId,
    required String title,
    required String description,
    required DateTime dueDate,
    required String priority,
    required List<String> assignedStudents,
    List<String>? attachments,
  }) async {
    try {
      final taskData = {
        'classId': classId,
        'mentorId': mentorId,
        'title': title,
        'description': description,
        'dueDate': Timestamp.fromDate(dueDate),
        'priority': priority,
        'assignedStudents': assignedStudents,
        'attachments': attachments ?? [],
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection('tasks').add(taskData);

      // Her öğrenci için görev kaydı oluştur (notification ve status tracking için)
      final batch = _firestore.batch();
      for (var studentId in assignedStudents) {
        final studentTaskRef = _firestore
            .collection('students')
            .doc(studentId)
            .collection('tasks')
            .doc(docRef.id);

        batch.set(studentTaskRef, {
          'taskId': docRef.id,
          'classId': classId,
          'title': title,
          'dueDate': Timestamp.fromDate(dueDate),
          'priority': priority,
          'status': 'not_started', // Varsayılan durum
          'assignedAt': FieldValue.serverTimestamp(),
        });
      }

      // Class'ın task count'unu artır
      final classRef = _firestore.collection('classes').doc(classId);
      batch.update(classRef, {
        'taskCount': FieldValue.increment(1),
      });

      await batch.commit();

      debugPrint('✅ Task created successfully: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating task: $e');
      return null;
    }
  }

  // Sınıfın görevlerini çek
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

  // Öğrencinin görevlerini çek (status bilgisi ile)
  Future<List<TaskModel>> getStudentTasks(String studentId) async {
    try {
      // Ana task verilerini çek
      final tasksSnapshot = await _firestore
          .collection('tasks')
          .where('assignedStudents', arrayContains: studentId)
          .orderBy('dueDate', descending: false)
          .get();

      // Her task için öğrencinin status bilgisini çek
      final tasks = <TaskModel>[];
      for (var taskDoc in tasksSnapshot.docs) {
        final task = TaskModel.fromFirestore(taskDoc);

        // Öğrencinin bu task için status bilgisini al
        final studentTaskDoc = await _firestore
            .collection('students')
            .doc(studentId)
            .collection('tasks')
            .doc(task.id)
            .get();

        debugPrint('📋 Task: ${task.title}');
        debugPrint('   Student task doc exists: ${studentTaskDoc.exists}');

        if (studentTaskDoc.exists) {
          final statusData = studentTaskDoc.data()!;
          debugPrint('   Status from Firestore: "${statusData['status']}"');
          final taskWithStatus = task.copyWith(
            status: statusData['status'] ?? 'not_started',
            startedAt: statusData['startedAt'] != null
                ? (statusData['startedAt'] as Timestamp).toDate()
                : null,
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
        } else {
          // Status bilgisi yoksa varsayılan değerle ekle
          debugPrint('   ⚠️  No student task doc found, defaulting to not_started');
          tasks.add(task.copyWith(status: 'not_started'));
        }
      }

      return tasks;
    } catch (e) {
      debugPrint('❌ Error fetching student tasks: $e');
      return [];
    }
  }

  // Task'ı başlat
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
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Task started');
      return true;
    } catch (e) {
      debugPrint('❌ Error starting task: $e');
      return false;
    }
  }

  // Task'ı tamamla
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

  // Tek bir task'ın detayını çek (öğrenci için - status bilgisi ile)
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
          startedAt: statusData['startedAt'] != null
              ? (statusData['startedAt'] as Timestamp).toDate()
              : null,
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

  // Mentor için: Task detayını tüm öğrenci durumları ile çek
  Future<TaskDetailWithStudents?> getTaskDetailWithStudents({
    required String taskId,
  }) async {
    try {
      debugPrint('📋 Fetching task detail with students: $taskId');

      // Ana task verisini çek
      final taskDoc = await _firestore.collection('tasks').doc(taskId).get();

      if (!taskDoc.exists) {
        debugPrint('❌ Task not found');
        return null;
      }

      final task = TaskModel.fromFirestore(taskDoc);

      // Her öğrenci için status bilgisini çek
      final studentStatuses = <StudentTaskStatus>[];

      for (var studentId in task.assignedStudents) {
        try {
          // Öğrenci bilgisini çek
          final studentDoc = await _firestore
              .collection('students')
              .doc(studentId)
              .get();

          if (!studentDoc.exists) continue;

          final studentData = studentDoc.data()!;
          final studentName = studentData['name'] ?? 'Unknown';
          final studentEmail = studentData['email'] ?? '';

          // Öğrencinin task status'ünü çek
          final studentTaskDoc = await _firestore
              .collection('students')
              .doc(studentId)
              .collection('tasks')
              .doc(taskId)
              .get();

          String status = 'not_started';
          DateTime? startedAt;
          DateTime? completedAt;
          String? completionNote;
          List<String>? completionAttachments;

          if (studentTaskDoc.exists) {
            final statusData = studentTaskDoc.data()!;
            status = statusData['status'] ?? 'not_started';
            startedAt = statusData['startedAt'] != null
                ? (statusData['startedAt'] as Timestamp).toDate()
                : null;
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
            studentName: studentName,
            studentEmail: studentEmail,
            status: status,
            startedAt: startedAt,
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

  // Görevi güncelle
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

  // Görevi sil
  Future<bool> deleteTask(String taskId, String classId) async {
    try {
      // Öğrencilerin task kayıtlarını sil
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

  // Görev durumunu güncelle (genel - eski metod, yeni metodlar kullanılmalı)
  Future<bool> updateTaskStatus({
    required String taskId,
    required String studentId,
    required String status, // 'not_started', 'in_progress', 'completed'
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
  final String status; // 'not_started', 'in_progress', 'completed'
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? completionNote;
  final List<String>? completionAttachments;

  StudentTaskStatus({
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.status,
    this.startedAt,
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