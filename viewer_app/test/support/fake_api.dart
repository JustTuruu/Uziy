import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:viewer_app/services/api_service.dart';

/// One request the app made, as the fake backend saw it.
class RecordedCall {
  RecordedCall(this.method, this.path, this.body);
  final String method;
  final String path;
  final Object? body;

  @override
  String toString() => '$method $path $body';
}

/// A scripted reply: HTTP [status] and a JSON [body] (null for 204).
class FakeReply {
  const FakeReply(this.status, [this.body]);
  final int status;
  final Object? body;
}

/// Stands in for the backend: records every call and answers with whatever
/// [respond] returns for it. Install with [FakeApi.install].
class FakeApi implements HttpClientAdapter {
  FakeApi(this.respond);

  final FakeReply Function(RecordedCall call) respond;
  final calls = <RecordedCall>[];

  /// Makes every [ApiService] request go through a new fake; returns it.
  static FakeApi install(FakeReply Function(RecordedCall call) respond) {
    final fake = FakeApi(respond);
    ApiService.instance.dio.httpClientAdapter = fake;
    return fake;
  }

  Iterable<RecordedCall> callsTo(String path) =>
      calls.where((c) => c.path == path);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final call = RecordedCall(options.method, options.path, options.data);
    calls.add(call);
    final reply = respond(call);
    return ResponseBody.fromString(
      reply.body == null ? '' : jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
