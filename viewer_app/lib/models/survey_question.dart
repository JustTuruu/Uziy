enum QuestionType { singleChoice, multipleChoice, text }

class SurveyQuestion {
  final int id;
  final int campaignId;
  final String prompt;
  final QuestionType type;
  final List<String> options; // empty for text
  final bool required;

  const SurveyQuestion({
    required this.id,
    required this.campaignId,
    required this.prompt,
    required this.type,
    this.options = const [],
    this.required = true,
  });

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) {
    return SurveyQuestion(
      id: json['id'] as int,
      // The backend's QuestionDto has no campaign id (the request is already
      // scoped to one campaign), so tolerate its absence.
      campaignId: (json['campaign_id'] ?? json['campaignId']) as int? ?? 0,
      prompt: json['prompt'] as String,
      type: QuestionType.values.firstWhere(
        // Backend sends SINGLE_CHOICE / MULTIPLE_CHOICE / TEXT.
        (t) =>
            t.name.toUpperCase() ==
            (json['type'] as String).replaceAll('_', '').toUpperCase(),
        orElse: () => QuestionType.singleChoice,
      ),
      options: (json['options'] as List?)?.cast<String>() ?? const [],
      required: json['required'] as bool? ?? true,
    );
  }
}
