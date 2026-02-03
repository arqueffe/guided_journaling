import 'smollm2_service.dart';

class TitleGenerator {
  final SmolLM2Service _service;

  TitleGenerator(this._service);

  bool get isInitialized => _service.isInitialized;

  Future<String> generateTitle(String noteContent) async {
    if (!_service.isInitialized) {
      throw Exception('Title generator not initialized');
    }

    if (noteContent.trim().isEmpty) {
      throw Exception('Note content cannot be empty');
    }

    // Create prompt for title generation
    final prompt =
        '<|im_start|>system\nYou are a helpful assistant that generates short, concise titles (5 words or less) for journal entries. Only output the title, nothing else.<|im_end|>\n<|im_start|>user\nGenerate a short title for this note:\n\n${noteContent.substring(0, noteContent.length > 200 ? 200 : noteContent.length)}<|im_end|>\n<|im_start|>assistant\n';

    // Run inference
    final result = await _service.runInference(prompt);

    return result;
  }
}
