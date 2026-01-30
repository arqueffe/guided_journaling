import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Note {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final List<Map<String, dynamic>>? emotionAnalysis;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.emotionAnalysis,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'emotionAnalysis': emotionAnalysis,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      emotionAnalysis: json['emotionAnalysis'] != null
          ? List<Map<String, dynamic>>.from(
              (json['emotionAnalysis'] as List).map(
                (item) => Map<String, dynamic>.from(item),
              ),
            )
          : null,
    );
  }
}

class NoteStorage {
  static const String _notesKey = 'journai_notes';

  Future<List<Note>> loadNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJson = prefs.getString(_notesKey);

      if (notesJson == null) {
        return [];
      }

      final List<dynamic> decodedList = json.decode(notesJson);
      return decodedList.map((item) => Note.fromJson(item)).toList();
    } catch (e) {
      print('Error loading notes: $e');
      return [];
    }
  }

  Future<void> saveNotes(List<Note> notes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJson = json.encode(
        notes.map((note) => note.toJson()).toList(),
      );
      await prefs.setString(_notesKey, notesJson);
    } catch (e) {
      print('Error saving notes: $e');
    }
  }

  Future<void> addNote(Note note, List<Note> currentNotes) async {
    currentNotes.add(note);
    await saveNotes(currentNotes);
  }

  Future<void> deleteNote(String noteId, List<Note> currentNotes) async {
    currentNotes.removeWhere((note) => note.id == noteId);
    await saveNotes(currentNotes);
  }

  Future<void> clearAllNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notesKey);
  }
}
