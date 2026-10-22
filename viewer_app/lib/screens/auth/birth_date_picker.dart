import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../widgets/ui.dart';
import 'auth_widgets.dart';

// The birth date is picked on three wheels — Он · Сар · Өдөр — in a bottom
// sheet (owner, 2026-10-22). The month calendar it replaced needed a tap per
// month to travel back 20 years and felt hard to use.

const String kBirthPickerTitle = 'Төрсөн он сар өдөр';
const String kBirthPickerDone = 'Сонгох';
const String kYearWheelLabel = 'Он';
const String kMonthWheelLabel = 'Сар';
const String kDayWheelLabel = 'Өдөр';

/// Height of one row on a wheel, and of the whole wheel.
const double kBirthWheelItemExtent = 40;
const double kBirthWheelHeight = 216;

/// Days in [month] of [year] (leap years included).
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Month as the wheel shows it: '1-р сар' … '12-р сар'.
String birthMonthLabel(int month) => '$month-р сар';

/// The chosen date as it is said: '2007 оны 2-р сарын 22' (the dotted
/// '2007.02.22' read as a code, owner 2026-10-22).
String birthDateLong(DateTime date) =>
    '${date.year} оны ${date.month}-р сарын ${date.day}';

/// '19 настай'.
String birthAgeLabel(int age) => '$age настай';

/// The date the wheels stand for: the day is cut to the month's length (31
/// → 29 in a leap February) and the result kept within [first]..[last].
DateTime birthDateFrom(
  int year,
  int month,
  int day, {
  required DateTime first,
  required DateTime last,
}) {
  final date = DateTime(year, month, math.min(day, daysInMonth(year, month)));
  if (date.isBefore(first)) return first;
  if (date.isAfter(last)) return last;
  return date;
}

/// Opens [BirthDateSheet]; the chosen date, or null when dismissed.
Future<DateTime?> showBirthDatePicker(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    // As tall as the wheels need (the default 9/16 cap cut them off on small
    // phones); the sheet scrolls if even that does not fit.
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => BirthDateSheet(initial: initial, first: first, last: last),
  );
}

/// Он · Сар · Өдөр wheels, a live preview of the date and the age, and one
/// 'Сонгох' button.
class BirthDateSheet extends StatefulWidget {
  const BirthDateSheet({
    super.key,
    required this.initial,
    required this.first,
    required this.last,
    this.now,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;

  /// For the age in the preview; tests pin it.
  final DateTime? now;

  @override
  State<BirthDateSheet> createState() => _BirthDateSheetState();
}

class _BirthDateSheetState extends State<BirthDateSheet> {
  late DateTime _date = birthDateFrom(
    widget.initial.year,
    widget.initial.month,
    widget.initial.day,
    first: widget.first,
    last: widget.last,
  );
  late final _year =
      FixedExtentScrollController(initialItem: _date.year - widget.first.year);
  late final _month = FixedExtentScrollController(initialItem: _date.month - 1);
  late final _day = FixedExtentScrollController(initialItem: _date.day - 1);

  @override
  void dispose() {
    _year.dispose();
    _month.dispose();
    _day.dispose();
    super.dispose();
  }

  void _change({int? year, int? month, int? day}) {
    final next = birthDateFrom(
      year ?? _date.year,
      month ?? _date.month,
      day ?? _date.day,
      first: widget.first,
      last: widget.last,
    );
    if (next == _date) return;
    setState(() => _date = next);
    // A wheel may show a value the date could not keep (31 in February, a
    // month past the youngest allowed date): move it to what was kept.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _settle(_year, _date.year - widget.first.year);
      _settle(_month, _date.month - 1);
      _settle(_day, _date.day - 1);
    });
  }

  void _settle(FixedExtentScrollController wheel, int item) {
    if (wheel.hasClients && wheel.selectedItem != item) {
      wheel.jumpToItem(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final years = widget.last.year - widget.first.year + 1;
    final age = ageInYears(_date, widget.now ?? DateTime.now());
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.screenPadding,
        0,
        AppLayout.screenPadding,
        AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BirthDateSummary(date: _date, age: age),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              _Wheel(
                flex: 4,
                label: kYearWheelLabel,
                controller: _year,
                count: years,
                text: (i) => '${widget.first.year + i}',
                onSelected: (i) => _change(year: widget.first.year + i),
                capStart: true,
                capEnd: false,
              ),
              _Wheel(
                flex: 4,
                label: kMonthWheelLabel,
                controller: _month,
                count: 12,
                text: (i) => birthMonthLabel(i + 1),
                onSelected: (i) => _change(month: i + 1),
                capStart: false,
                capEnd: false,
              ),
              _Wheel(
                flex: 3,
                label: kDayWheelLabel,
                controller: _day,
                count: daysInMonth(_date.year, _date.month),
                text: (i) => '${i + 1}',
                onSelected: (i) => _change(day: i + 1),
                capStart: false,
                capEnd: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: kBirthPickerDone,
            haptic: true,
            onPressed: () => Navigator.of(context).pop(_date),
          ),
        ],
      ),
    );
  }
}

/// Top of the sheet, centred: what is being picked (quiet), the date as it
/// is said (large) and the age in a small pill. The date and age are
/// announced as the wheels turn.
class _BirthDateSummary extends StatelessWidget {
  const _BirthDateSummary({required this.date, required this.age});

  final DateTime date;
  final int age;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Semantics(
          header: true,
          child: Text(
            kBirthPickerTitle,
            textAlign: TextAlign.center,
            style: context.textStyles.label.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          liveRegion: true,
          child: Column(
            children: [
              Text(
                birthDateLong(date),
                textAlign: TextAlign.center,
                style: context.textStyles.headline,
              ),
              const SizedBox(height: AppSpacing.sm),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.actionWash,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.actionLine),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    birthAgeLabel(age),
                    style: context.textStyles.label.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One labelled wheel; the three share one highlight band, so only the outer
/// ends of the band are rounded.
class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.flex,
    required this.label,
    required this.controller,
    required this.count,
    required this.text,
    required this.onSelected,
    required this.capStart,
    required this.capEnd,
  });

  final int flex;
  final String label;
  final FixedExtentScrollController controller;
  final int count;
  final String Function(int index) text;
  final ValueChanged<int> onSelected;
  final bool capStart;
  final bool capEnd;

  @override
  Widget build(BuildContext context) {
    // The picker sets its own (system) text style; merge onto the app's so
    // the numbers use the app font like the rest of the form.
    final style = DefaultTextStyle.of(context).style.merge(
          context.textStyles.title,
        );
    return Expanded(
      flex: flex,
      child: Column(
        children: [
          ExcludeSemantics(
            child: Text(label, style: context.textStyles.caption),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: kBirthWheelHeight,
            child: Semantics(
              label: label,
              child: CupertinoPicker.builder(
                key: ValueKey('birth-wheel-$label'),
                scrollController: controller,
                itemExtent: kBirthWheelItemExtent,
                onSelectedItemChanged: onSelected,
                childCount: count,
                // The band is painted OVER the chosen row, so it must be
                // see-through (the opaque actionWash hid the chosen value).
                selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                  background: context.colors.primary
                      .withValues(alpha: kActionWashOpacity),
                  capStartEdge: capStart,
                  capEndEdge: capEnd,
                ),
                itemBuilder: (context, i) => Center(
                  child: Text(text(i), style: style),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
