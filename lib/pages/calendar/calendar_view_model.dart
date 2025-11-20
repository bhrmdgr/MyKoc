import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:mykoc/pages/tasks/task_model.dart';
import 'package:mykoc/pages/calendar/calendar_note_model.dart';
import 'package:mykoc/firebase/tasks/task_service.dart';
import 'package:mykoc/firebase/calendar/calendar_service.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';

class CalendarViewModel extends ChangeNotifier {
  // Servisler
  final TaskService _taskService = TaskService();
  final CalendarService _calendarService = CalendarService();
  final LocalStorageService _localStorage = LocalStorageService();

  // Calendar State
  CalendarFormat _calendarFormat = CalendarFormat.month;
  CalendarFormat get calendarFormat => _calendarFormat;

  DateTime _focusedDay = DateTime.now();
  DateTime get focusedDay => _focusedDay;

  DateTime? _selectedDay;
  DateTime? get selectedDay => _selectedDay;

  // Data State
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<TaskModel> _allTasks = [];
  List<TaskModel> _selectedDayTasks = [];
  List<TaskModel> get selectedDayTasks => _selectedDayTasks;

  // Notes State
  Map<DateTime, CalendarNoteModel> _notes = {};
  bool _isEditingNote = false;
  bool get isEditingNote => _isEditingNote;

  String get currentDayNoteContent {
    if (_selectedDay == null) return '';
    final normalizedDate = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    return _notes[normalizedDate]?.content ?? '';
  }

  // --- INIT ---
  Future<void> initialize() async {
    _isLoading = true;
    _selectedDay = _focusedDay;
    notifyListeners();

    final uid = _localStorage.getUid();
    if (uid == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    // 1. Taskları Çek
    try {
      final isMentor = _localStorage.isMentor();
      if (isMentor) {
        final classes = _localStorage.getClassesList();
        if (classes != null && classes.isNotEmpty) {
          // Tüm sınıfların tasklarını toplayalım
          List<TaskModel> allClassTasks = [];
          for (var cls in classes) {
            final tasks = await _taskService.getClassTasks(cls['id']);
            allClassTasks.addAll(tasks);
          }
          _allTasks = allClassTasks;
        }
      } else {
        _allTasks = await _taskService.getStudentTasks(uid);
      }
    } catch (e) {
      debugPrint('Error fetching tasks: $e');
    }

    // 2. Notları Localden Yükle
    _loadNotesFromLocal();

    // 3. Seçili günün verilerini güncelle
    _updateSelectedDayTasks();

    _isLoading = false;
    notifyListeners();

    // 4. Firebase Not Senkronizasyonu
    await _syncNotesFromFirebase(uid);
  }

  // --- EVENT LOADER (TAKVİM İŞARETÇİLERİ İÇİN) ---
  // Bu metot takvimdeki her gün için çalışır ve o güne ait hem notu hem taskları döndürür.
  List<dynamic> getEventsForDay(DateTime day) {
    List<dynamic> events = [];

    // 1. O güne ait taskları ekle
    final tasksForDay = _allTasks.where((task) => isSameDay(task.dueDate, day));
    events.addAll(tasksForDay);

    // 2. O güne ait not varsa ekle
    final normalizedDate = DateTime(day.year, day.month, day.day);
    if (_notes.containsKey(normalizedDate)) {
      events.add(_notes[normalizedDate]);
    }

    return events;
  }

  // --- CALENDAR ACTIONS ---

  void onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _isEditingNote = false;
      _updateSelectedDayTasks();
      notifyListeners();
    }
  }

  void onFormatChanged(CalendarFormat format) {
    _calendarFormat = format;
    notifyListeners();
  }

  void onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    notifyListeners();
  }

  void toggleEditingNote() {
    _isEditingNote = !_isEditingNote;
    notifyListeners();
  }

  // --- TASK LOGIC ---

  void _updateSelectedDayTasks() {
    if (_selectedDay == null) return;
    _selectedDayTasks = _allTasks.where((task) {
      return isSameDay(task.dueDate, _selectedDay);
    }).toList();
  }

  // --- NOTE LOGIC ---

  void _loadNotesFromLocal() {
    final storedData = _localStorage.getCalendarNotes();
    final Map<DateTime, CalendarNoteModel> loadedNotes = {};

    storedData.forEach((key, value) {
      final date = DateTime.parse(key);
      final note = CalendarNoteModel.fromMap(value);
      final normalizedDate = DateTime(date.year, date.month, date.day);
      loadedNotes[normalizedDate] = note;
    });

    _notes = loadedNotes;
  }

  Future<void> _syncNotesFromFirebase(String uid) async {
    try {
      final cloudNotes = await _calendarService.getUserNotes(uid);
      final Map<String, dynamic> mapForStorage = {};
      final Map<DateTime, CalendarNoteModel> updatedNotesMap = {};

      for (var note in cloudNotes) {
        final normalizedDate = DateTime(note.date.year, note.date.month, note.date.day);
        updatedNotesMap[normalizedDate] = note;
        mapForStorage[note.date.toIso8601String()] = note.toMap();
      }

      await _localStorage.saveCalendarNotes(mapForStorage);
      _notes = updatedNotesMap;
      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing notes: $e');
    }
  }

  Future<bool> saveNote(String content) async {
    final uid = _localStorage.getUid();
    if (uid == null || _selectedDay == null) return false;

    final normalizedDate = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final trimmedContent = content.trim();

    if (trimmedContent.isEmpty) {
      if (_notes.containsKey(normalizedDate)) {
        _notes.remove(normalizedDate);
        _updateLocalCache();
        notifyListeners();
        await _calendarService.deleteNote(uid, normalizedDate);
      }
    } else {
      final newNote = CalendarNoteModel(
        id: '${uid}_${normalizedDate.millisecondsSinceEpoch}',
        userId: uid,
        date: normalizedDate,
        content: trimmedContent,
        updatedAt: DateTime.now(),
      );

      _notes[normalizedDate] = newNote;
      _updateLocalCache();
      notifyListeners();
      await _calendarService.saveNote(userId: uid, date: normalizedDate, content: trimmedContent);
    }

    _isEditingNote = false;
    notifyListeners();
    return true;
  }

  void _updateLocalCache() {
    final Map<String, dynamic> mapForStorage = {};
    _notes.forEach((key, value) {
      mapForStorage[key.toIso8601String()] = value.toMap();
    });
    _localStorage.saveCalendarNotes(mapForStorage);
  }
}