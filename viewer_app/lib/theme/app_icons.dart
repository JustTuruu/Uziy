import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The app's icon vocabulary: one name per meaning, so a screen asks for
/// `AppIcons.history` and never picks a glyph itself. Swapping the icon set
/// later means editing this file only.
///
/// Lucide: one consistent rounded 2 px stroke family, which reads cleaner
/// and more modern than the stock Material glyphs.
abstract final class AppIcons {
  // Profile hero
  static const IconData user = LucideIcons.user;
  static const IconData verified = LucideIcons.badgeCheck;
  static const IconData unverified = LucideIcons.shieldAlert;
  static const IconData check = LucideIcons.check;
  static const IconData hint = LucideIcons.info;

  // Personal info
  static const IconData male = LucideIcons.mars;
  static const IconData female = LucideIcons.venus;
  static const IconData genderUnknown = LucideIcons.user;
  static const IconData age = LucideIcons.cake;
  static const IconData city = LucideIcons.building2;
  static const IconData district = LucideIcons.mapPin;

  // Menu
  static const IconData history = LucideIcons.history;
  static const IconData help = LucideIcons.lifeBuoy;
  static const IconData privacy = LucideIcons.shieldCheck;
  static const IconData logout = LucideIcons.logOut;
  static const IconData watched = LucideIcons.circlePlay;

  // Wallet history
  static const IconData payout = LucideIcons.landmark;
  static const IconData payoutReturned = LucideIcons.undo2;
  static const IconData moneyIn = LucideIcons.arrowDownLeft;
  static const IconData moneyOut = LucideIcons.arrowUpRight;

  // How it works
  static const IconData answer = LucideIcons.listChecks;
  static const IconData reward = LucideIcons.coins;
  static const IconData next = LucideIcons.arrowRight;

  // Password visibility (thin Lucide strokes, like the rest of the set)
  static const IconData passwordHidden = LucideIcons.eyeOff;
  static const IconData passwordShown = LucideIcons.eye;

  // Login field adornments (2026-10-14 reference design)
  static const IconData phone = LucideIcons.phone;
  static const IconData lock = LucideIcons.lock;

  // One-time code
  static const IconData otp = LucideIcons.messageSquareText;
  static const IconData resetPassword = LucideIcons.keyRound;

  // Controls
  static const IconData chevron = LucideIcons.chevronRight;
  static const IconData back = LucideIcons.chevronLeft;
  static const IconData expand = LucideIcons.chevronDown;
  static const IconData retry = LucideIcons.refreshCw;
}
