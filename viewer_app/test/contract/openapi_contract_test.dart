import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The app's hand-written models checked against the backend's API description
// (docs/api/openapi.json, rewritten by `./gradlew updateOpenApi`). Every key a
// `fromJson` reads must be a field the backend sends, and a key it reads
// without a null check must be one the backend always sends. A renamed or
// dropped field then fails here instead of showing up as an empty screen.

const _specPath = '../docs/api/openapi.json';

/// One model: its file, class, the schema it parses, and keys it may read
/// although the backend never sends them (each with the reason).
class _Model {
  const _Model(this.file, this.className, this.schema,
      {this.tolerated = const {}});
  final String file;
  final String className;
  final String schema;
  final Set<String> tolerated;
}

const _models = [
  _Model('lib/models/campaign.dart', 'Campaign', 'FeedItemDto'),
  _Model('lib/models/payout_request.dart', 'PayoutRequest', 'PayoutDto'),
  _Model('lib/models/phone_verification.dart', 'PhoneVerification',
      'PhoneVerificationStartedRes'),
  _Model('lib/models/phone_verification.dart', 'PhoneVerificationState',
      'PhoneVerificationStateRes'),
  _Model('lib/models/statistics_consent.dart', 'StatisticsConsent',
      'StatisticsConsentDto'),
  // QuestionDto has no campaign id (the request is already scoped to one
  // campaign); the model only falls back to it.
  _Model('lib/models/survey_question.dart', 'SurveyQuestion', 'QuestionDto',
      tolerated: {'campaign_id', 'campaignId'}),
  _Model('lib/models/user.dart', 'AppUser', 'Me'),
  _Model('lib/models/view_history_item.dart', 'ViewHistoryItem',
      'ViewHistoryItemDto'),
];

final _key = RegExp(r"json\['(\w+)'\]");

/// `json['x'] as int` / `(json['x'] as num)` — read as if always present.
final _castWithoutNull =
    RegExp(r"json\['(\w+)'\]\s+as\s+(?:num|int|double|String|bool|List|Map)(?![?\w<])");

/// The source of [className] in [source]: from its declaration to the next
/// top-level class (or the end of the file).
String classBody(String source, String className) {
  final start = source.indexOf(RegExp('^class $className\\b', multiLine: true));
  if (start < 0) throw StateError('class $className not found');
  final next = source.indexOf(RegExp(r'^class ', multiLine: true), start + 1);
  return source.substring(start, next < 0 ? source.length : next);
}

/// Keys read from `json[...]`, and those read without allowing null.
({Set<String> all, Set<String> assumed}) keysRead(String body) {
  final all = _key.allMatches(body).map((m) => m[1]!).toSet();
  final assumed = _castWithoutNull
      .allMatches(body)
      .map((m) => m[1]!)
      // `json['x'] == null ? … : json['x'] as T` checks first.
      .where((k) => !body.contains("json['$k'] == null"))
      .toSet();
  return (all: all, assumed: assumed);
}

/// OpenAPI 3.1: `type: [string, null]`, or `oneOf` with a `{type: null}`.
bool mayBeNull(Map property) {
  final type = property['type'];
  if (type is List && type.contains('null')) return true;
  final oneOf = property['oneOf'];
  return oneOf is List && oneOf.any((s) => (s as Map)['type'] == 'null' ||
      (s['type'] is List && (s['type'] as List).contains('null')));
}

void main() {
  final spec = jsonDecode(File(_specPath).readAsStringSync())
      as Map<String, dynamic>;
  final schemas = (spec['components'] as Map)['schemas'] as Map;

  group('the helpers read what they should', () {
    test('null is read from a type list and from oneOf', () {
      expect(mayBeNull({'type': ['string', 'null']}), isTrue);
      expect(mayBeNull({'type': 'string'}), isFalse);
      expect(
          mayBeNull({
            'oneOf': [
              {r'$ref': '#/x'},
              {'type': ['null']},
            ]
          }),
          isTrue);
    });

    test('a key cast without a null check is assumed present', () {
      const body = "class X { f(json) => X(a: json['a'] as int, "
          "b: json['b'] as String?, c: (json['c'] as num?)?.toInt(), "
          "d: json['d'] == null ? null : json['d'] as String); }";
      final keys = keysRead(body);
      expect(keys.all, {'a', 'b', 'c', 'd'});
      expect(keys.assumed, {'a'});
    });

    test('a class body stops at the next class', () {
      const source = 'class A {\n a;\n}\nclass AB {\n b;\n}\n';
      expect(classBody(source, 'A'), contains(' a;'));
      expect(classBody(source, 'A'), isNot(contains(' b;')));
    });
  });

  for (final m in _models) {
    group('${m.className} ⇄ ${m.schema}', () {
      final schema = schemas[m.schema] as Map<String, dynamic>?;
      final body = classBody(File(m.file).readAsStringSync(), m.className);
      final keys = keysRead(body);

      test('the schema exists', () => expect(schema, isNotNull));

      test('every key it reads is a field the backend sends', () {
        final sent = (schema!['properties'] as Map).keys.toSet();
        expect(keys.all.difference(sent).difference(m.tolerated), isEmpty);
      });

      test('a key read without a null check is always sent, never null', () {
        final required = ((schema!['required'] as List?) ?? const [])
            .cast<String>()
            .toSet();
        final properties = schema['properties'] as Map;
        final nullable = {
          for (final MapEntry(:key, :value) in properties.entries)
            if (mayBeNull(value as Map)) key as String,
        };
        expect(keys.assumed.difference(required), isEmpty);
        expect(keys.assumed.intersection(nullable), isEmpty);
      });
    });
  }
}
