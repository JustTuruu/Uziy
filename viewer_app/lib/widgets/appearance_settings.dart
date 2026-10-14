import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'info_row.dart';
import 'app_button.dart';
import 'status_banner.dart';

class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({super.key, this.controller});
  final ThemeController? controller;

  @override
  Widget build(BuildContext context) {
    final settings = controller ?? ThemeController.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => InfoRow(
        icon: Icons.contrast_rounded,
        label: 'Харагдах горим',
        subtitle: ThemeController.label(settings.mode),
        onTap: () => showAppearanceSettings(context, controller: settings),
      ),
    );
  }
}

Future<void> showAppearanceSettings(BuildContext context,
        {ThemeController? controller}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => AppearanceSheet(
        controller: controller ?? ThemeController.instance,
      ),
    );

class AppearanceSheet extends StatefulWidget {
  const AppearanceSheet({super.key, required this.controller});
  final ThemeController controller;

  @override
  State<AppearanceSheet> createState() => _AppearanceSheetState();
}

class _AppearanceSheetState extends State<AppearanceSheet> {
  bool _saveFailed = false;
  int _selection = 0;
  ThemeController get controller => widget.controller;

  Future<void> _select(ThemeMode mode) async {
    final selection = ++_selection;
    setState(() => _saveFailed = false);
    final saved = await controller.setMode(mode);
    if (!mounted || selection != _selection) return;
    setState(() => _saveFailed = !saved);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Харагдах горим', style: context.textStyles.headline),
                const SizedBox(height: 8),
                Text('Өөрт тухтай өнгөний горимоо сонгоорой.',
                    style: context.textStyles.bodySmall),
                const SizedBox(height: 16),
                for (final mode in ThemeMode.values)
                  Semantics(
                    selected: controller.mode == mode,
                    inMutuallyExclusiveGroup: true,
                    child: ListTile(
                      shape: const RoundedRectangleBorder(
                          borderRadius: AppRadii.brMd),
                      selected: controller.mode == mode,
                      selectedTileColor:
                          context.colors.primary.withValues(alpha: .10),
                      selectedColor: context.colors.primary,
                      leading: Icon(switch (mode) {
                        ThemeMode.system => Icons.settings_brightness_outlined,
                        ThemeMode.light => Icons.light_mode_outlined,
                        ThemeMode.dark => Icons.dark_mode_outlined,
                      }),
                      title: Text(ThemeController.label(mode)),
                      trailing: controller.mode == mode
                          ? Icon(Icons.check_rounded,
                              color: context.colors.primary)
                          : null,
                      onTap: () => _select(mode),
                    ),
                  ),
                if (_saveFailed) ...[
                  const SizedBox(height: 12),
                  const StatusBanner(
                    message:
                        'Горим солигдлоо. Тохиргоог хадгалж чадсангүй, дахин сонгоно уу.',
                  ),
                ],
                const SizedBox(height: 20),
                AppButton(
                    label: 'Боллоо',
                    onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
        ),
      );
}
