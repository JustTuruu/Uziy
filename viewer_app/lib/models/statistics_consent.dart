/// The viewer's answer to "may your answers be used in anonymous
/// statistics?" (`GET/PUT /viewer/consents/statistics`). Never asked counts
/// as no.
enum StatisticsConsentStatus {
  unasked,
  granted,
  declined;

  /// Anything unknown reads as [unasked]: it never claims a yes.
  static StatisticsConsentStatus fromWire(Object? value) => switch (value) {
        'GRANTED' => StatisticsConsentStatus.granted,
        'DECLINED' => StatisticsConsentStatus.declined,
        _ => StatisticsConsentStatus.unasked,
      };
}

class StatisticsConsent {
  const StatisticsConsent({required this.status, this.decidedAt});

  final StatisticsConsentStatus status;
  final DateTime? decidedAt;

  bool get granted => status == StatisticsConsentStatus.granted;

  factory StatisticsConsent.fromJson(Map<String, dynamic> json) {
    final at = json['decidedAt'] as String?;
    return StatisticsConsent(
      status: StatisticsConsentStatus.fromWire(json['status']),
      decidedAt: at == null ? null : DateTime.parse(at).toLocal(),
    );
  }
}
