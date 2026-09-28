import 'package:dio/dio.dart';

import '../models/campaign.dart';
import '../models/survey_question.dart';
import '../models/user.dart';
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
      return AppUser.fromJson(r.data!);
    } on DioException catch (e) {
      throw _map(e, 'Профайл ачаалж чадсангүй');
    }
  }

  /// GET /viewer/feed — targeted campaigns the user hasn't watched.
  Future<List<Campaign>> feed() async {
    try {
      final r = await _dio.get<List<dynamic>>('/viewer/feed');
      return r.data!
          .cast<Map<String, dynamic>>()
          .map(Campaign.fromJson)
          .toList();
    } on DioException catch (e) {
      throw _map(e, 'Санал болгосон видеонуудыг ачаалж чадсангүй');
    }
  }

  /// GET /viewer/campaigns/{id}/questions
  Future<List<SurveyQuestion>> questions(int campaignId) async {
    try {
      final r = await _dio.get<List<dynamic>>(
        '/viewer/campaigns/$campaignId/questions',
      );
      return r.data!
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
    required Map<int, dynamic> answers, // questionId → answer (String / List<String>)
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
      return r.data!;
    } on DioException catch (e) {
      throw _map(e, 'Хүсэлт илгээхэд алдаа гарлаа');
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

  ApiException _map(DioException e, String fallback) {
    final s = e.response?.statusCode ?? 0;
    final d = e.response?.data;
    String message = fallback;
    if (d is Map<String, dynamic> && d['message'] is String) {
      message = d['message'] as String;
    } else if (s == 401) {
      message = 'Дахин нэвтэрнэ үү';
    } else if (s == 409) {
      message = 'Аль хэдийн үзсэн байна';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
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
