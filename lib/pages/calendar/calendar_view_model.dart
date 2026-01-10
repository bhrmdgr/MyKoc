import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:mykoc/pages/tasks/task_model.dart';
import 'package:mykoc/pages/calendar/calendar_note_model.dart';
import 'package:mykoc/firebase/tasks/task_service.dart';
import 'package:mykoc/firebase/calendar/calendar_service.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';

class CalendarViewModel extends ChangeNotifier {
  final TaskService _taskService = TaskService();
  final CalendarService _calendarService = CalendarService();
  final LocalStorageService _localStorage = LocalStorageService();

  bool _isDisposed = false;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  CalendarFormat get calendarFormat => _calendarFormat;

  DateTime _focusedDay = DateTime.now();
  DateTime get focusedDay => _focusedDay;

  DateTime? _selectedDay;
  DateTime? get selectedDay => _selectedDay;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<TaskModel> _allTasks = [];
  List<TaskModel> _selectedDayTasks = [];
  List<TaskModel> get selectedDayTasks => _selectedDayTasks;

  Map<DateTime, CalendarNoteModel> _notes = {};
  bool _isEditingNote = false;
  bool get isEditingNote => _isEditingNote;

  // --- YENİ EKLENEN KISIM: ROL KONTROLÜ ---
  bool get isMentor => _localStorage.isMentor();

  String get currentDayNoteContent {
    if (_selectedDay == null) return '';
    final normalizedDate = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    return _notes[normalizedDate]?.content ?? '';
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) notifyListeners();
  }

  // --- INIT: Önce Yerel Veri -> Sonra Firebase ---
  Future<void> initialize() async {
    _isLoading = true;
    _selectedDay = _focusedDay;
    _safeNotifyListeners();

    final uid = _localStorage.getUid();
    if (uid == null) {
      _isLoading = false;
      _safeNotifyListeners();
      return;
    }

    // 1. Önce Localden Yükle (Hız İçin)
    _loadDataFromLocal();
    _updateSelectedDayTasks();

    // Eğer yerelde veri varsa loading'i kapat ki kullanıcı takvimi hemen görsün
    if (_allTasks.isNotEmpty || _notes.isNotEmpty) {
      _isLoading = false;
      _safeNotifyListeners();
    }

    // 2. Arka Planda Firebase Senkronizasyonu
    await _syncWithFirebase(uid);

    _isLoading = false;
    _safeNotifyListeners();
  }

  void _loadDataFromLocal() {
    // Notları Yükle
    final storedNotes = _localStorage.getCalendarNotes();
    _notes = {};
    storedNotes.forEach((key, value) {
      final date = DateTime.parse(key);
      final note = CalendarNoteModel.fromMap(value);
      _notes[DateTime(date.year, date.month, date.day)] = note;
    });

    // Taskları Yükle (HomeViewModel'in kaydettiği cache'i kullanıyoruz)
    final storedTasks = _localStorage.getStudentTasks();
    if (storedTasks != null) {
      _allTasks = storedTasks.map((t) => TaskModel.fromMap(t)).toList();
    }
  }

  Future<void> _syncWithFirebase(String uid) async {
    try {
      // Notları Senkronize Et
      final cloudNotes = await _calendarService.getUserNotes(uid);
      if (_isDisposed) return;

      final Map<String, dynamic> mapForStorage = {};
      _notes = {};
      for (var note in cloudNotes) {
        final normalizedDate = DateTime(note.date.year, note.date.month, note.date.day);
        _notes[normalizedDate] = note;
        mapForStorage[note.date.toIso8601String()] = note.toMap();
      }
      await _localStorage.saveCalendarNotes(mapForStorage);

      // Görevleri Senkronize Et (Güncel hali çek)
      if (!_localStorage.isMentor()) {
        final freshTasks = await _taskService.getStudentTasks(uid);
        _allTasks = freshTasks;
        await _localStorage.saveStudentTasks(_allTasks.map((t) => t.toMap()).toList());
      }

      _updateSelectedDayTasks();
      debugPrint('✅ Calendar synced with Firebase');
    } catch (e) {
      debugPrint('❌ Sync Error: $e');
    }
  }

  List<dynamic> getEventsForDay(DateTime day) {
    List<dynamic> events = [];
    final tasksForDay = _allTasks.where((task) => isSameDay(task.dueDate, day));
    events.addAll(tasksForDay);

    final normalizedDate = DateTime(day.year, day.month, day.day);
    if (_notes.containsKey(normalizedDate)) {
      events.add(_notes[normalizedDate]);
    }
    return events;
  }

  void onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _isEditingNote = false;
      _updateSelectedDayTasks();
      _safeNotifyListeners();
    }
  }

  void onFormatChanged(CalendarFormat format) {
    _calendarFormat = format;
    _safeNotifyListeners();
  }

  void onFormatChangedWithoutNotify(CalendarFormat format) {
    _calendarFormat = format;
  }

  void onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    _safeNotifyListeners();
  }

  void toggleEditingNote() {
    _isEditingNote = !_isEditingNote;
    _safeNotifyListeners();
  }

  void _updateSelectedDayTasks() {
    if (_selectedDay == null) return;
    _selectedDayTasks = _allTasks.where((task) => isSameDay(task.dueDate, _selectedDay)).toList();
  }

  Future<bool> saveNote(String content) async {
    final uid = _localStorage.getUid();
    if (uid == null || _selectedDay == null) {
      debugPrint('❌ SaveNote Hatası: UID veya Seçili Gün eksik.');
      return false;
    }

    final normalizedDate = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final trimmedContent = content.trim();

    // UI'da hemen göstermek için geçici yedek alalım (Hata olursa geri döneceğiz)
    final oldNote = _notes[normalizedDate];

    try {
      if (trimmedContent.isEmpty) {
        // 1. Durum: Notu Silme
        _notes.remove(normalizedDate); // UI'dan anında kaldır

        bool isSuccess = await _calendarService.deleteNote(uid, normalizedDate);

        if (!isSuccess) {
          // Firebase silme başarısızsa eski notu geri getir
          if (oldNote != null) _notes[normalizedDate] = oldNote;
          throw Exception("Firebase silme işlemi başarısız.");
        }
      } else {
        // 2. Durum: Notu Kaydetme veya Güncelleme
        final newNote = CalendarNoteModel(
          id: '${uid}_${normalizedDate.millisecondsSinceEpoch}',
          userId: uid,
          date: normalizedDate,
          content: trimmedContent,
          updatedAt: DateTime.now(),
        );

        // UI'yı güncelle
        _notes[normalizedDate] = newNote;

        // Firebase'e gönder ve BEKLE (await)
        bool isSuccess = await _calendarService.saveNote(
          userId: uid,
          date: normalizedDate,
          content: trimmedContent,
        );

        if (!isSuccess) {
          // Firebase kayıt başarısızsa UI'yı eski haline döndür
          if (oldNote != null) {
            _notes[normalizedDate] = oldNote;
          } else {
            _notes.remove(normalizedDate);
          }
          throw Exception("Firebase kayıt işlemi başarısız.");
        }
      }

      // 3. Her şey başarılıysa Yerel Cache'i güncelle
      _updateLocalNoteCache();
      _isEditingNote = false;
      _safeNotifyListeners();

      debugPrint('✅ Not başarıyla Firebase ve Yerel Hafızaya kaydedildi.');
      return true;

    } catch (e) {
      debugPrint('❌ saveNote Kritik Hata: $e');
      _safeNotifyListeners(); // UI'daki değişikliği geri almak için
      return false;
    }
  }

  void _updateLocalNoteCache() {
    final Map<String, dynamic> mapForStorage = {};
    _notes.forEach((key, value) {
      mapForStorage[key.toIso8601String()] = value.toMap();
    });
    _localStorage.saveCalendarNotes(mapForStorage);
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}