/// What the debug network log may print. Pure functions, no I/O.
///
/// Even a debug log ends up in places we do not control (a shared screen, a
/// pasted bug report, the device log on a tester's phone), so secrets in a
/// request body or query string are masked before they are printed.
library;

import 'dart:convert';

/// Body keys and query parameters whose values are never printed, compared
/// without case: passwords, the payout bank account, the FCM device token.
const Set<String> kRedactedLogKeys = {
  'password',
  'newpassword',
  'accountnumber',
  'token',
};

/// Printed instead of a masked value.
const String kRedactedValue = '***';

bool _isRedactedKey(Object? key) =>
    kRedactedLogKeys.contains(key.toString().toLowerCase());

/// [data] (a request body: map, list, JSON string or anything else) with the
/// values of [kRedactedLogKeys] replaced by [kRedactedValue], at any depth.
/// A string that is not JSON is returned unchanged.
Object? redactForLog(Object? data) {
  if (data is Map) {
    return {
      for (final entry in data.entries)
        entry.key: _isRedactedKey(entry.key)
            ? kRedactedValue
            : redactForLog(entry.value),
    };
  }
  if (data is List) return [for (final item in data) redactForLog(item)];
  if (data is String) return _redactJsonString(data);
  return data;
}

String _redactJsonString(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    return text;
  }
  if (decoded is! Map && decoded is! List) return text;
  return jsonEncode(redactForLog(decoded));
}

/// [uri] as text with the values of [kRedactedLogKeys] query parameters
/// replaced by [kRedactedValue] (kept readable, not percent-encoded).
String redactUriForLog(Uri uri) {
  if (!uri.hasQuery) return uri.toString();
  final pairs = <String>[
    for (final entry in uri.queryParametersAll.entries)
      for (final value in entry.value)
        '${Uri.encodeQueryComponent(entry.key)}='
            '${_isRedactedKey(entry.key) ? kRedactedValue : Uri.encodeQueryComponent(value)}',
  ];
  // A raw '?' can only start the query, so everything before it is the
  // scheme, host and path (the fragment after the query is dropped).
  final base = uri.toString().split('?').first;
  return '$base?${pairs.join('&')}';
}
