import 'package:flutter/material.dart';

import '../models/statistics_consent.dart';
import '../services/viewer_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'info_row.dart';

// The viewer's consent to anonymous statistics (Mongolia's Personal Data
// Protection Law: a separate, informed, revocable yes). Never asked = no.

const String kStatsConsentTitle = 'Нэргүй статистикт оролцох уу?';
const String kStatsConsentBody =
    'Зөвшөөрвөл таны судалгааны хариултыг нэр, утас зэрэг таныг '
    'тодорхойлох мэдээлэлгүйгээр, дор хаяж 50 хүний хариулттай нэгтгэж, '
    'зөвхөн хувь хэлбэрээр статистик гаргана. Ийм нэгтгэсэн тайланг '
    'байгууллагуудад хүргэж болно. Чөлөөт бичсэн хариулт ордоггүй. '
    'Хүссэн үедээ Профайл хэсгээс цуцална.';
const String kStatsConsentYes = 'Зөвшөөрөх';
const String kStatsConsentNo = 'Үгүй';
const String kStatsConsentThanks =
    'Баярлалаа! Тохиргоог Профайлаас өөрчилж болно.';
const String kStatsConsentTileLabel = 'Нэргүй статистикт оролцох';
const String kStatsConsentOn = 'Зөвшөөрсөн';
const String kStatsConsentOff = 'Зөвшөөрөөгүй';

/// Minors are never in the statistics (a minor's yes is not enough), so they
/// are not asked. Mirrors the backend's StatisticsPrivacyPolicy.MIN_AGE.
const int kStatsConsentMinAge = 18;

/// Whether to ask a viewer of [age] at all; unknown age is not asked.
bool canAskStatsConsent(int? age) => age != null && age >= kStatsConsentMinAge;

/// Where the consent is read and stored; tests pass a fake.
abstract class StatisticsConsentApi {
  Future<StatisticsConsent> load();
  Future<StatisticsConsent> decide({required bool granted});
}

class ViewerStatisticsConsentApi implements StatisticsConsentApi {
  const ViewerStatisticsConsentApi();

  @override
  Future<StatisticsConsent> load() =>
      ViewerService.instance.statisticsConsent();

  @override
  Future<StatisticsConsent> decide({required bool granted}) =>
      ViewerService.instance.decideStatisticsConsent(granted: granted);
}

/// One-time question on Home: shown only while the viewer has never
/// answered; gone for good after Зөвшөөрөх or Үгүй. A failed load shows
/// nothing (it is asked again next time).
class StatsConsentPrompt extends StatefulWidget {
  const StatsConsentPrompt({
    super.key,
    this.api = const ViewerStatisticsConsentApi(),
  });

  final StatisticsConsentApi api;

  @override
  State<StatsConsentPrompt> createState() => _StatsConsentPromptState();
}

class _StatsConsentPromptState extends State<StatsConsentPrompt> {
  bool _ask = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final consent = await widget.api.load();
      if (!mounted) return;
      setState(() => _ask = consent.status == StatisticsConsentStatus.unasked);
    } catch (_) {
      // Not asking this time is safe: unasked counts as no.
    }
  }

  Future<void> _decide(bool granted) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await widget.api.decide(granted: granted);
      if (!mounted) return;
      setState(() => _ask = false);
      if (granted) {
        messenger?.showSnackBar(
          const SnackBar(content: Text(kStatsConsentThanks)),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ask) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(AppIcons.privacy, color: context.colors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      kStatsConsentTitle,
                      style: context.textStyles.bodyStrong,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(kStatsConsentBody, style: context.textStyles.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: kStatsConsentNo,
                    variant: AppButtonVariant.secondary,
                    onPressed: _saving ? null : () => _decide(false),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: kStatsConsentYes,
                    loading: _saving,
                    onPressed: _saving ? null : () => _decide(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Profile row with a switch: give or withdraw the consent at any time.
/// Hidden until the current state is known, so it never shows a wrong one.
class StatsConsentTile extends StatefulWidget {
  const StatsConsentTile({
    super.key,
    this.api = const ViewerStatisticsConsentApi(),
  });

  final StatisticsConsentApi api;

  @override
  State<StatsConsentTile> createState() => _StatsConsentTileState();
}

class _StatsConsentTileState extends State<StatsConsentTile> {
  bool? _granted;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.api.load().then((c) {
      if (mounted) setState(() => _granted = c.granted);
    }).catchError((Object _) {});
  }

  Future<void> _set(bool granted) async {
    final before = _granted;
    setState(() {
      _granted = granted;
      _saving = true;
    });
    try {
      final saved = await widget.api.decide(granted: granted);
      if (mounted) setState(() => _granted = saved.granted);
    } catch (_) {
      if (mounted) setState(() => _granted = before);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final granted = _granted;
    if (granted == null) return const SizedBox.shrink();
    return InfoRow(
      icon: AppIcons.privacy,
      iconColor: context.colors.success,
      label: kStatsConsentTileLabel,
      subtitle: granted ? kStatsConsentOn : kStatsConsentOff,
      trailing: Switch.adaptive(
        value: granted,
        onChanged: _saving ? null : _set,
      ),
    );
  }
}
