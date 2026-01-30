import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'emotion_detector.dart';

// Global emotion detector instance
final emotionDetector = EmotionDetector();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize emotion detector
  try {
    // Get temporary directory to copy vocab
    final tempDir = await getTemporaryDirectory();
    print('Temp directory: ${tempDir.path}');

    // Load model bytes directly from assets
    final modelData = await rootBundle.load('assets/model.onnx');
    final modelBytes = modelData.buffer.asUint8List();
    print('Model loaded: ${modelBytes.length} bytes');

    // Copy vocab from assets to temp directory (tokenizer needs file path)
    final vocabData = await rootBundle.load('assets/vocab.txt');
    final vocabPath = '${tempDir.path}${Platform.pathSeparator}vocab.txt';
    final vocabFile = File(vocabPath);
    await vocabFile.writeAsBytes(vocabData.buffer.asUint8List(), flush: true);
    print('Vocab written to: $vocabPath (${await vocabFile.length()} bytes)');

    // Verify vocab file exists
    if (!await vocabFile.exists()) {
      throw Exception('Vocab file does not exist after writing');
    }

    await emotionDetector.initialize(modelBytes, vocabPath);
    print('Emotion detector initialized from assets');
  } catch (e) {
    print('Failed to initialize emotion detector: $e');
  }

  runApp(const MyApp());
}

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
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JournAI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<Note> _notes = [];

  void _createNote() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateNoteScreen()),
    );

    if (result != null && result is Map<String, String>) {
      // Analyze emotions if detector is initialized
      List<Map<String, dynamic>>? emotions;
      if (emotionDetector.isInitialized &&
          result['content']!.trim().isNotEmpty) {
        // Show loading dialog while analyzing emotions
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Analyzing emotions...'),
              ],
            ),
          ),
        );

        try {
          emotions = await emotionDetector.analyzeSentences(result['content']!);
        } catch (e) {
          print('Error analyzing emotions: $e');
        }

        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }
      }

      final note = Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: result['title']!,
        content: result['content']!,
        createdAt: DateTime.now(),
        emotionAnalysis: emotions,
      );

      if (mounted) {
        setState(() {
          _notes.add(note);
        });
      }
    }
  }

  void _viewHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HistoryScreen(notes: _notes)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('JournAI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View History',
            onPressed: _viewHistory,
          ),
        ],
      ),
      body: const Center(child: Text('Welcome to JournAI')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNote,
        tooltip: 'Create Note',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  final List<Note> notes;

  const HistoryScreen({super.key, required this.notes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Note History'),
      ),
      body: notes.isEmpty
          ? const Center(child: Text('No notes yet. Create your first note!'))
          : ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return ListTile(
                  leading: const Icon(Icons.note),
                  title: Text(note.title),
                  subtitle: Text(
                    '${note.createdAt.day}/${note.createdAt.month}/${note.createdAt.year} ${note.createdAt.hour}:${note.createdAt.minute.toString().padLeft(2, '0')}',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ViewNoteScreen(note: note),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class CreateNoteScreen extends StatefulWidget {
  const CreateNoteScreen({super.key});

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveNote() {
    if (_titleController.text.trim().isNotEmpty) {
      Navigator.pop(context, {
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Create Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save Note',
            onPressed: _saveNote,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Note title',
                border: InputBorder.none,
              ),
            ),
            const Divider(),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Write your note here...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ViewNoteScreen extends StatelessWidget {
  final Note note;

  const ViewNoteScreen({super.key, required this.note});

  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'sadness':
        return Colors.blue.shade600;
      case 'anger':
        return Colors.red.shade600;
      case 'love':
        return Colors.pink.shade400;
      case 'surprise':
        return Colors.orange.shade600;
      case 'fear':
        return Colors.purple.shade600;
      case 'happiness':
        return Colors.yellow.shade700;
      case 'neutral':
        return Colors.grey.shade600;
      case 'disgust':
        return Colors.green.shade700;
      case 'shame':
        return Colors.brown.shade600;
      case 'guilt':
        return Colors.deepOrange.shade700;
      case 'confusion':
        return Colors.teal.shade600;
      case 'desire':
        return Colors.pinkAccent.shade400;
      case 'sarcasm':
        return Colors.indigo.shade600;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('View Note'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              note.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${note.createdAt.day}/${note.createdAt.month}/${note.createdAt.year} ${note.createdAt.hour}:${note.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const Divider(height: 24),
            if (note.emotionAnalysis != null &&
                note.emotionAnalysis!.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    children: note.emotionAnalysis!.map((analysis) {
                      final sentence = analysis['sentence'] as String;
                      final emotion =
                          analysis['emotion'] as Map<String, dynamic>;
                      final label = emotion['label'] as String;
                      final score = emotion['score'] as double;

                      return Tooltip(
                        message:
                            '$label (${(score * 100).toStringAsFixed(1)}%)',
                        decoration: BoxDecoration(
                          color: _getEmotionColor(label),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.help,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _getEmotionColor(
                                    label,
                                  ).withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              sentence,
                              style: const TextStyle(fontSize: 16, height: 1.5),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    note.content,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
