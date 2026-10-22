/**
 * Where a viewer lives / where a campaign can be shown: the capital or one of
 * the 21 aimags. Spelled exactly like the backend's `MongolianRegions` and the
 * viewer app's `regions.dart` — a viewer is matched on this exact name, so keep
 * the three lists in step (`regions.test.ts` compares this file with the Java one).
 * Shared by both panels: the company targeting picker and the admin user filter.
 */

/** `targetCity` for "every place". */
export const EVERYWHERE = "ALL";

export const CAPITAL = "Улаанбаатар";

/** The 21 aimags, in Mongolian alphabetical order. */
export const AIMAGS = [
  "Архангай",
  "Баян-Өлгий",
  "Баянхонгор",
  "Булган",
  "Говь-Алтай",
  "Говьсүмбэр",
  "Дархан-Уул",
  "Дорноговь",
  "Дорнод",
  "Дундговь",
  "Завхан",
  "Орхон",
  "Өвөрхангай",
  "Өмнөговь",
  "Сүхбаатар",
  "Сэлэнгэ",
  "Төв",
  "Увс",
  "Ховд",
  "Хөвсгөл",
  "Хэнтий",
] as const;

/** Every place a viewer can register in: the capital first, then the aimags. */
export const CITIES: readonly string[] = [CAPITAL, ...AIMAGS];

export const EVERYWHERE_LABEL = "Бүх аймаг, хот";

/** Options for a place picker: everywhere, the capital, then aimags. */
export const TARGET_CITY_OPTIONS = [EVERYWHERE, ...CITIES].map((value) => ({
  value,
  label: value === EVERYWHERE ? EVERYWHERE_LABEL : value,
}));
