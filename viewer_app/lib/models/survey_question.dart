enum QuestionType {
  singleChoice,
  multipleChoice,
  text,

  /// 3-point Муу / Дунд / Сайн mood slider; answered with one of its labels.
  rating;

  /// The backend's wire names (`SINGLE_CHOICE`, `MULTI_CHOICE`, ...); an
  /// unknown type falls back to single choice so the survey still opens.
  static QuestionType fromWire(String wire) => switch (wire.toUpperCase()) {
        'MULTI_CHOICE' || 'MULTIPLE_CHOICE' => multipleChoice,
        'TEXT' => text,
        'RATING' => rating,
        _ => singleChoice,
      };
}

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
      type: QuestionType.fromWire(json['type'] as String),
      options: (json['options'] as List?)?.cast<String>() ?? const [],
      required: json['required'] as bool? ?? true,
    );
  }
}
