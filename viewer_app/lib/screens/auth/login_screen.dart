import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_router.dart';
import '../../routes/auth_gate.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/ui.dart';
import '../splash_screen.dart';
import 'auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.next});

  /// Page to open after signing in (see `auth_gate.dart`); null means Home.
  final String? next;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passFocus = FocusNode();
  bool _loading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  String? _error;

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.login(
        phone: _phoneCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;
      await finishAuth(context, widget.next);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e, stack) {
      // Never swallow — show the actual runtime error so we can diagnose
      // without hunting through the flutter run console.
      debugPrint('[login] unexpected error: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _error = 'Алдаа: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final switchDuration = AppMotion.duration(context, AppDurations.normal);
    final hero = authHeroMetrics(MediaQuery.sizeOf(context).height);

    return AmbientBackground(
      variant: AmbientVariant.gold,
      child: FallingCoins(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppLayout.maxContentWidth,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppLayout.screenPadding,
                          AppSpacing.xxl,
                          AppLayout.screenPadding,
                          AppSpacing.md,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Spacer(),
                              // Not wrapped in FadeSlideIn: it may arrive via
                              // a Hero flight from the splash screen.
                              Center(
                                child: UziyLogo(
                                  size: hero.logoSize,
                                  heroTag: SplashScreen.logoHeroTag,
                                ),
                              ),
                              SizedBox(height: hero.gap),
                              FadeSlideIn(
                                index: 0,
                                child: Text(
                                  'Тавтай морил',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.overline.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              FadeSlideIn(
                                index: 1,
                                child: Semantics(
                                  header: true,
                                  child: const Text(
                                    'Нэвтрэх',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.display,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              FadeSlideIn(
                                index: 2,
                                child: Text(
                                  'Утасны дугаар болон нууц үгээ оруулна уу',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              SizedBox(height: hero.gap),
                              FadeSlideIn(
                                index: 3,
                                child: AppCard(
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      PhonePrefixField(
                                        controller: _phoneCtrl,
                                        textInputAction: TextInputAction.next,
                                        onFieldSubmitted: (_) =>
                                            _passFocus.requestFocus(),
                                        validator: (v) => AuthValidators.phone(
                                          v,
                                          message: 'Утасны дугаараа шалгана уу',
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      PasswordField(
                                        controller: _passCtrl,
                                        focusNode: _passFocus,
                                        hintText: 'Нууц үг',
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _submit(),
                                        validator: AuthValidators.password,
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppColors.primary,
                                          ),
                                          onPressed: () =>
                                              context.push(Routes.forgot),
                                          child: const Text('Нууц үг мартсан?'),
                                        ),
                                      ),
                                      _ErrorSlot(
                                        duration: switchDuration,
                                        child: _error == null
                                            ? const SizedBox(
                                                key: ValueKey('no-error'),
                                                width: double.infinity,
                                              )
                                            : Padding(
                                                key: ValueKey(_error),
                                                padding: const EdgeInsets.only(
                                                  bottom: AppSpacing.md,
                                                ),
                                                child: StatusBanner(
                                                  message: _error!,
                                                ),
                                              ),
                                      ),
                                      AppButton(
                                        label: 'Нэвтрэх',
                                        onPressed: _submit,
                                        loading: _loading,
                                        haptic: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Center(
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.textSecondary,
                                    minimumSize: const Size(
                                      0,
                                      AppLayout.minTapTarget,
                                    ),
                                  ),
                                  onPressed: () => context.go(Routes.home),
                                  iconAlignment: IconAlignment.end,
                                  icon: const Icon(AppIcons.next, size: 16),
                                  label: const Text('Зочноор үзэх'),
                                ),
                              ),
                              if (!hero.compact) ...[
                                const SizedBox(height: AppSpacing.xl),
                                const FadeSlideIn(
                                  index: 4,
                                  child: HowItWorksStrip(),
                                ),
                              ],
                              const Spacer(flex: 2),
                              const SizedBox(height: AppSpacing.xxl),
                              AuthFooterLink(
                                prompt: 'Шинээр бүртгүүлэх үү?',
                                action: 'Бүртгүүлэх',
                                onTap: () => context.push(
                                  authLocation(Routes.register,
                                      next: widget.next),
                                ),
                              ),
                              if (kDebugMode) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Center(
                                  child: Text(
                                    'dev · API: ${ApiService.instance.dio.options.baseUrl}',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textTertiary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grows and cross-fades whatever [child] is. With no animation time (OS
/// reduce-motion) it is just [child]: an AnimatedSize whose duration is zero
/// re-dirties its own layout and throws.
class _ErrorSlot extends StatelessWidget {
  const _ErrorSlot({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (duration == Duration.zero) return child;
    return AnimatedSize(
      duration: duration,
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(duration: duration, child: child),
    );
  }
}
