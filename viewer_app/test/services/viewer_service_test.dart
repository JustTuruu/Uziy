import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/services/api_service.dart';
import 'package:viewer_app/services/viewer_service.dart';

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

    test('me 403', () async {
      _reply(403, forbidden);
      expect((await _catch(svc.me)).statusCode, 403);
    });

    test('questions 403', () async {
      _reply(403, forbidden);
      expect((await _catch(() => svc.questions(1))).statusCode, 403);
    });

    test('submit 409 -> already watched', () async {
      _reply(409, const {'status': 409});
      final e = await _catch(
        () => svc.submitSurvey(campaignId: 1, answers: const {}),
      );
      expect(e.statusCode, 409);
      expect(e.message, 'Аль хэдийн үзсэн байна');
    });

    test('payout 400 surfaces the backend message', () async {
      _reply(400, const {'message': 'Үлдэгдэл хүрэлцэхгүй'});
      final e = await _catch(
        () => svc.requestPayout(
          amount: 500,
          bank: 'Khan',
          accountNumber: '1',
          accountName: 'A',
          nationalId: 'АА99999999',
        ),
      );
      expect(e.statusCode, 400);
      expect(e.message, 'Үлдэгдэл хүрэлцэхгүй');
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
}
