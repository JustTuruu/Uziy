import 'package:flutter/material.dart';

import '../../services/api_error.dart';
import '../../services/viewer_service.dart';
import '../../widgets/ui.dart';
import '../auth/auth_widgets.dart';
import '../auth/login_fields.dart';
import 'privacy_content.dart';
import 'profile_widgets.dart';

const String kDeleteTitle = 'Бүртгэлээ устгах уу?';
const String kDeleteIntro = 'Устгасны дараа буцаах боломжгүй.';
const String kDeletePasswordLabel = 'Нууц үг';
const String kDeletePasswordHint = 'Баталгаажуулахын тулд нууц үгээ оруулна уу';
const String kDeletePasswordRequired = 'Нууц үгээ оруулна уу';
const String kDeleteConfirm = 'Устгах';
const String kDeleteCancel = 'Болих';

/// The warning shown when money is left in the wallet: it is forfeited.
String deleteBalanceWarning(num balance) =>
    'Таны хэтэвчинд ${formatTugrik(balance)} байна. Бүртгэлээ устгавал энэ '
    'мөнгийг авах боломжгүй болно.';

/// Deletes the account with the typed password; throws [ApiException] with
/// a message to show (wrong password, payout still being checked).
typedef DeleteAccount = Future<void> Function(String password);

/// Opens [DeleteAccountSheet]; true once the account was deleted. Uses the
/// root navigator so the sheet covers the floating tab bar.
Future<bool> showDeleteAccountSheet(
  BuildContext context, {
  required num balance,
  required DeleteAccount onDelete,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => DeleteAccountSheet(balance: balance, onDelete: onDelete),
  );
  return result ?? false;
}

/// Says what deleting the account does ([kDeleteAccountFacts], the same
/// wording as the privacy page), warns when [balance] would be forfeited,
/// and asks for the password before calling [onDelete].
class DeleteAccountSheet extends StatefulWidget {
  const DeleteAccountSheet({
    super.key,
    required this.balance,
    required this.onDelete,
  });

  final num balance;
  final DeleteAccount onDelete;

  @override
  State<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<DeleteAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_deleting || !_formKey.currentState!.validate()) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.onDelete(_password.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = kUnexpectedError);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final secondary = context.textStyles.bodySmall.copyWith(
      color: context.colors.textSecondary,
    );
    return Padding(
      // Keeps the password field above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xs,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: LoginFieldsTheme(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Center(
                  child: DangerIconBadge(icon: AppIcons.deleteAccount),
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  header: true,
                  child: Text(
                    kDeleteTitle,
                    textAlign: TextAlign.center,
                    style: context.textStyles.headline,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  kDeleteIntro,
                  textAlign: TextAlign.center,
                  style: context.textStyles.body.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                for (final fact in kDeleteAccountFacts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Text('•  ', style: secondary),
                        ),
                        Expanded(child: Text(fact, style: secondary)),
                      ],
                    ),
                  ),
                if (widget.balance > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  StatusBanner(
                    key: const ValueKey('delete-balance-warning'),
                    tone: BannerTone.warning,
                    icon: AppIcons.warning,
                    message: deleteBalanceWarning(widget.balance),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                LabeledField(
                  label: kDeletePasswordLabel,
                  child: PasswordField(
                    controller: _password,
                    hintText: kDeletePasswordHint,
                    showLeadingIcon: false,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _delete(),
                    validator: (v) => (v == null || v.isEmpty)
                        ? kDeletePasswordRequired
                        : null,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  StatusBanner(message: error),
                ],
                const SizedBox(height: AppSpacing.xxl),
                AppButton(
                  label: kDeleteConfirm,
                  icon: AppIcons.deleteAccount,
                  variant: AppButtonVariant.danger,
                  loading: _deleting,
                  haptic: true,
                  onPressed: _delete,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: kDeleteCancel,
                  variant: AppButtonVariant.secondary,
                  onPressed:
                      _deleting ? null : () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
