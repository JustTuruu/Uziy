import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_router.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/ui.dart';
import '../splash_screen.dart';
import 'auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
      context.go(Routes.home);
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

    return AmbientBackground(
      variant: AmbientVariant.gold,
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
                            const Spacer(flex: 2),
                            // Not wrapped in FadeSlideIn: it may arrive via
                            // a Hero flight from the splash screen.
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: UziyLogo(
                                size: 76,
                                heroTag: SplashScreen.logoHeroTag,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxxl),
                            FadeSlideIn(
                              index: 0,
                              child: Text(
                                'Тавтай морил',
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
                                  style: AppTextStyles.display,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            FadeSlideIn(
                              index: 2,
                              child: Text(
                                'Утасны дугаар болон нууц үгээ оруулна уу',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxxl),
                            FadeSlideIn(
                              index: 3,
                              child: PhonePrefixField(
                                controller: _phoneCtrl,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) =>
                                    _passFocus.requestFocus(),
                                validator: (v) => AuthValidators.phone(
                                  v,
                                  message: 'Утасны дугаараа шалгана уу',
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            FadeSlideIn(
                              index: 4,
                              child: PasswordField(
                                controller: _passCtrl,
                                focusNode: _passFocus,
                                hintText: 'Нууц үг',
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                validator: AuthValidators.password,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                ),
                                onPressed: () {
                                  // TODO: password reset flow.
                                },
                                child: const Text('Нууц үг мартсан?'),
                              ),
                            ),
                            AnimatedSize(
                              duration: switchDuration,
                              curve: AppMotion.standard,
                              alignment: Alignment.topCenter,
                              child: AnimatedSwitcher(
                                duration: switchDuration,
                                child: _error == null
                                    ? const SizedBox(
                                        key: ValueKey('no-error'),
                                        width: double.infinity,
                                      )
                                    : Padding(
                                        key: ValueKey(_error),
                                        padding: const EdgeInsets.only(
                                          top: AppSpacing.xs,
                                          bottom: AppSpacing.md,
                                        ),
                                        child: StatusBanner(message: _error!),
                                      ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            AppButton(
                              label: 'Нэвтрэх',
                              onPressed: _submit,
                              loading: _loading,
                              haptic: true,
                            ),
                            const Spacer(flex: 3),
                            const SizedBox(height: AppSpacing.xxl),
                            AuthFooterLink(
                              prompt: 'Шинээр бүртгүүлэх үү?',
                              action: 'Бүртгүүлэх',
                              onTap: () => context.push(Routes.register),
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
    );
  }
}
