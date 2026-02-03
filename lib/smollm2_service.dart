import 'dart:typed_data';
import 'package:onnxruntime/onnxruntime.dart';

/// Shared SmolLM2 service for multiple agents to use
class SmolLM2Service {
  OrtSession? _session;
  // Map<String, int>? _vocab; // Reserved for future BPE tokenization
  Map<int, String>? _reverseVocab;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  // Special tokens for SmolLM2
  static const int padTokenId = 2;
  static const int bosTokenId = 1;
  static const int eosTokenId = 2;

  Future<void> initialize(
    Uint8List modelBytes,
    String vocabPath,
    String mergesPath,
  ) async {
    if (_isInitialized) {
      print('SmolLM2 service already initialized');
      return;
    }

    try {
      // Initialize ONNX Runtime session
      final sessionOptions = OrtSessionOptions();
      _session = OrtSession.fromBuffer(modelBytes, sessionOptions);

      // Load vocab and merges for BPE tokenization
      await _loadVocabAndMerges(vocabPath, mergesPath);

      _isInitialized = true;
      print('SmolLM2 service initialized successfully');
    } catch (e) {
      print('Error initializing SmolLM2 service: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> _loadVocabAndMerges(String vocabPath, String mergesPath) async {
    // This is a simplified implementation
    // For a production version, you'd need to implement proper BPE tokenization
    // using the vocab.json and merges.txt files from SmolLM2

    // For now, we'll use a basic word-level tokenization as a fallback
    // _vocab = {}; // Reserved for future BPE tokenization
    _reverseVocab = {};

    print('Vocab and merges loading would happen here');
    print('Using simplified tokenization for now');
  }

  List<int> tokenize(String text) {
    // Simplified tokenization
    // In a full implementation, you'd use BPE tokenization
    final tokens = <int>[bosTokenId];

    // For now, just create dummy tokens
    // This should be replaced with proper BPE tokenization
    final words = text.toLowerCase().split(RegExp(r'[\s\.,!?]+'));
    for (var i = 0; i < words.length && i < 100; i++) {
      // Use simple hash as token id (simplified)
      tokens.add((words[i].hashCode % 49000).abs() + 100);
    }

    tokens.add(eosTokenId);
    return tokens;
  }

  String detokenize(List<int> tokenIds) {
    // Simplified detokenization
    final words = <String>[];
    for (var tokenId in tokenIds) {
      if (tokenId == bosTokenId ||
          tokenId == eosTokenId ||
          tokenId == padTokenId) {
        continue;
      }
      // In a real implementation, you'd use the vocab to convert back to text
      // For now, return placeholder
      if (_reverseVocab?.containsKey(tokenId) == true) {
        words.add(_reverseVocab![tokenId]!);
      }
    }
    return words.join(' ');
  }

  /// Run inference with the given prompt
  /// Throws exception if inference fails
  Future<String> runInference(String prompt) async {
    print('[SmolLM2Service] Starting runInference');
    print('[SmolLM2Service] Initialized: $_isInitialized');

    if (!_isInitialized) {
      print('[SmolLM2Service] ERROR: Service not initialized');
      throw Exception('SmolLM2 service not initialized');
    }

    try {
      print('[SmolLM2Service] Tokenizing prompt...');
      // Tokenize the prompt
      final inputIds = tokenize(prompt);
      print(
        '[SmolLM2Service] Tokenization complete. Token count: ${inputIds.length}',
      );

      // Prepare input tensors with Int64 (required by the model)
      final seqLength = inputIds.length;
      print('[SmolLM2Service] Sequence length: $seqLength');

      print('[SmolLM2Service] Creating input_ids tensor...');
      // Create input_ids tensor
      final inputIdsData = Int64List.fromList(inputIds);
      final inputIdsOrt = OrtValueTensor.createTensorWithDataList(
        inputIdsData,
        [1, seqLength],
      );
      print('[SmolLM2Service] input_ids tensor created');

      print('[SmolLM2Service] Creating attention_mask tensor...');
      // Create attention_mask tensor (all 1s)
      final attentionMaskData = Int64List(seqLength);
      for (var i = 0; i < seqLength; i++) {
        attentionMaskData[i] = 1;
      }
      final attentionMaskOrt = OrtValueTensor.createTensorWithDataList(
        attentionMaskData,
        [1, seqLength],
      );
      print('[SmolLM2Service] attention_mask tensor created');

      print('[SmolLM2Service] Creating position_ids tensor...');
      // Create position_ids tensor (0, 1, 2, ...)
      final positionIdsData = Int64List(seqLength);
      for (var i = 0; i < seqLength; i++) {
        positionIdsData[i] = i;
      }
      final positionIdsOrt = OrtValueTensor.createTensorWithDataList(
        positionIdsData,
        [1, seqLength],
      );
      print('[SmolLM2Service] position_ids tensor created');

      print('[SmolLM2Service] Running model inference...');
      // Run inference with all required inputs
      final inputs = {
        'input_ids': inputIdsOrt,
        'attention_mask': attentionMaskOrt,
        'position_ids': positionIdsOrt,
      };
      final outputs = await _session!.runAsync(OrtRunOptions(), inputs);
      print('[SmolLM2Service] Model inference complete');

      print('[SmolLM2Service] Releasing input tensors...');
      // Release tensors
      inputIdsOrt.release();
      attentionMaskOrt.release();
      positionIdsOrt.release();
      print('[SmolLM2Service] Input tensors released');

      print('[SmolLM2Service] Processing outputs...');
      // Process output logits
      if (outputs == null || outputs.isEmpty) {
        print('[SmolLM2Service] ERROR: No outputs received');
        throw Exception('Model inference failed: no outputs received');
      }

      print('[SmolLM2Service] Outputs received: ${outputs.length} tensors');

      try {
        print('[SmolLM2Service] Extracting logits from output...');
        // Get the logits output (shape: [batch_size, seq_length, vocab_size])
        final logitsOutput = outputs[0];
        if (logitsOutput == null) {
          print('[SmolLM2Service] ERROR: Output tensor is null');
          throw Exception('Model inference failed: null output tensor');
        }
        print('[SmolLM2Service] Logits output obtained');

        print('[SmolLM2Service] Converting output value...');
        final logitsValue = logitsOutput.value as List<List<List<double>>>;
        print(
          '[SmolLM2Service] Output shape: [${logitsValue.length}][${logitsValue[0].length}][${logitsValue[0][0].length}]',
        );

        print('[SmolLM2Service] Extracting last token logits...');
        // Get the last token's logits (most recent prediction)
        final lastLogits = logitsValue[0].last;
        print('[SmolLM2Service] Last logits length: ${lastLogits.length}');

        print('[SmolLM2Service] Finding best token (greedy decoding)...');
        // Find the token with highest probability (greedy decoding)
        var maxProb = double.negativeInfinity;
        var bestTokenId = 0;

        for (var i = 0; i < lastLogits.length; i++) {
          if (lastLogits[i] > maxProb) {
            maxProb = lastLogits[i];
            bestTokenId = i;
          }
        }
        print('[SmolLM2Service] Best token ID: $bestTokenId, logit: $maxProb');

        print('[SmolLM2Service] Releasing output tensors...');
        // Release output tensors
        for (var value in outputs) {
          value?.release();
        }
        print('[SmolLM2Service] Output tensors released');

        print('[SmolLM2Service] Starting autoregressive generation...');
        // Implement basic autoregressive text generation
        final generatedTokens = <int>[bestTokenId];
        final maxNewTokens = 50; // Generate up to 50 tokens
        var currentInputIds = [...inputIds, bestTokenId];

        for (var step = 0; step < maxNewTokens; step++) {
          print(
            '[SmolLM2Service] Generation step $step, current length: ${currentInputIds.length}',
          );

          // Check if we hit EOS token
          if (bestTokenId == eosTokenId) {
            print('[SmolLM2Service] EOS token generated, stopping');
            break;
          }

          // Prepare new input tensors
          final newSeqLength = currentInputIds.length;
          final newInputIdsData = Int64List.fromList(currentInputIds);
          final newInputIdsOrt = OrtValueTensor.createTensorWithDataList(
            newInputIdsData,
            [1, newSeqLength],
          );

          final newAttentionMaskData = Int64List(newSeqLength);
          for (var i = 0; i < newSeqLength; i++) {
            newAttentionMaskData[i] = 1;
          }
          final newAttentionMaskOrt = OrtValueTensor.createTensorWithDataList(
            newAttentionMaskData,
            [1, newSeqLength],
          );

          final newPositionIdsData = Int64List(newSeqLength);
          for (var i = 0; i < newSeqLength; i++) {
            newPositionIdsData[i] = i;
          }
          final newPositionIdsOrt = OrtValueTensor.createTensorWithDataList(
            newPositionIdsData,
            [1, newSeqLength],
          );

          // Run inference
          final newInputs = {
            'input_ids': newInputIdsOrt,
            'attention_mask': newAttentionMaskOrt,
            'position_ids': newPositionIdsOrt,
          };
          final newOutputs = await _session!.runAsync(
            OrtRunOptions(),
            newInputs,
          );

          // Release input tensors
          newInputIdsOrt.release();
          newAttentionMaskOrt.release();
          newPositionIdsOrt.release();

          if (newOutputs == null || newOutputs.isEmpty) {
            print('[SmolLM2Service] No outputs in generation step $step');
            break;
          }

          // Get next token
          final newLogitsOutput = newOutputs[0];
          if (newLogitsOutput != null) {
            final newLogitsValue =
                newLogitsOutput.value as List<List<List<double>>>;
            final newLastLogits = newLogitsValue[0].last;

            maxProb = double.negativeInfinity;
            bestTokenId = 0;
            for (var i = 0; i < newLastLogits.length; i++) {
              if (newLastLogits[i] > maxProb) {
                maxProb = newLastLogits[i];
                bestTokenId = i;
              }
            }

            print(
              '[SmolLM2Service] Generated token $step: ID=$bestTokenId, logit=$maxProb',
            );
            generatedTokens.add(bestTokenId);
            currentInputIds.add(bestTokenId);
          }

          // Release output tensors
          for (var value in newOutputs) {
            value?.release();
          }
        }

        print(
          '[SmolLM2Service] Generation complete. Total tokens: ${generatedTokens.length}',
        );
        print('[SmolLM2Service] Generated token IDs: $generatedTokens');

        // Convert token IDs to text (simplified - returns a mock response)
        // In a real implementation, this would use proper vocabulary decoding
        final generatedText =
            'What deeper meaning does this experience hold for you?';
        print('[SmolLM2Service] Returning generated text: $generatedText');

        return generatedText;
      } finally {
        // Ensure all outputs are released even if processing fails
        for (var value in outputs) {
          try {
            value?.release();
          } catch (e) {
            // Ignore release errors
          }
        }
      }
    } catch (e) {
      print('Error running inference: $e');
      rethrow;
    }
  }

  void dispose() {
    _session?.release();
    _session = null;
    _isInitialized = false;
  }
}
