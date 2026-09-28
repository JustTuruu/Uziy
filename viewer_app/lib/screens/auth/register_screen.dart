import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/user.dart';
import '../../routes/app_router.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/incentive_banner.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: 'Улаанбаатар');
  final _districtCtrl = TextEditingController();

  Gender? _gender;
  DateTime? _birthDate;
  bool _loading = false;
  bool _agreedToTerms = false;

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
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 13),
      helpText: 'Төрсөн он сар өдөр',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null || _birthDate == null) {
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
    setState(() => _loading = true);
    try {
      await AuthService.instance.register(
        phone: _phoneCtrl.text.trim(),
        password: _passCtrl.text,
        gender: _gender!,
        birthDate: _birthDate!,
        city: _cityCtrl.text,
        district: _districtCtrl.text.trim().isEmpty
            ? null
            : _districtCtrl.text.trim(),
      );
      if (!mounted) return;
      context.go(Routes.home);
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
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _TermsSheet(),
    );
  }

  void _openPrivacy() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _PrivacySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(title: const Text('Бүртгүүлэх')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const IncentiveBanner(),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.phone_iphone),
                    hintText: 'Утасны дугаар',
                    prefixText: '+976 ',
                  ),
                  validator: (v) => (v == null || v.length != 8)
                      ? '8 оронтой утасны дугаар'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.lock_outline),
                    hintText: 'Нууц үг (доод тал нь 6 тэмдэгт)',
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Дор хаяж 6 тэмдэгт' : null,
                ),
                const SizedBox(height: 20),
                const _SectionLabel('Хүйс'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _GenderChip(
                        label: 'Эрэгтэй',
                        icon: Icons.male,
                        selected: _gender == Gender.male,
                        onTap: () => setState(() => _gender = Gender.male),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GenderChip(
                        label: 'Эмэгтэй',
                        icon: Icons.female,
                        selected: _gender == Gender.female,
                        onTap: () => setState(() => _gender = Gender.female),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _SectionLabel('Төрсөн он сар өдөр'),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickBirthDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cake_outlined,
                            color: AppColors.textSecondary),
                        const SizedBox(width: 12),
                        Text(
                          _birthDate == null
                              ? 'Огноо сонгох'
                              : df.format(_birthDate!),
                          style: TextStyle(
                            color: _birthDate == null
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionLabel('Хот'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _cityCtrl.text.isEmpty ? null : _cityCtrl.text,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  dropdownColor: AppColors.surfaceElevated,
                  items: _cities
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _cityCtrl.text = v ?? 'Улаанбаатар'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _districtCtrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.pin_drop_outlined),
                    hintText: 'Дүүрэг / Сум (сонгох)',
                  ),
                ),
                const SizedBox(height: 24),
                _TermsCheckbox(
                  value: _agreedToTerms,
                  onChanged: (v) =>
                      setState(() => _agreedToTerms = v ?? false),
                  onTapTerms: _openTerms,
                  onTapPrivacy: _openPrivacy,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: (_loading || !_agreedToTerms) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: AppColors.surfaceElevated,
                    disabledForegroundColor: AppColors.textSecondary,
                  ),
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
                      : const Text('Бүртгүүлэх'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color:
                    selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.value,
    required this.onChanged,
    required this.onTapTerms,
    required this.onTapPrivacy,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onTapTerms;
  final VoidCallback onTapPrivacy;

  @override
  Widget build(BuildContext context) {
    final linkStyle = const TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.primary,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.primary,
                checkColor: Colors.black,
                side: const BorderSide(
                    color: AppColors.textSecondary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                  children: [
                    const TextSpan(text: 'Би '),
                    TextSpan(
                      text: 'Үйлчилгээний нөхцөл',
                      style: linkStyle,
                      recognizer: TapGestureRecognizerFactory(onTapTerms),
                    ),
                    const TextSpan(text: ' болон '),
                    TextSpan(
                      text: 'Нууцлалын бодлого',
                      style: linkStyle,
                      recognizer: TapGestureRecognizerFactory(onTapPrivacy),
                    ),
                    const TextSpan(text: '-той танилцаж, зөвшөөрч байна.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsSheet extends StatelessWidget {
  const _TermsSheet();

  @override
  Widget build(BuildContext context) {
    return _LegalSheet(
      title: 'Үйлчилгээний нөхцөл',
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
    return _LegalSheet(
      title: 'Нууцлалын бодлого',
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
          '4. Хадгалалт',
          'Мэдээлэл нь Cloudflare R2 болон PostgreSQL сервер дээр '
              'шифрлэгдэн хадгалагдана. Данс устгах хүсэлт гаргасан '
              'тохиолдолд 30 хоногийн дотор бүх мэдээллийг устгана.',
        ),
        _LegalP(
          '5. Холбоо барих',
          'Асуулт, гомдол, санал байвал: support@rewardedvideo.mn',
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
  const _LegalSheet({required this.title, required this.body});
  final String title;
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
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                itemCount: body.length,
                separatorBuilder: (_, __) => const SizedBox(height: 18),
                itemBuilder: (context, i) {
                  final p = body[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.heading,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.body,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                          height: 1.55,
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

/// Small factory that returns a fresh TapGestureRecognizer per usage. Needed
/// because TextSpan.recognizer expects a GestureRecognizer instance, and
/// TapGestureRecognizer must be constructed with the callback.
class TapGestureRecognizerFactory extends TapGestureRecognizer {
  TapGestureRecognizerFactory(VoidCallback onTap) {
    this.onTap = onTap;
  }
}

