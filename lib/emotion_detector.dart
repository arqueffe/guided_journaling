import 'dart:math';
import 'dart:typed_data';
import 'package:onnxruntime/onnxruntime.dart';
import 'tokenizer.dart';

class EmotionDetector {
  static const List<String> emotionLabels = [
    'Sadness',
    'Anger',
    'Love',
    'Surprise',
    'Fear',
    'Happiness',
    'Neutral',
    'Disgust',
    'Shame',
    'Guilt',
    'Confusion',
    'Desire',
    'Sarcasm',
  ];

  late OrtSession _session;
  late BertTokenizer _tokenizer;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize(Uint8List modelBytes, String vocabPath) async {
    try {
      // Initialize ONNX Runtime
      OrtEnv.instance.init();

      // Create session options
      final sessionOptions = OrtSessionOptions();

      // Load the model from bytes
      _session = OrtSession.fromBuffer(modelBytes, sessionOptions);

      // Initialize tokenizer
      _tokenizer = BertTokenizer(maxLength: 512);
      await _tokenizer.loadVocab(vocabPath);

      _initialized = true;
      print('Emotion detector initialized successfully');
    } catch (e) {
      print('Error initializing emotion detector: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> detectEmotion(String text) async {
    if (!_initialized) {
      throw StateError(
        'Emotion detector not initialized. Call initialize() first.',
      );
    }

    try {
      // Tokenize the text
      final encoded = _tokenizer.encode(text);
      final inputIds = encoded['input_ids']!;
      final attentionMask = encoded['attention_mask']!;
      final tokenTypeIds = encoded['token_type_ids']!;

      // Prepare input tensors
      final inputIdsData = OrtValueTensor.createTensorWithDataList(
        Int64List.fromList(inputIds.map((e) => e).toList()),
        [1, inputIds.length],
      );

      final attentionMaskData = OrtValueTensor.createTensorWithDataList(
        Int64List.fromList(attentionMask.map((e) => e).toList()),
        [1, attentionMask.length],
      );

      final tokenTypeIdsData = OrtValueTensor.createTensorWithDataList(
        Int64List.fromList(tokenTypeIds.map((e) => e).toList()),
        [1, tokenTypeIds.length],
      );

      // Run inference
      final inputs = {
        'input_ids': inputIdsData,
        'attention_mask': attentionMaskData,
        'token_type_ids': tokenTypeIdsData,
      };

      final runOptions = OrtRunOptions();
      final outputs = await _session.runAsync(runOptions, inputs);

      // Get the logits from output
      final output = outputs?[0];
      final logits = output?.value as List<List<double>>;

      // Apply softmax to get probabilities
      final scores = _softmax(logits[0]);

      print(
        'Model output classes: ${scores.length}, Expected: ${emotionLabels.length}',
      );

      // Find the emotion with highest score
      int maxIndex = 0;
      double maxScore = scores[0];
      for (int i = 1; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i];
          maxIndex = i;
        }
      }

      // Release tensors
      inputIdsData.release();
      attentionMaskData.release();
      tokenTypeIdsData.release();
      runOptions.release();
      output?.release();

      // Create all_scores map only if lengths match
      Map<String, double> allScores = {};
      if (scores.length == emotionLabels.length) {
        allScores = Map.fromIterables(emotionLabels, scores);
      } else {
        print(
          'WARNING: Score length mismatch. Using first ${emotionLabels.length} labels.',
        );
        // Use as many as we can
        final minLength = scores.length < emotionLabels.length
            ? scores.length
            : emotionLabels.length;
        allScores = Map.fromIterables(
          emotionLabels.sublist(0, minLength),
          scores.sublist(0, minLength),
        );
      }

      return {
        'label': maxIndex < emotionLabels.length
            ? emotionLabels[maxIndex]
            : 'Unknown',
        'score': maxScore,
        'all_scores': allScores,
      };
    } catch (e) {
      print('Error during emotion detection: $e');
      rethrow;
    }
  }

  List<double> _softmax(List<double> logits) {
    // Find max for numerical stability
    double maxLogit = logits.reduce((a, b) => a > b ? a : b);

    // Calculate exp and sum
    List<double> expValues = logits.map((x) => exp(x - maxLogit)).toList();
    double sumExp = expValues.reduce((a, b) => a + b);

    // Normalize
    return expValues.map((x) => x / sumExp).toList();
  }

  Future<List<Map<String, dynamic>>> analyzeSentences(String text) async {
    // Split text into sentences
    final sentences = _splitIntoSentences(text);

    List<Map<String, dynamic>> results = [];

    for (String sentence in sentences) {
      if (sentence.trim().isNotEmpty) {
        final emotion = await detectEmotion(sentence);
        results.add({'sentence': sentence, 'emotion': emotion});
      }
    }

    return results;
  }

  List<String> _splitIntoSentences(String text) {
    // Simple sentence splitter - can be improved
    text = text.trim();

    // Split by common sentence endings
    List<String> sentences = [];
    RegExp sentencePattern = RegExp(r'[.!?]+[\s\n]+|[\n]{2,}');

    int lastEnd = 0;
    for (Match match in sentencePattern.allMatches(text)) {
      sentences.add(text.substring(lastEnd, match.end).trim());
      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      sentences.add(text.substring(lastEnd).trim());
    }

    return sentences.where((s) => s.isNotEmpty).toList();
  }

  void dispose() {
    if (_initialized) {
      _session.release();
      OrtEnv.instance.release();
      _initialized = false;
    }
  }
}
