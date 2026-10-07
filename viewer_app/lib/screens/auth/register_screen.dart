import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/register_draft.dart';
import '../../models/user.dart';
import '../../routes/app_router.dart' show Routes;
import '../../routes/auth_gate.dart';
import '../../services/auth_service.dart';
import '../../widgets/incentive_banner.dart';
import '../../widgets/ui.dart';
import 'auth_widgets.dart';

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
  final _cityCtrl = TextEditingController(text: 'Улаанбаатар');
  final _districtCtrl = TextEditingController();
  final _passFocus = FocusNode();
  final _scrollCtrl = ScrollController();

  // Scroll targets for "jump to the first problem" after a failed submit.
  final _credentialsKey = GlobalKey();
  final _aboutKey = GlobalKey();

  Gender? _gender;
  DateTime? _birthDate;
  bool _loading = false;
  bool _agreedToTerms = false;

  /// Set on the first submit attempt: highlights a missing gender / birth
  /// date inline (in addition to the snackbar).
  bool _attempted = false;

  /// The large page title has scrolled away: show it in the app bar.
  bool _compactTitle = false;

  static const _cities = [
    'Улаанбаатар',
    'Дархан',
    'Эрдэнэт',
    'Чойбалсан',
    'Мөрөн',
    'Ховд',
    'Өлгий',
    'Бусад',
  ];

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
      _scrollTo(_credentialsKey);
      return;
    }
    if (_gender == null || _birthDate == null) {
      _scrollTo(_aboutKey);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Хүйс болон төрсөн өдрөө сонгоно уу'),
        ),
      );
      return;
    }
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Үйлчилгээний нөхцөлийг зөвшөөрнө үү'),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final phone = _phoneCtrl.text.trim();
    try {
      // The account is created on the next screen, with the texted code.
      await AuthService.instance.requestOtp(
        phone: phone,
        purpose: OtpPurpose.register,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      await context.push(
        authLocation(Routes.verify, next: widget.next),
        extra: RegisterDraft(
          phone: phone,
          password: _passCtrl.text,
          gender: _gender!,
          birthDate: _birthDate!,
          city: _cityCtrl.text,
          district: _districtCtrl.text.trim().isEmpty
              ? null
              : _districtCtrl.text.trim(),
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
        const SnackBar(content: Text('Алдаа гарлаа, дахин оролдоно уу')),
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

  void _selectGender(Gender g) {
    if (_gender == g) return;
    setState(() => _gender = g);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final fast = AppMotion.duration(context, AppDurations.fast);
    final showGenderError = _attempted && _gender == null;
    final showBirthError = _attempted && _birthDate == null;

    return AmbientBackground(
      variant: AmbientVariant.gold,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: _compactTitle
              ? AppColors.background.withValues(alpha: 0.94)
              : Colors.transparent,
          shape: Border(
            bottom: BorderSide(
              color: _compactTitle ? AppColors.border : Colors.transparent,
            ),
          ),
          automaticallyImplyLeading: false,
          leading: canPop
              ? Center(
                  child: AppIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    semanticLabel: 'Буцах',
                    size: 40,
                    iconSize: 18,
                    onPressed: () => Navigator.of(context).maybePop(),
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
          agreed: _agreedToTerms,
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
                    FadeSlideIn(
                      index: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: const Text(
                              'Бүртгүүлэх',
                              style: AppTextStyles.display,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Мэдээллээ оруулаад урамшуулалт видео үзэж '
                            'эхлээрэй.',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const FadeSlideIn(index: 1, child: IncentiveBanner()),
                    const SizedBox(height: AppSpacing.xxxl),
                    FadeSlideIn(
                      key: _credentialsKey,
                      index: 2,
                      child: _FormSection(
                        title: 'Нэвтрэх мэдээлэл',
                        subtitle: 'Дараа нэвтрэхдээ эдгээрийг ашиглана',
                        children: [
                          PhonePrefixField(
                            controller: _phoneCtrl,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => _passFocus.requestFocus(),
                            validator: (v) => AuthValidators.phone(
                              v,
                              message: '8 оронтой утасны дугаар',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          PasswordField(
                            controller: _passCtrl,
                            focusNode: _passFocus,
                            hintText: 'Нууц үг (доод тал нь 6 тэмдэгт)',
                            textInputAction: TextInputAction.done,
                            validator: AuthValidators.password,
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
                        subtitle: 'Таны мэдээлэл нууцлагдан хадгалагдана',
                        children: [
                          const FieldLabel('Хүйс'),
                          Row(
                            children: [
                              Expanded(
                                child: GenderOptionCard(
                                  label: 'Эрэгтэй',
                                  icon: Icons.male_rounded,
                                  selected: _gender == Gender.male,
                                  error: showGenderError,
                                  onTap: () => _selectGender(Gender.male),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: GenderOptionCard(
                                  label: 'Эмэгтэй',
                                  icon: Icons.female_rounded,
                                  selected: _gender == Gender.female,
                                  error: showGenderError,
                                  onTap: () => _selectGender(Gender.female),
                                ),
                              ),
                            ],
                          ),
                          _AnimatedError(
                            show: showGenderError,
                            message: 'Хүйсээ сонгоно уу',
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          const FieldLabel('Төрсөн он сар өдөр'),
                          BirthDateTile(
                            value: _birthDate,
                            error: showBirthError,
                            onTap: _pickBirthDate,
                          ),
                          _AnimatedError(
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
                        subtitle: 'Таны бүсийн урамшууллыг харуулахад '
                            'ашиглана',
                        children: [
                          const FieldLabel('Хот'),
                          DropdownButtonFormField<String>(
                            initialValue:
                                _cityCtrl.text.isEmpty ? null : _cityCtrl.text,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.location_city_rounded),
                            ),
                            // Fill the field and ellipsize, so a long city
                            // name never overflows at small widths / large
                            // text.
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            iconEnabledColor: AppColors.textSecondary,
                            dropdownColor: AppColors.surfaceElevated,
                            borderRadius: AppRadii.brMd,
                            menuMaxHeight: 360,
                            style: AppTextStyles.body,
                            items: _cities
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              HapticFeedback.selectionClick();
                              setState(
                                () => _cityCtrl.text = v ?? 'Улаанбаатар',
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _districtCtrl,
                            textInputAction: TextInputAction.done,
                            style: AppTextStyles.body,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.pin_drop_outlined),
                              hintText: 'Дүүрэг / Сум (заавал биш)',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    FadeSlideIn(
                      index: 5,
                      child: TermsAgreementTile(
                        value: _agreedToTerms,
                        onChanged: (v) => setState(() => _agreedToTerms = v),
                        onTapTerms: _openTerms,
                        onTapPrivacy: _openPrivacy,
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
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: title,
          subtitle: subtitle,
          padding: const EdgeInsets.only(left: 2, bottom: AppSpacing.lg),
        ),
        ...children,
      ],
    );
  }
}

/// Inline required-field message that grows / shrinks in.
class _AnimatedError extends StatelessWidget {
  const _AnimatedError({required this.show, required this.message});

  final bool show;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.duration(context, AppDurations.normal),
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child:
          show ? FieldError(message) : const SizedBox(width: double.infinity),
    );
  }
}

/// Pinned bottom bar with the primary CTA. Hidden behind the keyboard while
/// typing (Scaffold.bottomNavigationBar), always reachable otherwise.
class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.agreed,
    required this.loading,
    required this.onSubmit,
  });

  final bool agreed;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.94),
        border: const Border(top: BorderSide(color: AppColors.border)),
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
                  AnimatedSize(
                    duration: AppMotion.duration(context, AppDurations.normal),
                    curve: AppMotion.standard,
                    alignment: Alignment.bottomCenter,
                    child: agreed
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 14,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Үргэлжлүүлэхийн тулд нөхцөлийг '
                                    'зөвшөөрнө үү',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  AppButton(
                    label: 'Бүртгүүлэх',
                    onPressed: agreed ? onSubmit : null,
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
                color: AppColors.handle,
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
                      gradient: AppGradients.goldSoft,
                      borderRadius: AppRadii.brSm,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.28),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: AppTextStyles.title.copyWith(
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
                      Text(p.heading, style: AppTextStyles.titleSmall),
                      const SizedBox(height: 6),
                      Text(
                        p.body,
                        style: AppTextStyles.bodySmall.copyWith(
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
