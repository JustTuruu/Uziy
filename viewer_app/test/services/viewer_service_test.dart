import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/services/api_service.dart';
import 'package:viewer_app/services/campaign_events.dart';
import 'package:viewer_app/services/viewer_service.dart';

import '../support/fake_api.dart';

/// Replies to every request with a fixed status + JSON body.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body);
  final int status;
  final Object body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  @override
  void close({bool force = false}) {}
}

void _reply(int status, Object body) {
  ApiService.instance.dio.httpClientAdapter = _FakeAdapter(status, body);
}

Future<ApiException> _catch(Future<Object?> Function() call) async {
  try {
    await call();
  } on ApiException catch (e) {
    return e;
  }
  fail('expected ApiException');
}

void main() {
  final svc = ViewerService.instance;
  const forbidden = {'status': 403, 'error': 'Forbidden', 'path': '/viewer/x'};

  group('4xx responses become ApiException with the status', () {
    test('feed 403 (the "Сервертэй холбогдож чадсангүй" bug)', () async {
      _reply(403, forbidden);
      final e = await _catch(svc.feed);
      expect(e.statusCode, 403);
      expect(e.message, 'Дахин нэвтэрнэ үү');
    });

    test('myPayouts 403', () async {
      _reply(403, forbidden);
      expect((await _catch(svc.myPayouts)).statusCode, 403);
    });

    test('me 403', () async {
      _reply(403, forbidden);
      expect((await _catch(svc.me)).statusCode, 403);
    });

    test('history 403', () async {
      _reply(403, forbidden);
      final e = await _catch(svc.history);
      expect(e.statusCode, 403);
      expect(e.message, 'Дахин нэвтэрнэ үү');
    });

    test('questions 403', () async {
      _reply(403, forbidden);
      expect((await _catch(() => svc.questions(1))).statusCode, 403);
    });

    test('submit 409 carries the backend message', () async {
      _reply(409, const {
        'status': 409,
        'message': 'Та энэ урамшууллыг аль хэдийн авсан байна',
      });
      final e = await _catch(
        () => svc.submitSurvey(campaignId: 1, answers: const {}),
      );
      expect(e.statusCode, 409);
      expect(e.message, 'Та энэ урамшууллыг аль хэдийн авсан байна');
    });

    test('payout 400 surfaces the backend message', () async {
      _reply(400, const {'message': 'Үлдэгдэл хүрэлцэхгүй'});
      final e = await _catch(
        () => svc.requestPayout(
          amount: 500,
          bank: 'Khan',
          accountNumber: '1',
          accountName: 'A',
        ),
      );
      expect(e.statusCode, 400);
      expect(e.message, 'Үлдэгдэл хүрэлцэхгүй');
    });
  });

  /// The national ID is no longer collected (owner, 2026-10-14).
  test('a payout request sends the account, never a national ID', () async {
    final api = FakeApi.install((_) => const FakeReply(200, {'id': 1}));

    await svc.requestPayout(
      amount: 2000,
      bank: 'Khan Bank',
      accountNumber: '5001234567',
      accountName: 'БОЛД',
    );

    expect(api.callsTo('/viewer/payouts').single.body, {
      'amount': 2000.0,
      'bank': 'Khan Bank',
      'accountNumber': '5001234567',
      'accountName': 'БОЛД',
    });
  });

  group('2xx still parses', () {
    test('feed', () async {
      _reply(200, [
        {
          'id': 1,
          'title': 'T',
          'companyName': 'C',
          'durationSeconds': 45,
          'rewardPerUser': 700.0,
        }
      ]);
      final feed = await svc.feed();
      expect(feed.single.id, 1);
      expect(feed.single.rewardPerUser, 700);
    });

    test('submit', () async {
      _reply(200, const {'rewardPaid': 700.0, 'newBalance': 1200.0});
      final r = await svc.submitSurvey(campaignId: 1, answers: const {});
      expect(r.newBalance, 1200);
    });
  });

  group('history', () {
    test('parses the list the backend sends', () async {
      _reply(200, [
        {
          'campaignId': 3,
          'title': 'Шинэ 5G багц',
          'companyName': 'MobiCom',
          'rewardPaid': 700.0,
          'watchedAt': '2026-10-06T10:00:00+08:00',
        },
      ]);

      final items = await svc.history();

      expect(items, hasLength(1));
      expect(items.single.campaignId, 3);
      expect(items.single.rewardPaid, 700);
    });
  });

  group('guestFeed', () {
    test('parses the public sample cards', () async {
      _reply(200, [
        {
          'id': 4,
          'title': 'Шинэ 5G багц',
          'videoUrl': '',
          'durationSeconds': 45,
          'hasVideo': true,
          'rewardPerUser': 700,
          'companyName': 'MobiCom',
        },
      ]);

      final feed = await svc.guestFeed();

      expect(feed.single.id, 4);
      expect(feed.single.videoUrl, '');
    });

    test('a server error becomes an ApiException', () async {
      _reply(500, const {'message': 'boom'});
      final e = await _catch(svc.guestFeed);
      expect(e.statusCode, 500);
    });
  });

  group('encodeAnswer', () {
    // The backend parses every answer as JSON; each result must round-trip.
    dynamic roundTrip(dynamic answer) =>
        jsonDecode(ViewerService.encodeAnswer(answer));

    test('a plain answer is a JSON string', () {
      expect(ViewerService.encodeAnswer('Тийм'), '"Тийм"');
    });

    test('a choice list is a JSON array of strings', () {
      expect(roundTrip(['Дуудлага', 'Мессеж']), ['Дуудлага', 'Мессеж']);
      expect(ViewerService.encodeAnswer(<String>[]), '[]');
    });

    test('options with commas survive', () {
      expect(roundTrip('10,000₮-аас бага'), '10,000₮-аас бага');
      expect(roundTrip(['Видео, хөгжим үзэх, сонсох']),
          ['Видео, хөгжим үзэх, сонсох']);
    });

    test('free text with new lines, tabs, quotes and backslashes stays valid',
        () {
      // Regression: a new line used to produce invalid JSON, so the backend
      // answered "Хариулт буруу байна".
      const text = 'нэг\nхоёр\tгурав "ишлэл" a\\b';
      expect(roundTrip(text), text);
    });
  });

  group('submitSurvey tells the app the campaign is finished', () {
    Future<List<int>> completionsDuring(Future<void> Function() call) async {
      final ids = <int>[];
      final sub = CampaignEvents.instance.completed
          .listen((e) => ids.add(e.campaignId));
      await call();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      return ids;
    }

    test('after a paid reward', () async {
      _reply(200, const {'rewardPaid': 700, 'newBalance': 1700});
      final ids = await completionsDuring(
          () => svc.submitSurvey(campaignId: 5, answers: const {1: 'Тийм'}));
      expect(ids, [5]);
    });

    test('when the server says it was already rewarded (409)', () async {
      _reply(409, const {'status': 409, 'message': 'Аль хэдийн авсан'});
      final ids = await completionsDuring(() async {
        final e = await _catch(
            () => svc.submitSurvey(campaignId: 5, answers: const {1: 'Тийм'}));
        expect(e.statusCode, 409);
      });
      expect(ids, [5]);
    });

    test('not when the answers are rejected (400)', () async {
      _reply(400, const {'status': 400, 'message': 'Хариулт буруу байна'});
      final ids = await completionsDuring(() async {
        await _catch(
            () => svc.submitSurvey(campaignId: 5, answers: const {1: 'x'}));
      });
      expect(ids, isEmpty);
    });
  });

  group('statistics consent', () {
    test('a 403 carries the status', () async {
      _reply(403, forbidden);
      expect((await _catch(svc.statisticsConsent)).statusCode, 403);
    });

    test('a decision is read back', () async {
      _reply(200,
          const {'status': 'DECLINED', 'decidedAt': '2026-10-14T04:00:00Z'});
      final c = await svc.decideStatisticsConsent(granted: false);
      expect(c.granted, isFalse);
    });
  });

  group('setName', () {
    test('PUTs the trimmed name and reads the profile back', () async {
      final api = FakeApi.install((_) => const FakeReply(200, {
            'id': 1,
            'phoneNumber': '88112233',
            'role': 'VIEWER',
            'balance': 0,
            'isVerified': false,
            'lastName': 'Бат',
            'firstName': 'Сараа',
          }));
      final me = await svc.setName(lastName: ' Бат ', firstName: 'Сараа ');

      final call = api.callsTo('/viewer/me/name').single;
      expect(call.method, 'PUT');
      expect(call.body, {'lastName': 'Бат', 'firstName': 'Сараа'});
      expect(me.lastName, 'Бат');
      expect(me.firstName, 'Сараа');
    });

    test('a name already set comes back as the backend message', () async {
      FakeApi.install((_) => const FakeReply(
          409, {'message': 'Овог, нэр аль хэдийн бүртгэгдсэн байна'}));
      final e =
          await _catch(() => svc.setName(lastName: 'Өөр', firstName: 'Хүн'));
      expect(e.statusCode, 409);
      expect(e.message, 'Овог, нэр аль хэдийн бүртгэгдсэн байна');
    });
  });
}
