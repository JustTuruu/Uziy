import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../services/viewer_service.dart';
import '../../widgets/ui.dart';
import 'wallet_logic.dart';
import 'wallet_widgets.dart';

/// First-payout verification flow.
/// Spec §4A: the Admin verifies that the bank account holder's name matches
/// the viewer. (The national ID is no longer asked for — owner, 2026-10-14.) On match, is_verified = TRUE — this is the
/// anti-fraud gate against fake profiles.
class PayoutRequestScreen extends StatefulWidget {
  const PayoutRequestScreen({super.key, this.firstPayout = false});

  /// Shows the 'Эхний таталт' notice — only before the viewer's first
  /// payout, never again once one is waiting or paid.
  final bool firstPayout;

  @override
  State<PayoutRequestScreen> createState() => _PayoutRequestScreenState();
}

class _PayoutRequestScreenState extends State<PayoutRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController.fromValue(
    quickAmountValue(kDefaultPayoutAmount),
  );
  final _accountNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _amountFocus = FocusNode();
  String _bank = kDefaultPayoutBank;
  bool _loading = false;

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
    super.dispose();
  }

  /// Tapping into the amount selects it all, so typing a new number
  /// replaces the old one instead of being added to it.
  void _onAmountFocus() {
    if (!_amountFocus.hasFocus) return;
    _amountCtrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _amountCtrl.text.length,
    );
  }

  void _pickAmount(int amount) {
    _amountCtrl.value = quickAmountValue(amount);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(walletErrorSnackBar(message, palette: context.colors));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    setState(() => _loading = true);
    try {
      final amount = payoutAmountOf(_amountCtrl.text)!.toDouble();
      await ViewerService.instance.requestPayout(
        amount: amount,
        bank: _bank,
        accountNumber: _accountNumberCtrl.text.trim(),
        accountName: _accountNameCtrl.text.trim(),
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
                  if (widget.firstPayout) ...[
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
                  ],
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
    );
  }

  /// The amount: a big framed input the user types into (grouped as they
  /// type), with quick picks under it that fill the same field.
  Widget _amountCard() {
    OutlineInputBorder frame(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: AppRadii.brMd,
          borderSide: BorderSide(color: color, width: width),
        );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(kPayoutAmountLabel, style: context.textStyles.overline),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _amountCtrl,
            focusNode: _amountFocus,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: const [PayoutAmountFormatter()],
            style: context.textStyles.display.copyWith(
              fontFeatures: AppTextStyles.tabular,
            ),
            cursorColor: context.colors.primary,
            decoration: InputDecoration(
              filled: true,
              fillColor: context.colors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              border: frame(context.colors.borderStrong),
              enabledBorder: frame(context.colors.borderStrong),
              focusedBorder: frame(context.colors.primary, 1.5),
              errorBorder: frame(context.colors.danger),
              focusedErrorBorder: frame(context.colors.danger, 1.5),
              hintText: '0',
              hintStyle: context.textStyles.display.copyWith(
                color: context.colors.textTertiary,
              ),
              helperText: kPayoutAmountHelper,
              helperMaxLines: 2,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.sm,
                ),
                child: CoinIcon(size: 28),
              ),
              prefixIconConstraints: const BoxConstraints(),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Text(
                  tugrikSymbol,
                  style: context.textStyles.displaySmall.copyWith(
                    color: context.colors.primary,
                  ),
                ),
              ),
              suffixIconConstraints: const BoxConstraints(),
            ),
            validator: validatePayoutAmount,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            kQuickAmountsLabel,
            style: context.textStyles.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
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

  /// Account number and holder name, grouped in one card.
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
          fillColor: context.colors.background,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Дансны мэдээлэл',
          subtitle: 'Данс таны өөрийн нэр дээр байх ёстой',
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
                style: context.textStyles.bodyStrong.copyWith(
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
                textInputAction: TextInputAction.done,
                style: context.textStyles.bodyStrong,
                decoration: field(
                  label: 'Дансны эзэмшигчийн нэр',
                  icon: Icons.person_outline_rounded,
                ),
                validator: validateAccountName,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
