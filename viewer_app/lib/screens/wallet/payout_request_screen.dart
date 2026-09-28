import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

/// First-payout verification flow.
/// Spec §4A: the Admin verifies that the bank account name + national ID
/// match the profile data. On match, is_verified = TRUE — this is the
/// anti-fraud gate against fake profiles.
class PayoutRequestScreen extends StatefulWidget {
  const PayoutRequestScreen({super.key});

  @override
  State<PayoutRequestScreen> createState() => _PayoutRequestScreenState();
}

class _PayoutRequestScreenState extends State<PayoutRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController(text: '2000');
  final _accountNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _nationalIdCtrl = TextEditingController();
  String _bank = 'Khan Bank';
  bool _loading = false;

  static const _banks = [
    'Khan Bank',
    'Golomt Bank',
    'TDB',
    'Xac Bank',
    'State Bank',
    'M Bank',
    'Capitron Bank',
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _accountNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _nationalIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    // TODO: POST /payouts/request — enters PENDING queue for Admin review.
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _loading = false);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Хүсэлт хүлээн авлаа'),
        content: const Text(
          'Таны эхний татах хүсэлт админаар шалгагдаж, дансны нэр таарсны '
          'дараа is_verified статус олгогдоно. 1-2 ажлын өдрийн дотор мөнгө '
          'таны данс руу орно.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            child: const Text('Ойлголоо'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мөнгө татах')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.accent.withOpacity(0.35)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          color: AppColors.accent, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Эхний удаа мөнгө татахад дансны нэр таны бүртгэлтэй '
                          'мэдээлэлтэй заавал таарсан байх шаардлагатай. '
                          'Ингэснээр таны бүртгэл баталгаажина.',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.attach_money),
                    suffixText: '₮',
                    hintText: 'Татах дүн',
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '') ?? 0;
                    if (n < 1000) return 'Хамгийн бага дүн: 1,000 ₮';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _bank,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                  dropdownColor: AppColors.surfaceElevated,
                  items: _banks
                      .map((b) =>
                          DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setState(() => _bank = v ?? _bank),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _accountNumberCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.numbers),
                    hintText: 'Дансны дугаар',
                  ),
                  validator: (v) =>
                      (v == null || v.length < 8) ? 'Дансны дугаар' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _accountNameCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline),
                    hintText: 'Дансны эзэмшигчийн нэр',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 3) ? 'Нэр' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nationalIdCtrl,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.badge_outlined),
                    hintText: 'Регистрийн дугаар (АА99999999)',
                  ),
                  validator: (v) => (v == null || v.length != 10)
                      ? '10 оронтой регистр'
                      : null,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.black),
                          ),
                        )
                      : const Text('Хүсэлт илгээх'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
