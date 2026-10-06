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

  static List<SurveyQuestion> mockFor(int campaignId) => [
        SurveyQuestion(
          id: 1,
          campaignId: campaignId,
          prompt: 'Энэ реклам танд сонирхолтой санагдсан уу?',
          type: QuestionType.singleChoice,
          options: const ['Тийм', 'Дунд зэрэг', 'Үгүй'],
        ),
        SurveyQuestion(
          id: 2,
          campaignId: campaignId,
          prompt: 'Та энэ бүтээгдэхүүнийг өмнө нь ашиглаж байсан уу?',
          type: QuestionType.singleChoice,
          options: const ['Тогтмол ашигладаг', 'Хааяа', 'Үгүй'],
        ),
        SurveyQuestion(
          id: 3,
          campaignId: campaignId,
          prompt: 'Ямар шинэ санал болмоор байна вэ?',
          type: QuestionType.text,
          required: false,
        ),
      ];
}
