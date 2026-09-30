/// Gold Noir UI kit barrel.
///
/// `import '../widgets/ui.dart';` gives a screen every kit widget plus the
/// theme tokens (AppColors, AppRadii, AppSpacing, AppDurations, AppMotion,
/// AppShadows, AppGradients, AppTextStyles, AppLayout) and the formatting
/// helpers (formatTugrik, formatDurationShort, formatClock, formatPhoneMn,
/// formatGrouped, monogramOf).
///
/// Nothing here imports the router, so widget tests of kit consumers stay
/// independent of sibling screens.
library;

export '../theme/app_theme.dart';
export '../theme/tokens.dart';
export '../utils/format.dart';
export 'ambient_background.dart';
export 'animated_money.dart';
export 'app_button.dart';
export 'app_card.dart';
export 'brand_logo.dart';
export 'campaign_art.dart';
export 'coin.dart';
export 'confetti.dart';
export 'empty_state.dart';
export 'fade_slide_in.dart';
export 'fill_width.dart';
export 'info_row.dart';
export 'pressable.dart';
export 'section_header.dart';
export 'segmented_progress.dart';
export 'skeleton.dart';
export 'status_banner.dart';
export 'tag_chip.dart';
