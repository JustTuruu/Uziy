import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/regions.dart';
import '../../widgets/ui.dart';
import 'auth_widgets.dart' show LabeledField;

const String kCityLabel = 'Аймаг / хот';
const String kDistrictLabel = 'Дүүрэг';

/// Registration's location: the capital or an aimag from the list; in the
/// capital a district must be picked too, in an aimag the sum may be typed.
/// Picking another city clears the district so a stale one is never sent.
class LocationFields extends StatelessWidget {
  const LocationFields({
    super.key,
    required this.city,
    required this.district,
    required this.onCityChanged,
  });

  /// Holds the chosen city (one of [kRegisterCities]).
  final TextEditingController city;

  /// Holds the picked capital district or the typed sum.
  final TextEditingController district;

  /// Lets the parent rebuild after the city changed.
  final ValueChanged<String> onCityChanged;

  @override
  Widget build(BuildContext context) {
    final chosen = kRegisterCities.contains(city.text);
    final capital = isCapital(city.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(
          label: kCityLabel,
          // Nothing is preselected: a default would quietly register an
          // aimag viewer in the capital (owner, 2026-10-14).
          child: RegionDropdown(
            key: const ValueKey('city'),
            value: chosen ? city.text : null,
            options: kRegisterCities,
            validator: (v) => v == null ? kCityRequired : null,
            onChanged: (v) {
              city.text = v;
              district.clear();
              onCityChanged(v);
            },
          ),
        ),
        if (chosen) const SizedBox(height: AppSpacing.md),
        if (capital)
          LabeledField(
            label: kDistrictLabel,
            child: RegionDropdown(
              key: const ValueKey('district'),
              value: kCapitalDistricts.contains(district.text)
                  ? district.text
                  : null,
              options: kCapitalDistricts,
              validator: (v) => v == null ? kDistrictRequired : null,
              onChanged: (v) => district.text = v,
            ),
          )
        else if (chosen)
          LabeledField(
            label: 'Сум',
            optional: true,
            child: TextFormField(
              key: const ValueKey('sum'),
              controller: district,
              textInputAction: TextInputAction.done,
              style: context.textStyles.body,
              decoration: const InputDecoration(),
            ),
          ),
      ],
    );
  }
}

/// One themed dropdown of place names; long names ellipsize instead of
/// overflowing at small widths or large text.
class RegionDropdown extends StatelessWidget {
  const RegionDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
    this.validator,
  });

  final String? value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final String? hint;
  final FormFieldValidator<String>? validator;

  /// About eight rows, then the menu scrolls.
  static const double menuMaxHeight = 360;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(hintText: hint),
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      iconEnabledColor: context.colors.textSecondary,
      dropdownColor: context.colors.surfaceElevated,
      borderRadius: AppRadii.brMd,
      menuMaxHeight: menuMaxHeight,
      style: context.textStyles.body,
      validator: validator,
      items: [
        for (final o in options)
          DropdownMenuItem(
            value: o,
            child: Text(o, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v == null) return;
        HapticFeedback.selectionClick();
        onChanged(v);
      },
    );
  }
}
