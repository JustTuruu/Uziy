import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'info_row.dart';
import 'pressable.dart';
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

/// Header shortcut: a tap flips light <-> dark at once (the icon spins from
/// sun to moon), a long press opens the full sheet, which also offers
/// "follow the device".
class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key, this.controller});
  final ThemeController? controller;

  static const String toDarkLabel = 'Бараан горим руу шилжих';
  static const String toLightLabel = 'Цайвар горим руу шилжих';

  /// The icon shows the look on screen now, not the stored setting, so
  /// "follow the device" shows a sun or a moon too.
  static IconData iconFor(Brightness shown) => shown == Brightness.dark
      ? Icons.dark_mode_rounded
      : Icons.light_mode_rounded;

  static String labelFor(Brightness shown) =>
      shown == Brightness.dark ? toLightLabel : toDarkLabel;

  Future<void> _toggle(
      BuildContext context, ThemeController settings, Brightness shown) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final saved = await settings.setMode(ThemeController.oppositeOf(shown));
    if (!saved) {
      messenger?.showSnackBar(
          const SnackBar(content: Text(AppearanceSheet.saveFailedMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = controller ?? ThemeController.instance;
    final shown = Theme.of(context).brightness;
    return AnimatedSwitcher(
      duration: AppMotion.duration(context, AppDurations.normal),
      switchInCurve: AppMotion.emphasized,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) => RotationTransition(
        turns: Tween<double>(begin: -0.25, end: 0).animate(animation),
        child: ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
      ),
      child: Pressable(
        key: ValueKey(shown),
        onLongPress: () =>
            showAppearanceSettings(context, controller: settings),
        isButton: false,
        // The inner button already shrinks on press.
        scale: 1,
        child: AppIconButton(
          icon: iconFor(shown),
          semanticLabel: labelFor(shown),
          size: 40,
          color: context.colors.textSecondary,
          haptic: true,
          onPressed: () => _toggle(context, settings, shown),
        ),
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

  static const String saveFailedMessage =
      'Горим солигдлоо. Тохиргоог хадгалж чадсангүй, дахин сонгоно уу.';

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
                ThemeModeChoices(
                  selected: controller.mode,
                  onSelected: _select,
                ),
                if (_saveFailed) ...[
                  const SizedBox(height: 12),
                  const StatusBanner(
                      message: AppearanceSheet.saveFailedMessage),
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

/// The three modes as cards, each with a small picture of the app in that
/// look. Side by side when they fit; stacked on a narrow phone with large
/// text so the labels never squeeze.
class ThemeModeChoices extends StatelessWidget {
  const ThemeModeChoices({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onSelected;

  /// Order on screen: the explicit looks first, "follow the device" last.
  static const List<ThemeMode> order = [
    ThemeMode.light,
    ThemeMode.dark,
    ThemeMode.system,
  ];

  /// Narrowest card (at 1x text) that still fits its label.
  static const double minCardWidth = 92;
  static const double _gap = AppSpacing.sm + 2;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return LayoutBuilder(builder: (context, box) {
      final cardWidth =
          (box.maxWidth - _gap * (order.length - 1)) / order.length;
      final cards = [
        for (final mode in order)
          ThemeModeCard(
            mode: mode,
            selected: mode == selected,
            onTap: () => onSelected(mode),
          ),
      ];
      if (cardWidth >= minCardWidth * scale) {
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                Expanded(child: cards[i]),
              ],
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: _gap),
            cards[i],
          ],
        ],
      );
    });
  }
}

/// One mode: a preview of the app in that look, its name, and a ring + tick
/// when chosen.
class ThemeModeCard extends StatelessWidget {
  const ThemeModeCard({
    super.key,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fast = AppMotion.duration(context, AppDurations.fast);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Pressable(
        onTap: onTap,
        haptic: true,
        child: AnimatedContainer(
          duration: fast,
          curve: AppMotion.standard,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected
                ? context.colors.primary.withValues(alpha: 0.10)
                : context.colors.surface,
            borderRadius: AppRadii.brMd,
            border: Border.all(
              color: selected ? context.colors.primary : context.colors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: ThemePreview(mode: mode)),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: fast,
                    curve: AppMotion.emphasized,
                    child: Icon(Icons.check_circle_rounded,
                        size: 16, color: context.colors.primary),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      ThemeController.label(mode),
                      textAlign: TextAlign.center,
                      style: context.textStyles.label.copyWith(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A miniature of the home screen in the given look. "Follow the device" is
/// split diagonally, light on the left and dark on the right.
class ThemePreview extends StatelessWidget {
  const ThemePreview({super.key, required this.mode});

  final ThemeMode mode;

  static const double height = 84;

  @override
  Widget build(BuildContext context) {
    final Widget art = switch (mode) {
      ThemeMode.light => const _MiniScreen(AppPalette(false)),
      ThemeMode.dark => const _MiniScreen(AppPalette(true)),
      ThemeMode.system => const Stack(
          fit: StackFit.expand,
          children: [
            _MiniScreen(AppPalette(true)),
            ClipPath(
              clipper: _DiagonalHalf(),
              child: _MiniScreen(AppPalette(false)),
            ),
          ],
        ),
    };
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(borderRadius: AppRadii.brSm, child: art),
    );
  }
}

/// Header line, a balance pill and two feed cards, in [palette]'s colours.
class _MiniScreen extends StatelessWidget {
  const _MiniScreen(this.palette);
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    Widget bar(double widthFactor, Color color, {double height = 5}) =>
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFactor,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(height),
            ),
          ),
        );
    Widget card() => Expanded(
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: palette.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                bar(0.8, palette.textPrimary, height: 3),
              ],
            ),
          ),
        );
    return Container(
      color: palette.background,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: bar(0.7, palette.textPrimary)),
              Container(
                width: 18,
                height: 7,
                decoration: BoxDecoration(
                  color: palette.primary,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          bar(0.45, palette.textTertiary, height: 3),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              children: [card(), const SizedBox(width: 5), card()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Upper-left triangle of the box, for the "follow the device" split.
class _DiagonalHalf extends CustomClipper<Path> {
  const _DiagonalHalf();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(_DiagonalHalf oldClipper) => false;
}
