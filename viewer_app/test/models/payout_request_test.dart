import 'package:flutter_test/flutter_test.dart';
import 'package:viewer_app/models/payout_request.dart';

void main() {
  group('PayoutRequest.fromJson', () {
    test('reads the backend PayoutDto', () {
      final p = PayoutRequest.fromJson({
        'id': 7,
        'userId': 100,
        'userPhone': '88112233',
        'amount': 5000.0,
        'bank': 'Khan Bank',
        'accountNumber': '5000123456',
        'accountName': 'Бат',
        'status': 'REJECTED',
        'isFirstPayout': true,
        'requestedAt': '2026-10-14T03:00:00Z',
        'decidedAt': '2026-10-14T04:00:00Z',
        'rejectReason': '  Дансны нэр таарахгүй  ',
      });
      expect(p.id, 7);
      expect(p.amount, 5000);
      expect(p.bank, 'Khan Bank');
      expect(p.status, PayoutStatus.rejected);
      expect(p.isPending, isFalse);
      expect(p.requestedAt, DateTime.utc(2026, 10, 14, 3).toLocal());
      expect(p.decidedAt, DateTime.utc(2026, 10, 14, 4).toLocal());
      expect(p.rejectReason, 'Дансны нэр таарахгүй');
      expect(p.accountName, 'Бат');
    });

    test('a waiting request has no decision and no reason', () {
      final p = PayoutRequest.fromJson({
        'id': 1,
        'amount': 1000,
        'bank': 'TDB',
        'status': 'PENDING',
        'requestedAt': '2026-10-14T03:00:00Z',
        'decidedAt': null,
        'rejectReason': '',
      });
      expect(p.isPending, isTrue);
      expect(p.decidedAt, isNull);
      expect(p.rejectReason, isNull);
      expect(p.accountName, isNull, reason: 'missing in this payload');
    });

    test('a blank account name reads as none', () {
      final p = PayoutRequest.fromJson({
        'id': 1,
        'amount': 1000,
        'bank': 'TDB',
        'status': 'PENDING',
        'requestedAt': '2026-10-14T03:00:00Z',
        'accountName': '   ',
      });
      expect(p.accountName, isNull);
    });
  });

  test('wire statuses map exactly; unknown never reads as paid', () {
    expect(PayoutStatus.fromWire('PENDING'), PayoutStatus.pending);
    expect(PayoutStatus.fromWire('APPROVED'), PayoutStatus.approved);
    expect(PayoutStatus.fromWire('REJECTED'), PayoutStatus.rejected);
    expect(PayoutStatus.fromWire('PAID_OUT'), PayoutStatus.pending);
    expect(PayoutStatus.fromWire(null), PayoutStatus.pending);
  });
}
