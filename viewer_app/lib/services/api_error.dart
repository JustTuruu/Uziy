import 'package:dio/dio.dart';

/// User-facing error wording shared by every service and screen.
///
/// The backend words each of its errors in Mongolian (`message`), so that text
/// wins; the sentences here are only for when there is no answer to read
/// (no network, timeout) or the body carries no message.
const String kNoConnection =
    'Сервертэй холбогдож чадсангүй. Интернэт холболтоо шалгаад дахин оролдоно уу';
const String kTimeout = 'Хүсэлт удаж байна. Дахин оролдоно уу';
const String kSignInAgain = 'Дахин нэвтэрнэ үү';
const String kWrongCredentials = 'Утасны дугаар эсвэл нууц үг буруу байна';
const String kTooManyRequests = 'Түр хүлээгээд дахин оролдоно уу';
const String kServerError =
    'Серверт алдаа гарлаа. Түр хүлээгээд дахин оролдоно уу';

/// For a failure that is not an API answer at all (a bug, a bad payload).
const String kUnexpectedError = 'Алдаа гарлаа. Дахин оролдоно уу';

/// One sentence for a failed request, in this order: the backend's own
/// `message`; a network problem ([type]); [byStatus] for this call; a general
/// sentence for 401/403, 429 and 5xx; otherwise [fallback].
String apiErrorMessage({
  required int status,
  Object? body,
  DioExceptionType? type,
  required String fallback,
  Map<int, String> byStatus = const {},
}) {
  if (body is Map && body['message'] is String) {
    final message = (body['message'] as String).trim();
    if (message.isNotEmpty) return message;
  }
  switch (type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.connectionError:
      return kNoConnection;
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return kTimeout;
    default:
      break;
  }
  final forCall = byStatus[status];
  if (forCall != null) return forCall;
  if (status == 401 || status == 403) return kSignInAgain;
  if (status == 429) return kTooManyRequests;
  if (status >= 500) return kServerError;
  return fallback;
}
