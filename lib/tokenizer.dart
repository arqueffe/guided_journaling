import 'dart:io';

class BertTokenizer {
  final Map<String, int> _vocab = {};
  final int maxLength;
  static const String clsToken = '[CLS]';
  static const String sepToken = '[SEP]';
  static const String padToken = '[PAD]';
  static const String unkToken = '[UNK]';

  BertTokenizer({this.maxLength = 512});

  Future<void> loadVocab(String vocabPath) async {
    final file = File(vocabPath);
    final lines = await file.readAsLines();

    for (int i = 0; i < lines.length; i++) {
      _vocab[lines[i].trim()] = i;
    }
  }

  int _getTokenId(String token) {
    return _vocab[token] ?? _vocab[unkToken] ?? 100;
  }

  List<String> _basicTokenize(String text) {
    // Simple whitespace tokenization
    text = text.toLowerCase().trim();

    // Add spaces around punctuation
    text = text.replaceAllMapped(
      RegExp(r'([.,!?;:\-"()\[\]{}])'),
      (match) => ' ${match.group(0)} ',
    );

    return text
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
  }

  List<String> _wordpieceTokenize(String word) {
    if (_vocab.containsKey(word)) {
      return [word];
    }

    List<String> tokens = [];
    int start = 0;

    while (start < word.length) {
      int end = word.length;
      String? subToken;

      while (start < end) {
        String substr = word.substring(start, end);
        if (start > 0) {
          substr = '##$substr';
        }

        if (_vocab.containsKey(substr)) {
          subToken = substr;
          break;
        }
        end--;
      }

      if (subToken == null) {
        tokens.add(unkToken);
        start++;
      } else {
        tokens.add(subToken);
        start = end;
      }
    }

    return tokens;
  }

  Map<String, List<int>> encode(String text) {
    // Basic tokenization
    List<String> tokens = _basicTokenize(text);

    // WordPiece tokenization
    List<String> subTokens = [clsToken];
    for (String token in tokens) {
      subTokens.addAll(_wordpieceTokenize(token));
    }
    subTokens.add(sepToken);

    // Truncate to max length
    if (subTokens.length > maxLength) {
      subTokens = subTokens.sublist(0, maxLength - 1);
      subTokens.add(sepToken);
    }

    // Convert to IDs
    List<int> inputIds = subTokens.map((token) => _getTokenId(token)).toList();

    // Create attention mask (1 for real tokens, 0 for padding)
    List<int> attentionMask = List.filled(inputIds.length, 1, growable: true);

    // Create token type ids (all 0s for single sentence)
    List<int> tokenTypeIds = List.filled(inputIds.length, 0, growable: true);

    // Pad to max length
    while (inputIds.length < maxLength) {
      inputIds.add(_getTokenId(padToken));
      attentionMask.add(0);
      tokenTypeIds.add(0);
    }

    return {
      'input_ids': inputIds,
      'attention_mask': attentionMask,
      'token_type_ids': tokenTypeIds,
    };
  }
}
