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

      // Her öğrenci için görev kaydı oluştur (notification için)
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
          'status': 'pending',
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

  // Öğrencinin görevlerini çek
  Future<List<TaskModel>> getStudentTasks(String studentId) async {
    try {
      final snapshot = await _firestore
          .collection('tasks')
          .where('assignedStudents', arrayContains: studentId)
          .orderBy('dueDate', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => TaskModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching student tasks: $e');
      return [];
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

  // Görev durumunu güncelle (öğrenci için)
  Future<bool> updateTaskStatus({
    required String taskId,
    required String studentId,
    required String status, // 'pending', 'in_progress', 'completed'
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