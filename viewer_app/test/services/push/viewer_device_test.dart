import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/services/api_service.dart';
import 'package:viewer_app/services/push/device_registry.dart';
import 'package:viewer_app/services/push/push_message.dart';
import 'package:viewer_app/services/viewer_service.dart';

class _Capture implements HttpClientAdapter {
  _Capture(this.status);
  final int status;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString('', status);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final svc = ViewerService.instance;

  test('registerDevice POSTs token + platform', () async {
    final a = _Capture(204);
    ApiService.instance.dio.httpClientAdapter = a;
    await svc.registerDevice(token: 'abc', platform: 'ANDROID');
    expect(a.last!.method, 'POST');
    expect(a.last!.path, '/viewer/devices');
    expect(a.last!.data, {'token': 'abc', 'platform': 'ANDROID'});
  });

  test('unregisterDevice DELETEs with token query', () async {
    final a = _Capture(204);
    ApiService.instance.dio.httpClientAdapter = a;
    await svc.unregisterDevice(token: 'abc');
    expect(a.last!.method, 'DELETE');
    expect(a.last!.path, '/viewer/devices');
    expect(a.last!.queryParameters, {'token': 'abc'});
  });

  test('4xx becomes ApiException', () async {
    ApiService.instance.dio.httpClientAdapter = _Capture(403);
    expect(
      svc.registerDevice(token: 't', platform: 'IOS'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'status', 403)),
    );
  });

  test('ViewerDeviceRegistry maps the platform wire value', () async {
    final a = _Capture(204);
    ApiService.instance.dio.httpClientAdapter = a;
    await ViewerDeviceRegistry().register('t', PushPlatform.ios);
    expect(a.last!.data, {'token': 't', 'platform': 'IOS'});
  });
}
