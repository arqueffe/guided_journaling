import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'emotion_detector.dart';
import 'note_storage.dart';
import 'emotion_analysis_widget.dart';
import 'title_generator.dart';
import 'smollm2_service.dart';
import 'questioning_agent.dart';

// Global emotion detector instance
final emotionDetector = EmotionDetector();
// Global SmolLM2 service (shared by all agents)
final smollm2Service = SmolLM2Service();
// Global title generator instance
late final TitleGenerator titleGenerator;
// Global questioning agent instance
late final QuestioningAgent questioningAgent;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Get temporary directory for both models
  final tempDir = await getTemporaryDirectory();
  print('Temp directory: ${tempDir.path}');

  // Initialize emotion detector
  try {
    // Load model bytes directly from assets
    final modelData = await rootBundle.load('assets/bert-emotion/model.onnx');
    final modelBytes = modelData.buffer.asUint8List();
    print('Model loaded: ${modelBytes.length} bytes');

    // Copy vocab from assets to temp directory (tokenizer needs file path)
    final vocabData = await rootBundle.load('assets/bert-emotion/vocab.txt');
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

  // Initialize SmolLM2 service (shared by all agents)
  try {
    final titleModelData = await rootBundle.load('assets/smollm2/model.onnx');
    final titleModelBytes = titleModelData.buffer.asUint8List();
    print('SmolLM2 model loaded: ${titleModelBytes.length} bytes');

    // Copy tokenizer files to temp directory
    final vocabJsonData = await rootBundle.load('assets/smollm2/vocab.json');
    final vocabJsonPath = '${tempDir.path}${Platform.pathSeparator}vocab.json';
    final vocabJsonFile = File(vocabJsonPath);
    await vocabJsonFile.writeAsBytes(
      vocabJsonData.buffer.asUint8List(),
      flush: true,
    );

    final mergesData = await rootBundle.load('assets/smollm2/merges.txt');
    final mergesPath = '${tempDir.path}${Platform.pathSeparator}merges.txt';
    final mergesFile = File(mergesPath);
    await mergesFile.writeAsBytes(mergesData.buffer.asUint8List(), flush: true);

    await smollm2Service.initialize(titleModelBytes, vocabJsonPath, mergesPath);
    print('SmolLM2 service initialized');
  } catch (e) {
    print('Failed to initialize SmolLM2 service: $e');
  }

  // Initialize agents that use the shared service (always initialize, even if service failed)
  titleGenerator = TitleGenerator(smollm2Service);
  questioningAgent = QuestioningAgent(smollm2Service);
  print('Title generator and questioning agent initialized');

  runApp(const MyApp());
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
  final NoteStorage _storage = NoteStorage();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await _storage.loadNotes();
    if (mounted) {
      setState(() {
        _notes.clear();
        _notes.addAll(notes);
      });
    }
  }

  void _createNote() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateNoteScreen()),
    );

    if (result != null && result is String) {
      final content = result;

      // Show loading dialog for processing
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing note...'),
              ],
            ),
          ),
        );
      }

      // Generate title
      String title = 'Untitled Note';
      if (titleGenerator.isInitialized && content.trim().isNotEmpty) {
        try {
          title = await titleGenerator.generateTitle(content);
          print('Generated title: $title');
        } catch (e) {
          print('Error generating title: $e');
        }
      }

      // Analyze emotions if detector is initialized
      List<Map<String, dynamic>>? emotions;
      if (emotionDetector.isInitialized && content.trim().isNotEmpty) {
        try {
          emotions = await emotionDetector.analyzeSentences(content);
        } catch (e) {
          print('Error analyzing emotions: $e');
        }
      }

      final note = Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        content: content,
        createdAt: DateTime.now(),
        emotionAnalysis: emotions,
      );

      if (mounted) {
        await _storage.addNote(note, _notes);

        // Close loading dialog
        Navigator.of(context).pop();

        setState(() {
          // UI will update with the new note
        });

        print('Note saved successfully. Total notes: ${_notes.length}');
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
          : SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: EmotionAnalysisWidget(notes: notes),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];

                      // Get dominant emotion for preview
                      String? dominantEmotion;
                      if (note.emotionAnalysis != null &&
                          note.emotionAnalysis!.isNotEmpty) {
                        Map<String, int> emotionCounts = {};
                        for (var analysis in note.emotionAnalysis!) {
                          final emotion =
                              analysis['emotion'] as Map<String, dynamic>;
                          final label = emotion['label'] as String;
                          final score = emotion['score'] as double;
                          // Only consider emotions with confidence >= 60%
                          if (score >= 0.6) {
                            emotionCounts[label] =
                                (emotionCounts[label] ?? 0) + 1;
                          }
                        }
                        // Sort by count and skip neutral if it's the top emotion
                        final sortedEmotions = emotionCounts.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value));

                        if (sortedEmotions.isNotEmpty) {
                          // Use the top emotion if it's not neutral, otherwise use the second
                          if (sortedEmotions[0].key.toLowerCase() !=
                              'neutral') {
                            dominantEmotion = sortedEmotions[0].key;
                          } else if (sortedEmotions.length > 1) {
                            dominantEmotion = sortedEmotions[1].key;
                          } else {
                            // Only neutral exists, still use it for display
                            dominantEmotion = sortedEmotions[0].key;
                          }
                        }
                      }

                      return ListTile(
                        leading: dominantEmotion != null
                            ? Icon(
                                _getEmotionIcon(dominantEmotion),
                                color: _getEmotionColor(dominantEmotion),
                              )
                            : const Icon(Icons.note),
                        title: Text(note.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${note.createdAt.day}/${note.createdAt.month}/${note.createdAt.year} ${note.createdAt.hour}:${note.createdAt.minute.toString().padLeft(2, '0')}',
                            ),
                            if (dominantEmotion != null)
                              Text(
                                'Mood: $dominantEmotion',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getEmotionColor(dominantEmotion),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
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
                ],
              ),
            ),
    );
  }

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

  IconData _getEmotionIcon(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'sadness':
        return Icons.sentiment_very_dissatisfied;
      case 'anger':
        return Icons.sentiment_very_dissatisfied;
      case 'love':
        return Icons.favorite;
      case 'surprise':
        return Icons.sentiment_satisfied;
      case 'fear':
        return Icons.warning;
      case 'happiness':
        return Icons.sentiment_very_satisfied;
      case 'neutral':
        return Icons.sentiment_neutral;
      case 'disgust':
        return Icons.sick;
      case 'shame':
        return Icons.face;
      case 'guilt':
        return Icons.psychology;
      case 'confusion':
        return Icons.help_outline;
      case 'desire':
        return Icons.favorite_border;
      case 'sarcasm':
        return Icons.chat_bubble_outline;
      default:
        return Icons.mood;
    }
  }
}

class CreateNoteScreen extends StatefulWidget {
  const CreateNoteScreen({super.key});

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  final TextEditingController _contentController = TextEditingController();
  bool _isLoadingQuestion = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _saveNote() {
    if (_contentController.text.trim().isNotEmpty) {
      Navigator.pop(context, _contentController.text.trim());
    }
  }

  Future<void> _askQuestion() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Write something first before asking for a question!'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!questioningAgent.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Questioning agent is not initialized yet'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isLoadingQuestion = true;
    });

    try {
      print('Attempting to generate question...');
      final question = await questioningAgent.generateQuestion(
        _contentController.text,
      );
      print('Question generated successfully: $question');

      if (mounted) {
        setState(() {
          _isLoadingQuestion = false;
        });

        // Show the question in a dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber),
                SizedBox(width: 8),
                Text('Reflection Question'),
              ],
            ),
            content: Text(question, style: const TextStyle(fontSize: 16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error generating question: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isLoadingQuestion = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
          ),
        );
      }
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
            Expanded(
              child: TextField(
                controller: _contentController,
                autofocus: true,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText:
                      'Write your note here...\n\n(Title will be generated automatically)',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoadingQuestion ? null : _askQuestion,
        tooltip: 'Get a reflection question',
        backgroundColor: _isLoadingQuestion
            ? Colors.grey
            : Theme.of(context).colorScheme.secondary,
        child: _isLoadingQuestion
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.psychology),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                note.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${note.createdAt.day}/${note.createdAt.month}/${note.createdAt.year} ${note.createdAt.hour}:${note.createdAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const Divider(height: 24),
              if (note.emotionAnalysis != null &&
                  note.emotionAnalysis!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: EmotionAnalysisWidget(notes: [note]),
                ),
              if (note.emotionAnalysis != null &&
                  note.emotionAnalysis!.isNotEmpty)
                Wrap(
                  children: note.emotionAnalysis!.map((analysis) {
                    final sentence = analysis['sentence'] as String;
                    final emotion = analysis['emotion'] as Map<String, dynamic>;
                    final label = emotion['label'] as String;
                    final score = emotion['score'] as double;

                    // Check if confidence is below 60%
                    final isLowConfidence = score < 0.6;
                    final displayColor = isLowConfidence
                        ? Colors.grey.shade400
                        : _getEmotionColor(label);

                    return Tooltip(
                      message: isLowConfidence
                          ? 'Unknown (low confidence: ${(score * 100).toStringAsFixed(1)}%)'
                          : '$label (${(score * 100).toStringAsFixed(1)}%)',
                      decoration: BoxDecoration(
                        color: displayColor,
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
                                color: displayColor.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            sentence,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: isLowConfidence
                                  ? Colors.grey.shade600
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                )
              else
                Text(note.content, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
