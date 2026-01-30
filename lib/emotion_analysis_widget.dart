import 'package:flutter/material.dart';
import 'note_storage.dart';

class EmotionAnalysisWidget extends StatelessWidget {
  final List<Note> notes;

  const EmotionAnalysisWidget({super.key, required this.notes});

  Map<String, int> _calculateEmotionStats() {
    Map<String, int> emotionCounts = {};

    for (var note in notes) {
      if (note.emotionAnalysis != null) {
        for (var analysis in note.emotionAnalysis!) {
          final emotion = analysis['emotion'] as Map<String, dynamic>;
          final label = emotion['label'] as String;
          emotionCounts[label] = (emotionCounts[label] ?? 0) + 1;
        }
      }
    }

    return emotionCounts;
  }

  Map<String, double> _calculateEmotionPercentages() {
    final counts = _calculateEmotionStats();
    final total = counts.values.fold(0, (sum, count) => sum + count);

    if (total == 0) return {};

    return counts.map(
      (emotion, count) => MapEntry(emotion, count / total * 100),
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

  @override
  Widget build(BuildContext context) {
    final emotionPercentages = _calculateEmotionPercentages();

    if (emotionPercentages.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.analytics_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No emotion data available',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                'Create notes to see your emotion analysis',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    // Sort emotions by percentage
    final sortedEmotions = emotionPercentages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Emotion Analysis',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedEmotions.map((entry) {
              final emotion = entry.key;
              final percentage = entry.value;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getEmotionIcon(emotion),
                          color: _getEmotionColor(emotion),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            emotion,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _getEmotionColor(emotion),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getEmotionColor(emotion),
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Based on ${notes.where((n) => n.emotionAnalysis != null).length} analyzed notes',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
