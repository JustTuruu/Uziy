import 'package:dio/dio.dart';

import '../models/campaign.dart';
import '../models/survey_question.dart';
import '../models/user.dart';
import '../models/view_history_item.dart';
import 'api_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ViewerService {
  ViewerService._();
  static final ViewerService instance = ViewerService._();

  Dio get _dio => ApiService.instance.dio;

  /// GET /viewer/me — current user + balance.
  Future<AppUser> me() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/viewer/me');
      _check(r, 'Профайл ачаалж чадсангүй');
      return AppUser.fromJson(r.data!);
    } on DioException catch (e) {
      throw _map(e, 'Профайл ачаалж чадсангүй');
    }
  }

  /// GET /viewer/feed — targeted campaigns the user hasn't watched.
  Future<List<Campaign>> feed() async {
    try {
      final r = await _dio.get<dynamic>('/viewer/feed');
      _check(r, 'Санал болгосон видеонуудыг ачаалж чадсангүй');
      return (r.data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Campaign.fromJson)
          .toList();
    } on DioException catch (e) {
      throw _map(e, 'Санал болгосон видеонуудыг ачаалж чадсангүй');
    }
  }

  /// GET /viewer/history — the viewer's completed views, newest first.
  Future<List<ViewHistoryItem>> history() async {
    const fallback = 'Түүх ачаалж чадсангүй';
    try {
      final r = await _dio.get<dynamic>('/viewer/history');
      _check(r, fallback);
      return (r.data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ViewHistoryItem.fromJson)
          .toList();
    } on DioException catch (e) {
      throw _map(e, fallback);
    }
  }

  /// GET /viewer/campaigns/{id}/questions
  Future<List<SurveyQuestion>> questions(int campaignId) async {
    try {
      final r = await _dio.get<dynamic>(
        '/viewer/campaigns/$campaignId/questions',
      );
      _check(r, 'Асуултууд ачаалж чадсангүй');
      return (r.data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(SurveyQuestion.fromJson)
          .toList();
    } on DioException catch (e) {
      throw _map(e, 'Асуултууд ачаалж чадсангүй');
    }
  }

  /// POST /viewer/campaigns/{id}/submit — the atomic reward transaction.
  Future<RewardResult> submitSurvey({
    required int campaignId,
    required Map<int, dynamic>
        answers, // questionId → answer (String / List<String>)
  }) async {
    try {
      final body = {
        'answers': answers.entries.map((e) {
          return {
            'questionId': e.key,
            // Backend column is JSONB. Send answers as JSON-encoded strings
            // (a string, a JSON array of strings, or a JSON object).
            'answerJson': _encodeAnswer(e.value),
          };
        }).toList(),
      };
      final r = await _dio.post<Map<String, dynamic>>(
        '/viewer/campaigns/$campaignId/submit',
        data: body,
      );
      _check(r, 'Илгээхэд алдаа гарлаа');
      return RewardResult(
        rewardPaid: (r.data!['rewardPaid'] as num).toDouble(),
        newBalance: (r.data!['newBalance'] as num).toDouble(),
      );
    } on DioException catch (e) {
      throw _map(e, 'Илгээхэд алдаа гарлаа');
    }
  }

  /// POST /viewer/payouts — request a bank payout (approval by admin).
  Future<Map<String, dynamic>> requestPayout({
    required double amount,
    required String bank,
    required String accountNumber,
    required String accountName,
    required String nationalId,
  }) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/viewer/payouts',
        data: {
          'amount': amount,
          'bank': bank,
          'accountNumber': accountNumber,
          'accountName': accountName,
          'nationalId': nationalId,
        },
      );
      _check(r, 'Хүсэлт илгээхэд алдаа гарлаа');
      return r.data!;
    } on DioException catch (e) {
      throw _map(e, 'Хүсэлт илгээхэд алдаа гарлаа');
    }
  }

  /// POST /viewer/devices — register an FCM token for push (204).
  Future<void> registerDevice({
    required String token,
    required String platform, // 'ANDROID' | 'IOS'
  }) async {
    const fallback = 'Мэдэгдэл бүртгэж чадсангүй';
    try {
      final r = await _dio.post<dynamic>(
        '/viewer/devices',
        data: {'token': token, 'platform': platform},
      );
      _check(r, fallback);
    } on DioException catch (e) {
      throw _map(e, fallback);
    }
  }

  /// DELETE /viewer/devices?token=… — forget this device (logout).
  Future<void> unregisterDevice({required String token}) async {
    const fallback = 'Мэдэгдэл цуцалж чадсангүй';
    try {
      final r = await _dio.delete<dynamic>(
        '/viewer/devices',
        queryParameters: {'token': token},
      );
      _check(r, fallback);
    } on DioException catch (e) {
      throw _map(e, fallback);
    }
  }

  String _encodeAnswer(dynamic v) {
    if (v is String) return '"${v.replaceAll('"', r'\"')}"';
    if (v is List) {
      final parts =
          v.map((x) => '"${x.toString().replaceAll('"', r'\"')}"').join(',');
      return '[$parts]';
    }
    return v.toString();
  }

  /// The shared Dio accepts every status below 500 (see ApiService), so a
  /// 401/403/404/409 comes back as a normal response. Call this right after
  /// each request to turn those into an [ApiException] carrying the status —
  /// otherwise the error body gets parsed as data and surfaces as a bogus
  /// "can't reach the server" message.
  void _check(Response<dynamic> r, String fallback) {
    final s = r.statusCode ?? 0;
    if (s >= 200 && s < 300) return;
    throw _apiError(s, r.data, null, fallback);
  }

  ApiException _map(DioException e, String fallback) => _apiError(
      e.response?.statusCode ?? 0, e.response?.data, e.type, fallback);

  ApiException _apiError(
    int s,
    Object? d,
    DioExceptionType? type,
    String fallback,
  ) {
    String message = fallback;
    if (d is Map<String, dynamic> && d['message'] is String) {
      message = d['message'] as String;
    } else if (s == 401 || s == 403) {
      message = 'Дахин нэвтэрнэ үү';
    } else if (s == 409) {
      message = 'Аль хэдийн үзсэн байна';
    } else if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.connectionError) {
      message = 'Сервертэй холбогдож чадсангүй';
    }
    return ApiException(s, message);
  }
}

class RewardResult {
  final double rewardPaid;
  final double newBalance;
  const RewardResult({required this.rewardPaid, required this.newBalance});
}
