import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/regions.dart';
import '../../models/register_draft.dart';
import '../../models/user.dart';
import '../../routes/app_router.dart' show Routes;
import '../../routes/auth_gate.dart';
import '../../services/api_error.dart';
import '../../services/auth_service.dart';
import '../../widgets/incentive_banner.dart';
import '../../widgets/ui.dart';
import 'auth_widgets.dart';
import 'location_fields.dart';
import 'phone_verify_logic.dart' show kSmsPriceNote;
import 'login_fields.dart';

/// The pinned button: it does not create the account yet, it opens the
/// SMS step.
const String kContinueLabel = 'Үргэлжлүүлэх';

/// Caption above it, ending in the operator's SMS price.
const String kNextStepNote =
    'Дараа нь дугаараа SMS-ээр баталгаажуулна. $kSmsPriceNote';

/// Shown under the terms tile when 'Бүртгүүлэх' is tapped before agreeing.
const String kTermsRequired = 'Үйлчилгээний нөхцөлийг зөвшөөрнө үү';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.next});

  /// Page to open after registering (see `auth_gate.dart`); null means Home.
  final String? next;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _passFocus = FocusNode();
  final _scrollCtrl = ScrollController();

  // Scroll targets for "jump to the first problem" after a failed submit.
  final _credentialsKey = GlobalKey();
  final _aboutKey = GlobalKey();
  final _termsKey = GlobalKey();

  Gender? _gender;
  DateTime? _birthDate;
  bool _loading = false;
  bool _agreedToTerms = false;

  /// Set on the first submit attempt: highlights a missing gender / birth
  /// date inline (in addition to the snackbar).
  bool _attempted = false;

  /// The large page title has scrolled away: show it in the app bar.
  bool _compactTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _passFocus.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _lastNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final compact = _scrollCtrl.hasClients && _scrollCtrl.offset > 56;
    if (compact != _compactTitle) setState(() => _compactTitle = compact);
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: AppMotion.duration(context, AppDurations.medium),
      curve: AppMotion.standard,
    );
  }

  Future<void> _pickBirthDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final bounds = birthDatePickerBounds(now);
    final picked = await showDatePicker(
      context: context,
      initialDate: birthDatePickerInitial(_birthDate, now),
      firstDate: bounds.first,
      lastDate: bounds.last,
      helpText: 'Төрсөн он сар өдөр',
    );
    if (!mounted) return;
    if (picked != null) {
      HapticFeedback.selectionClick();
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_attempted) setState(() => _attempted = true);
    if (!_formKey.currentState!.validate()) {
      // Scroll to the first section that has a wrong field.
      final credentialsOk =
          AuthValidators.phone(_phoneCtrl.text, message: '') == null &&
              AuthValidators.password(_passCtrl.text) == null;
      _scrollTo(credentialsOk ? _aboutKey : _credentialsKey);
      return;
    }
    if (_gender == null || _birthDate == null) {
      // The fields say what is missing themselves; no extra snack bar.
      _scrollTo(_aboutKey);
      return;
    }
    if (!_agreedToTerms) {
      // The button stays tappable so the viewer learns why nothing happened:
      // the tile turns red and comes into view.
      _scrollTo(_termsKey);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final phone = phoneDigits(_phoneCtrl.text);
    try {
      // The account is created on the next screen, once the phone's SMS
      // has arrived.
      final verification =
          await AuthService.instance.startPhoneVerification(phone);
      if (!mounted) return;
      setState(() => _loading = false);
      await context.push(
        authLocation(Routes.verify, next: widget.next),
        extra: PendingRegistration(
          verification: verification,
          draft: RegisterDraft(
            phone: phone,
            password: _passCtrl.text,
            lastName: _lastNameCtrl.text.trim(),
            firstName: _firstNameCtrl.text.trim(),
            gender: _gender!,
            birthDate: _birthDate!,
            city: _cityCtrl.text,
            district: districtFor(_cityCtrl.text, _districtCtrl.text),
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kUnexpectedError)),
      );
    }
  }

  void _openTerms() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _TermsSheet(),
    );
  }

  void _openPrivacy() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _PrivacySheet(),
    );
  }

  void _selectGender(Gender g) => setState(() => _gender = g);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final fast = AppMotion.duration(context, AppDurations.fast);
    final showGenderError = _attempted && _gender == null;
    final showBirthError = _attempted && _birthDate == null;
    final showTermsError = _attempted && !_agreedToTerms;

    return LoginFieldsTheme(
      child: Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          backgroundColor: _compactTitle
              ? context.colors.background.withValues(alpha: 0.94)
              : Colors.transparent,
          shape: Border(
            bottom: BorderSide(
              color: _compactTitle ? context.colors.border : Colors.transparent,
            ),
          ),
          automaticallyImplyLeading: false,
          leadingWidth: AppLayout.screenPadding + AppLayout.minTapTarget,
          leading: canPop
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppLayout.screenPadding,
                  ),
                  child: Center(
                    child: AuthBackButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                )
              : null,
          title: AnimatedOpacity(
            opacity: _compactTitle ? 1 : 0,
            duration: fast,
            child: const Text('Бүртгүүлэх'),
          ),
        ),
        bottomNavigationBar: _SubmitBar(
          loading: _loading,
          onSubmit: _submit,
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  AppLayout.screenPadding,
                  AppSpacing.xs,
                  AppLayout.screenPadding,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FadeSlideIn(
                      index: 0,
                      child: AuthPageTitle('Бүртгүүлэх'),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    // Spec §4A: shown before the profile questions so the
                    // viewer knows why honest answers pay off.
                    const FadeSlideIn(index: 1, child: IncentiveBanner()),
                    const SizedBox(height: AppSpacing.xxxl),
                    FadeSlideIn(
                      key: _credentialsKey,
                      index: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LabeledField(
                            label: 'Утасны дугаар',
                            child: PhoneField(
                              controller: _phoneCtrl,
                              hintText: '',
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) =>
                                  _passFocus.requestFocus(),
                              validator: (v) => AuthValidators.phone(v,
                                  message: AuthValidators.phoneInvalid),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          LabeledField(
                            label: 'Нууц үг',
                            child: PasswordField(
                              controller: _passCtrl,
                              focusNode: _passFocus,
                              hintText: '',
                              showLeadingIcon: false,
                              helperText: '6-аас доошгүй тэмдэгт',
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.next,
                              validator: AuthValidators.password,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    FadeSlideIn(
                      key: _aboutKey,
                      index: 3,
                      child: _FormSection(
                        title: 'Таны тухай',
                        children: [
                          PersonNameFields(
                            lastName: _lastNameCtrl,
                            firstName: _firstNameCtrl,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const FieldLabel('Хүйс'),
                          GenderSelector(
                            value: _gender,
                            error: showGenderError,
                            onChanged: _selectGender,
                          ),
                          InlineFieldError(
                            show: showGenderError,
                            message: 'Хүйсээ сонгоно уу',
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          const FieldLabel('Төрсөн он сар өдөр'),
                          BirthDateTile(
                            placeholder: '',
                            value: _birthDate,
                            error: showBirthError,
                            onTap: _pickBirthDate,
                          ),
                          InlineFieldError(
                            show: showBirthError,
                            message: 'Төрсөн өдрөө сонгоно уу',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    FadeSlideIn(
                      index: 4,
                      child: _FormSection(
                        title: 'Байршил',
                        children: [
                          LocationFields(
                            city: _cityCtrl,
                            district: _districtCtrl,
                            onCityChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    FadeSlideIn(
                      key: _termsKey,
                      index: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TermsAgreementTile(
                            value: _agreedToTerms,
                            error: showTermsError,
                            onChanged: (v) =>
                                setState(() => _agreedToTerms = v),
                            onTapTerms: _openTerms,
                            onTapPrivacy: _openPrivacy,
                          ),
                          InlineFieldError(
                            show: showTermsError,
                            message: kTermsRequired,
                          ),
                        ],
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
}

/// Titled group of fields.
class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: title,
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        ),
        ...children,
      ],
    );
  }
}

/// Pinned bottom bar with the primary CTA. Hidden behind the keyboard while
/// typing (Scaffold.bottomNavigationBar), always reachable otherwise.
class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.loading,
    required this.onSubmit,
  });

  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.background.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: context.colors.border)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppLayout.screenPadding,
                AppSpacing.md,
                AppLayout.screenPadding,
                0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Said before the tap: the next step is a paid SMS
                  // (Product principle 2: nothing costs money unannounced).
                  Text(
                    kNextStepNote,
                    textAlign: TextAlign.center,
                    style: context.textStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: kContinueLabel,
                    trailingIcon: AppIcons.next,
                    raised: true,
                    onPressed: onSubmit,
                    loading: loading,
                    haptic: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Legal sheets (text is verbatim — do not edit wording)
// ---------------------------------------------------------------------------

class _TermsSheet extends StatelessWidget {
  const _TermsSheet();

  @override
  Widget build(BuildContext context) {
    return const _LegalSheet(
      title: 'Үйлчилгээний нөхцөл',
      icon: Icons.description_outlined,
      body: [
        _LegalP(
          '1. Ерөнхий заалт',
          'Uziy аппликейшн нь Монгол Улсын хэрэглэгчдэд зорилтот '
              'видео сурталчилгаа хүргэж, үзэгчид тэдгээрийг үзэж, судалгаа '
              'бөглөсний төлөө урамшуулал олгодог платформ юм.',
        ),
        _LegalP(
          '2. Хэрэглэгчийн үүрэг',
          'Хэрэглэгч бүртгүүлэхдээ бодит, үнэн зөв мэдээлэл (нас, хүйс, '
              'байршил) оруулах үүрэгтэй. Худал мэдээлэл оруулсан тохиолдолд '
              'дансыг түр хаах эсвэл балансыг цуцлах эрхтэй.',
        ),
        _LegalP(
          '3. Урамшуулал ба төлбөр',
          'Урамшуулал зөвхөн видеог бүтэн үзэж, судалгааг бүрэн бөглөсний '
              'дараа тооцогдоно. Эхний удаа мөнгө татахад дансны эзэмшигчийн '
              'нэр таны бүртгэлтэй мэдээлэлтэй таарч байх ёстой.',
        ),
        _LegalP(
          '4. Хориотой үйлдэл',
          'Автомат хэрэгсэл (bot), олон дансаар нэг хүн ашиглах, VPN-ээр '
              'байршил өөрчлөх зэрэг залилан үйлдэл илэрсэн тохиолдолд '
              'холбогдох дансыг цуцалж, хуулийн байгууллагад мэдэгдэнэ.',
        ),
        _LegalP(
          '5. Үйлчилгээний өөрчлөлт',
          'Аппын үйл ажиллагаа, нөхцөл, урамшууллын хувь хэмжээ өөрчлөгдөх '
              'боломжтой бөгөөд томоохон өөрчлөлтийн үед хэрэглэгчид урьдчилан '
              'мэдэгдэнэ.',
        ),
      ],
    );
  }
}

class _PrivacySheet extends StatelessWidget {
  const _PrivacySheet();

  @override
  Widget build(BuildContext context) {
    return const _LegalSheet(
      title: 'Нууцлалын бодлого',
      icon: Icons.shield_outlined,
      body: [
        _LegalP(
          '1. Цуглуулах мэдээлэл',
          'Утасны дугаар, нас, хүйс, байршил, үзсэн видеонуудын түүх, '
              'судалгааны хариулт, гүйлгээний бүртгэл зэргийг цуглуулна.',
        ),
        _LegalP(
          '2. Ашиглалт',
          'Дээрх мэдээллийг зөвхөн танд тохирсон видео харуулах, урамшуулал '
              'тооцоолох, залилангаас сэргийлэх зорилгоор ашиглана. '
              'Гуравдагч этгээдэд тодорхойлох боломжтой хэлбэрээр '
              'дамжуулахгүй.',
        ),
        _LegalP(
          '3. Хуваалцах',
          'Компаниуд зөвхөн хураангуй (aggregate) түвшинд судалгааны '
              'үр дүнг хардаг. Хувь хэрэглэгчийн нэр, утасны дугаар зэрэг '
              'нь тэдэнд харагдахгүй.',
        ),
        _LegalP(
          '4. Холбоо барих',
          'Асуулт, гомдол, санал байвал: uziy@gmail.com',
        ),
      ],
    );
  }
}

class _LegalP {
  final String heading;
  final String body;
  const _LegalP(this.heading, this.body);
}

class _LegalSheet extends StatelessWidget {
  const _LegalSheet({
    required this.title,
    required this.icon,
    required this.body,
  });

  final String title;
  final IconData icon;
  final List<_LegalP> body;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.handle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: context.gradients.goldSoft,
                      borderRadius: AppRadii.brSm,
                      border: Border.all(
                        color: context.colors.primary.withValues(alpha: 0.28),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 20, color: context.colors.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: context.textStyles.title.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.close_rounded,
                    semanticLabel: 'Хаах',
                    size: 36,
                    iconSize: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.paddingOf(context).bottom + 32,
                ),
                itemCount: body.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 20),
                itemBuilder: (context, i) {
                  final p = body[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.heading, style: context.textStyles.titleSmall),
                      const SizedBox(height: 6),
                      Text(
                        p.body,
                        style: context.textStyles.bodySmall.copyWith(
                          fontSize: 13.5,
                          height: 1.6,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
