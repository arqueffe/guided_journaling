import 'smollm2_service.dart';

class QuestioningAgent {
  final SmolLM2Service _service;

  QuestioningAgent(this._service);

  bool get isInitialized => _service.isInitialized;

  /// Generate a thought-provoking question based on the note content
  Future<String> generateQuestion(String noteContent) async {
    print('[QuestioningAgent] Starting generateQuestion');
    print('[QuestioningAgent] Service initialized: $_service.isInitialized');

    if (!_service.isInitialized) {
      print('[QuestioningAgent] ERROR: Service not initialized');
      throw Exception('Questioning agent not initialized');
    }

    if (noteContent.trim().isEmpty) {
      print('[QuestioningAgent] ERROR: Note content is empty');
      throw Exception('Note content cannot be empty');
    }

    print('[QuestioningAgent] Note content length: ${noteContent.length}');

    // Create prompt for question generation
    final prompt =
        '<|im_start|>system\nYou are a thoughtful journaling coach that asks insightful questions to help deepen reflection. Generate ONE concise, open-ended question that encourages the writer to explore their thoughts more deeply, be more specific, or examine different perspectives. Keep the question under 20 words. Only output the question, nothing else.<|im_end|>\n<|im_start|>user\nBased on this journal entry, ask a question to deepen their reflection:\n\n${noteContent.substring(0, noteContent.length > 300 ? 300 : noteContent.length)}<|im_end|>\n<|im_start|>assistant\n';

    print('[QuestioningAgent] Prompt created, length: ${prompt.length}');
    print('[QuestioningAgent] Calling service.runInference...');

    // Run inference
    final result = await _service.runInference(prompt);

    print(
      '[QuestioningAgent] Inference completed, result length: ${result.length}',
    );

    return result;
  }
}
