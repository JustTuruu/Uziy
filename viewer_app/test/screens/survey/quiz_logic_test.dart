import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/survey_question.dart';
import 'package:viewer_app/screens/survey/quiz_logic.dart';

void main() {
  const quiz = SurveyQuestion(
    id: 1,
    campaignId: 5,
    prompt: 'Ямар өнгө?',
    type: QuestionType.quiz,
    options: ['Улаан', 'Цэнхэр'],
  );
  const single = SurveyQuestion(
    id: 2,
    campaignId: 5,
    prompt: 'Тийм үү?',
    type: QuestionType.singleChoice,
    options: ['Тийм', 'Үгүй'],
  );

  test('a quiz pick is checked before moving on, other questions never are',
      () {
    final checks = QuizChecks();
    expect(checks.needsCheck(quiz, 'Цэнхэр'), isTrue);
    expect(checks.needsCheck(quiz, null), isFalse);
    expect(checks.needsCheck(single, 'Тийм'), isFalse);
  });

  test('a confirmed pick is not checked again, a changed one is', () {
    final checks = QuizChecks()..markCorrect(1, 'Цэнхэр');
    expect(checks.needsCheck(quiz, 'Цэнхэр'), isFalse);
    expect(checks.needsCheck(quiz, 'Улаан'), isTrue);
  });

  test('wrong picks are remembered per question', () {
    final checks = QuizChecks()..markWrong(1, 'Улаан');
    expect(checks.isWrong(1, 'Улаан'), isTrue);
    expect(checks.isWrong(1, 'Цэнхэр'), isFalse);
    expect(checks.isWrong(2, 'Улаан'), isFalse);
    expect(checks.isWrongPick(quiz, 'Улаан'), isTrue);
    expect(checks.isWrongPick(quiz, 'Цэнхэр'), isFalse);
  });
}
