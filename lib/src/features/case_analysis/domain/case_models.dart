import 'package:flutter/foundation.dart';

enum CaseChoice { left, right }

@immutable
class CaseScenario {
  const CaseScenario({
    required this.id,
    required this.prompt,
    required this.leftText,
    required this.rightText,
  });

  final String id;
  final String prompt;
  final String leftText;
  final String rightText;

  factory CaseScenario.fromMap(Map<String, dynamic> map) {
    return CaseScenario(
      id: (map['id'] ?? '').toString(),
      prompt: (map['prompt'] ?? '').toString(),
      leftText: (map['left_text'] ?? '').toString(),
      rightText: (map['right_text'] ?? '').toString(),
    );
  }
}
