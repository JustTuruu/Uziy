import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/campaign.dart';
import '../models/payout_request.dart';
import '../models/survey_question.dart';
import '../models/user.dart';
import '../models/view_history_item.dart';
import 'api_error.dart';
import 'api_service.dart';
import 'campaign_events.dart';

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

  /// GET /public/feed — a few sample cards for a not-signed-in visitor
  /// (no demographic targeting, no video URL).
  Future<List<Campaign>> guestFeed() async {
    const fallback = 'Санал болгосон видеонуудыг ачаалж чадсангүй';
    try {
      final r = await _dio.get<dynamic>('/public/feed');
      _check(r, fallback);
      return (r.data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Campaign.fromJson)
          .toList();
    } on DioException catch (e) {
      throw _map(e, fallback);
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
            'answerJson': encodeAnswer(e.value),
          };
        }).toList(),
      };
      final r = await _dio.post<Map<String, dynamic>>(
        '/viewer/campaigns/$campaignId/submit',
        data: body,
      );
      _check(r, 'Илгээхэд алдаа гарлаа');
      final result = RewardResult(
        rewardPaid: (r.data!['rewardPaid'] as num).toDouble(),
        newBalance: (r.data!['newBalance'] as num).toDouble(),
      );
      CampaignEvents.instance.publishCompleted(
        CampaignCompleted(campaignId, newBalance: result.newBalance),
      );
      return result;
    } on DioException catch (e) {
      throw _alreadyCompleted(campaignId, _map(e, 'Илгээхэд алдаа гарлаа'));
    } on ApiException catch (e) {
      throw _alreadyCompleted(campaignId, e);
    }
  }

  /// 409 means this campaign was already rewarded: it must leave the feed
  /// just like a fresh completion. The error itself is still reported.
  ApiException _alreadyCompleted(int campaignId, ApiException e) {
    if (e.statusCode == _conflict) {
      CampaignEvents.instance.publishCompleted(CampaignCompleted(campaignId));
    }
    return e;
  }

  static const int _conflict = 409;

  /// POST /viewer/payouts — request a bank payout (approval by admin).
  Future<Map<String, dynamic>> requestPayout({
    required double amount,
    required String bank,
    required String accountNumber,
    required String accountName,
  }) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/viewer/payouts',
        data: {
          'amount': amount,
          'bank': bank,
          'accountNumber': accountNumber,
          'accountName': accountName,
        },
      );
      _check(r, 'Хүсэлт илгээхэд алдаа гарлаа');
      return r.data!;
    } on DioException catch (e) {
      throw _map(e, 'Хүсэлт илгээхэд алдаа гарлаа');
    }
  }

  /// GET /viewer/payouts — the viewer's own payout requests, newest first.
  Future<List<PayoutRequest>> myPayouts() async {
    try {
      final r = await _dio.get<dynamic>('/viewer/payouts');
      _check(r, 'Хүсэлтүүдийг ачаалж чадсангүй');
      final list = r.data as List<dynamic>;
      return list
          .map((e) => PayoutRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _map(e, 'Хүсэлтүүдийг ачаалж чадсангүй');
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

  /// An answer as the JSON text the backend stores: a string, or an array of
  /// strings. A real encoder, so new lines, tabs, quotes and backslashes in a
  /// free-text answer are escaped instead of making the JSON invalid.
  @visibleForTesting
  static String encodeAnswer(dynamic v) =>
      jsonEncode(v is List ? v.map((x) => x.toString()).toList() : v);

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
  ) =>
      ApiException(
        s,
        apiErrorMessage(status: s, body: d, type: type, fallback: fallback),
      );
}

class RewardResult {
  final double rewardPaid;
  final double newBalance;
  const RewardResult({required this.rewardPaid, required this.newBalance});
}
