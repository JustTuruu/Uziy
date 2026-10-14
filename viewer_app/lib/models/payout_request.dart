/// Where a payout request stands; mirrors the backend's `PayoutStatus`.
enum PayoutStatus {
  pending,
  approved,
  rejected;

  /// Unknown wire values read as pending, so a new backend state never
  /// claims money was paid.
  static PayoutStatus fromWire(Object? value) => switch (value) {
        'APPROVED' => PayoutStatus.approved,
        'REJECTED' => PayoutStatus.rejected,
        _ => PayoutStatus.pending,
      };
}

/// The viewer's own payout request, as `GET /viewer/payouts` returns it
/// (backend `PayoutDto`, newest first). Only the fields the app shows.
class PayoutRequest {
  final int id;
  final double amount;
  final String bank;
  final PayoutStatus status;
  final DateTime requestedAt;
  final DateTime? decidedAt;
  final String? rejectReason;

  /// Account holder name the viewer typed; null when missing or blank.
  final String? accountName;

  const PayoutRequest({
    required this.id,
    required this.amount,
    required this.bank,
    required this.status,
    required this.requestedAt,
    this.decidedAt,
    this.rejectReason,
    this.accountName,
  });

  bool get isPending => status == PayoutStatus.pending;

  factory PayoutRequest.fromJson(Map<String, dynamic> json) {
    final decidedAt = json['decidedAt'] as String?;
    final reason = (json['rejectReason'] as String?)?.trim();
    final holder = (json['accountName'] as String?)?.trim();
    return PayoutRequest(
      id: (json['id'] as num).toInt(),
      amount: (json['amount'] as num).toDouble(),
      bank: json['bank'] as String? ?? '',
      status: PayoutStatus.fromWire(json['status']),
      requestedAt: DateTime.parse(json['requestedAt'] as String).toLocal(),
      decidedAt: decidedAt == null ? null : DateTime.parse(decidedAt).toLocal(),
      rejectReason: reason == null || reason.isEmpty ? null : reason,
      accountName: holder == null || holder.isEmpty ? null : holder,
    );
  }
}
