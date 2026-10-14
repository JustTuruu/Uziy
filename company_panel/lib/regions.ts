/**
 * Where a campaign can be shown: everywhere, the capital, or one of the 21
 * aimags. Spelled exactly like the backend's `MongolianRegions` and the viewer
 * app's `regions.dart` — a viewer is matched on this exact name, so keep the
 * three lists in step.
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

export const EVERYWHERE_LABEL = "Бүх аймаг, хот";

/** Options for the targeting picker: everywhere, the capital, then aimags. */
export const TARGET_CITY_OPTIONS = [EVERYWHERE, CAPITAL, ...AIMAGS].map(
  (value) => ({
    value,
    label: value === EVERYWHERE ? EVERYWHERE_LABEL : value,
  }),
);
