import 'package:flutter/material.dart';

import '../models/statistics_consent.dart';
import '../services/viewer_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'info_row.dart';

// The viewer's consent to anonymous statistics (Mongolia's Personal Data
// Protection Law: a separate, informed, revocable yes). Never decided = no.
// Viewers are not asked any more (owner, 2026-10-21: the Home question after
// registration was removed); the switch on the privacy page is the only place
// to give or withdraw it.

const String kStatsConsentTileLabel = 'Нэргүй статистикт оролцох';
const String kStatsConsentOn = 'Зөвшөөрсөн';
const String kStatsConsentOff = 'Зөвшөөрөөгүй';

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

/// Row with a switch: give or withdraw the consent at any time. Shown on the
/// privacy page, under the statistics section.
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
