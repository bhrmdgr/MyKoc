import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mykoc/firebase/tasks/task_service.dart';
import 'package:mykoc/firebase/storage/storage_service.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';

class CreateTaskViewModel extends ChangeNotifier {
  final String classId;
  final List<Map<String, dynamic>> students;
  final TaskService _taskService = TaskService();
  final StorageService _storageService = StorageService();
  final LocalStorageService _localStorage = LocalStorageService();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  DateTime get dueDate => _dueDate;

  String _priority = 'medium';
  String get priority => _priority;

  bool _assignToAllStudents = true;
  bool get assignToAllStudents => _assignToAllStudents;

  Set<String> _selectedStudents = {};
  Set<String> get selectedStudents => _selectedStudents;

  List<File> _attachments = [];
  List<File> get attachments => _attachments;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  double _uploadProgress = 0.0;
  double get uploadProgress => _uploadProgress;

  CreateTaskViewModel({
    required this.classId,
    required this.students,
  });

  void setDueDate(DateTime date) {
    _dueDate = date;
    notifyListeners();
  }

  void setPriority(String priority) {
    _priority = priority;
    notifyListeners();
  }

  void setAssignToAll(bool value) {
    _assignToAllStudents = value;
    if (value) {
      _selectedStudents = students.map((s) => s['uid'] as String).toSet();
    } else {
      _selectedStudents.clear();
    }
    notifyListeners();
  }

  void toggleStudent(String studentId) {
    if (_selectedStudents.contains(studentId)) {
      _selectedStudents.remove(studentId);
    } else {
      _selectedStudents.add(studentId);
    }
    notifyListeners();
  }

  // Dosya seç
  Future<void> pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        for (var file in result.files) {
          if (file.path != null) {
            _attachments.add(File(file.path!));
          }
        }
        notifyListeners();
        debugPrint('✅ ${result.files.length} file(s) selected');
      }
    } catch (e) {
      debugPrint('❌ Error picking files: $e');
    }
  }

  // Dosyayı sil
  void removeAttachment(int index) {
    _attachments.removeAt(index);
    notifyListeners();
  }

  Future<bool> createTask() async {
    _isLoading = true;
    notifyListeners();

    try {
      final uid = _localStorage.getUid();
      if (uid == null) {
        throw 'User not found';
      }

      // Atanacak öğrencileri belirle
      final assignedStudents = _assignToAllStudents
          ? students.map((s) => s['uid'] as String).toList()
          : _selectedStudents.toList();

      // Dosyaları yükle
      List<String> uploadedUrls = [];
      if (_attachments.isNotEmpty) {
        debugPrint('📤 Uploading ${_attachments.length} files...');

        for (int i = 0; i < _attachments.length; i++) {
          final file = _attachments[i];
          final fileName = file.path.split('/').last;

          final url = await _storageService.uploadFile(
            file: file,
            path: 'tasks/$classId/${DateTime.now().millisecondsSinceEpoch}',
            onProgress: (progress) {
              _uploadProgress = ((i + progress) / _attachments.length);
              notifyListeners();
            },
          );

          if (url != null) {
            uploadedUrls.add(url);
            debugPrint('✅ Uploaded: $fileName');
          }
        }
      }

      final taskId = await _taskService.createTask(
        classId: classId,
        mentorId: uid,
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
        assignedStudents: assignedStudents,
        attachments: uploadedUrls.isNotEmpty ? uploadedUrls : null,
      );

      debugPrint('✅ Task created: $taskId');
      return taskId != null;
    } catch (e) {
      debugPrint('❌ Create task error: $e');
      return false;
    } finally {
      _isLoading = false;
      _uploadProgress = 0.0;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}