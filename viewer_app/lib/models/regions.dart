/// Where a viewer lives: the capital or one of the 21 aimags, and in the
/// capital one of its 9 districts. Spelled exactly like the backend's
/// `MongolianRegions` — campaigns target a city by this exact name, so a
/// different spelling would quietly match nobody.
library;

const String kCapital = 'Улаанбаатар';

/// The 21 aimags, in Mongolian alphabetical order.
const List<String> kAimags = [
  'Архангай',
  'Баян-Өлгий',
  'Баянхонгор',
  'Булган',
  'Говь-Алтай',
  'Говьсүмбэр',
  'Дархан-Уул',
  'Дорноговь',
  'Дорнод',
  'Дундговь',
  'Завхан',
  'Орхон',
  'Өвөрхангай',
  'Өмнөговь',
  'Сүхбаатар',
  'Сэлэнгэ',
  'Төв',
  'Увс',
  'Ховд',
  'Хөвсгөл',
  'Хэнтий',
];

/// The capital's 9 districts (дүүрэг).
const List<String> kCapitalDistricts = [
  'Багануур',
  'Багахангай',
  'Баянгол',
  'Баянзүрх',
  'Налайх',
  'Сонгинохайрхан',
  'Сүхбаатар',
  'Хан-Уул',
  'Чингэлтэй',
];

/// What the registration picker offers: the capital first, then the aimags.
const List<String> kRegisterCities = [kCapital, ...kAimags];

bool isCapital(String city) => city == kCapital;

const String kDistrictRequired = 'Дүүргээ сонгоно уу';

/// Shown when no aimag or city was picked (nothing is preselected).
const String kCityRequired = 'Аймаг эсвэл хотоо сонгоно уу';

/// The district to send for [city]: in the capital the picked district, in
/// an aimag the optional typed sum (blank → null).
String? districtFor(String city, String input) {
  final value = input.trim();
  if (isCapital(city)) return kCapitalDistricts.contains(value) ? value : null;
  return value.isEmpty ? null : value;
}
