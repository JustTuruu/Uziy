import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../services/viewer_service.dart';
import '../../widgets/ui.dart';
import 'wallet_logic.dart';
import 'wallet_widgets.dart';

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
  final _amountFocus = FocusNode();
  String _bank = kDefaultPayoutBank;
  bool _loading = false;
  bool _amountFocused = false;

  /// Errors show on submit; after a failed submit they update as the user
  /// types, so a fixed field clears its message right away.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _amountFocus.addListener(_onAmountFocus);
  }

  @override
  void dispose() {
    _amountFocus
      ..removeListener(_onAmountFocus)
      ..dispose();
    _amountCtrl.dispose();
    _accountNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _nationalIdCtrl.dispose();
    super.dispose();
  }

  void _onAmountFocus() {
    if (_amountFocused != _amountFocus.hasFocus) {
      setState(() => _amountFocused = _amountFocus.hasFocus);
    }
  }

  void _pickAmount(int amount) {
    _amountCtrl.value = quickAmountValue(amount);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(walletErrorSnackBar(message));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    setState(() => _loading = true);
    try {
      final amount = double.parse(_amountCtrl.text);
      await ViewerService.instance.requestPayout(
        amount: amount,
        bank: _bank,
        accountNumber: _accountNumberCtrl.text.trim(),
        accountName: _accountNameCtrl.text.trim(),
        nationalId: _nationalIdCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _loading = false);
      HapticFeedback.mediumImpact();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (sheetContext) => PayoutSuccessSheet(
          amount: amount,
          bank: _bank,
          onDone: () => Navigator.pop(sheetContext),
        ),
      );
      // However the sheet is closed, the request is done: go back to the
      // wallet instead of leaving a filled form that could be re-sent.
      if (!mounted) return;
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Илгээхэд алдаа гарлаа');
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = math.max(
      AppLayout.screenPadding,
      (width - AppLayout.maxContentWidth) / 2,
    );

    return AmbientBackground(
      variant: AmbientVariant.subtle,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Мөнгө татах'),
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                gutter,
                AppSpacing.sm,
                gutter,
                AppSpacing.xxl,
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidate,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FadeSlideIn(
                      child: StatusBanner(
                        tone: BannerTone.info,
                        icon: Icons.verified_user_outlined,
                        title: 'Эхний таталт',
                        message: 'Эхний удаа мөнгө татахад дансны нэр таны '
                            'бүртгэлтэй мэдээлэлтэй заавал таарсан байх '
                            'шаардлагатай. Ингэснээр таны бүртгэл '
                            'баталгаажна.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    FadeSlideIn(index: 1, child: _amountCard()),
                    const SizedBox(height: AppSpacing.xxxl),
                    FadeSlideIn(
                      index: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionHeader(title: 'Банк сонгох'),
                          const SizedBox(height: AppSpacing.md),
                          BankPicker(
                            selected: _bank,
                            onSelected: (b) => setState(() => _bank = b),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    FadeSlideIn(index: 3, child: _accountCard()),
                    const SizedBox(height: AppSpacing.xxxl),
                    FadeSlideIn(
                      index: 4,
                      child: AppButton(
                        label: 'Хүсэлт илгээх',
                        icon: Icons.send_rounded,
                        loading: _loading,
                        haptic: true,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Big display-size amount with a coin, '₮', a hint and quick picks.
  Widget _amountCard() {
    return AnimatedContainer(
      duration: AppMotion.duration(context, AppDurations.fast),
      curve: AppMotion.standard,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.brLg,
        border: Border.all(
          color: _amountFocused
              ? AppColors.primary.withValues(alpha: 0.70)
              : AppColors.border,
          width: _amountFocused ? 1.5 : 1,
        ),
        boxShadow: _amountFocused
            ? AppShadows.glow(
                AppColors.primary,
                strength: 0.25,
                blur: 24,
                offset: Offset.zero,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Татах дүн', style: AppTextStyles.overline),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _amountCtrl,
            focusNode: _amountFocus,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTextStyles.display.copyWith(
              fontFeatures: AppTextStyles.tabular,
            ),
            cursorColor: AppColors.primary,
            decoration: InputDecoration(
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              hintText: '0',
              hintStyle: AppTextStyles.display.copyWith(
                color: AppColors.textTertiary,
              ),
              helperText: 'Хамгийн багадаа 1,000 ₮ татах боломжтой',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(right: AppSpacing.md),
                child: CoinIcon(size: 30),
              ),
              prefixIconConstraints: const BoxConstraints(),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Text(
                  tugrikSymbol,
                  style: AppTextStyles.displaySmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              suffixIconConstraints: const BoxConstraints(),
            ),
            validator: validatePayoutAmount,
          ),
          const SizedBox(height: AppSpacing.lg),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _amountCtrl,
            builder: (context, value, _) => QuickAmountChips(
              selected: selectedQuickAmount(value.text),
              onSelected: _pickAmount,
            ),
          ),
        ],
      ),
    );
  }

  /// Account number, holder name and national ID, grouped in one card.
  Widget _accountCard() {
    InputDecoration field({
      required String label,
      required IconData icon,
      String? hint,
    }) =>
        InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          fillColor: AppColors.background,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Дансны мэдээлэл',
          subtitle: 'Нэр, регистр таны бүртгэлтэй таарах ёстой',
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _accountNumberCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTextStyles.bodyStrong.copyWith(
                  fontFeatures: AppTextStyles.tabular,
                ),
                decoration: field(
                  label: 'Дансны дугаар',
                  icon: Icons.numbers_rounded,
                ),
                validator: validateAccountNumber,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _accountNameCtrl,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                style: AppTextStyles.bodyStrong,
                decoration: field(
                  label: 'Дансны эзэмшигчийн нэр',
                  icon: Icons.person_outline_rounded,
                ),
                validator: validateAccountName,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _nationalIdCtrl,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10),
                ],
                style: AppTextStyles.bodyStrong,
                decoration: field(
                  label: 'Регистрийн дугаар',
                  hint: 'АА99999999',
                  icon: Icons.badge_outlined,
                ),
                validator: validateNationalId,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
