import '../../models/survey_question.dart';

/// Copy shown under a quiz question after a wrong pick.
const String kQuizWrongMessage =
    'Буруу хариулт байна. Өөр хариулт сонгоод дахин оролдоно уу';

/// What the survey knows about its quiz questions: which pick the server
/// confirmed as correct, and which picks it already said are wrong.
///
/// A quiz pick is checked when the viewer moves on (`Дараах` / `Илгээх`); a
/// wrong one keeps them on the question, marked, until they find the right
/// one (owner, 2026-10-30: retry until correct). Changing a confirmed pick
/// needs a new check.
class QuizChecks {
  final Map<int, String> _confirmed = {};
  final Map<int, Set<String>> _wrong = {};

  /// Whether moving past [question] with [answer] must ask the server first.
  bool needsCheck(SurveyQuestion question, Object? answer) =>
      question.type == QuestionType.quiz &&
      answer is String &&
      _confirmed[question.id] != answer;

  void markCorrect(int questionId, String answer) =>
      _confirmed[questionId] = answer;

  void markWrong(int questionId, String answer) =>
      (_wrong[questionId] ??= <String>{}).add(answer);

  /// Whether [option] was already tried on [questionId] and is wrong.
  bool isWrong(int questionId, String option) =>
      _wrong[questionId]?.contains(option) ?? false;

  /// Whether the viewer's current [answer] is a known wrong pick: the survey
  /// then shows [kQuizWrongMessage] and does not let them move on with it.
  bool isWrongPick(SurveyQuestion question, Object? answer) =>
      answer is String && isWrong(question.id, answer);
}
