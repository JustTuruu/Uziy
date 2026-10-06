import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/survey_question.dart';

void main() {
  test('parses the backend QuestionDto (no campaign id)', () {
    final q = SurveyQuestion.fromJson({
      'id': 5,
      'position': 1,
      'prompt': 'Сонирхолтой байсан уу?',
      'type': 'SINGLE_CHOICE',
      'options': ['Тийм', 'Үгүй'],
      'required': true,
    });
    expect(q.id, 5);
    expect(q.campaignId, 0);
    expect(q.options, ['Тийм', 'Үгүй']);
  });

  test('uses campaign_id when present', () {
    final q = SurveyQuestion.fromJson({
      'id': 1,
      'campaign_id': 9,
      'prompt': 'p',
      'type': 'TEXT',
      'options': <String>[],
    });
    expect(q.campaignId, 9);
    expect(q.type, QuestionType.text);
  });

  test('maps SNAKE_CASE backend types to the right QuestionType', () {
    QuestionType typeOf(String t) => SurveyQuestion.fromJson({
          'id': 1,
          'prompt': 'p',
          'type': t,
        }).type;
    expect(typeOf('SINGLE_CHOICE'), QuestionType.singleChoice);
    expect(typeOf('MULTIPLE_CHOICE'), QuestionType.multipleChoice);
    expect(typeOf('TEXT'), QuestionType.text);
  });
}
