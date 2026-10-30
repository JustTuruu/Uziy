/**
 * Age targeting rules of the campaign wizard. The backend refuses the same
 * ranges (`TargetAgeRule`); checking here lets the form explain it before
 * anything is sent.
 */

export const MIN_TARGET_AGE = 13;
export const MAX_TARGET_AGE = 99;
/**
 * `maxAge - minAge` must be at least this (mirrors TargetAgeRule.MIN_AGE_SPAN):
 * one exact age in one aimag can be a handful of people, whose answers the
 * company would then see one by one.
 */
export const MIN_AGE_SPAN = 5;

export const AGE_OUT_OF_RANGE_MESSAGE =
  "Нас 13-99 хооронд, бага нас нь их наснаас хэтрэхгүй байх ёстой";
/** Word for word the backend's TargetAgeRule.AGE_RANGE_TOO_NARROW. */
export const AGE_RANGE_TOO_NARROW_MESSAGE =
  `Их нас бага наснаас дор хаяж ${MIN_AGE_SPAN} жилээр их байх ёстой — ` +
  "цөөхөн хүнд чиглэсэн судалгаанаас хариулагч хэн болох нь танигдах эрсдэлтэй";

/** Why the age range cannot be used, or null when it can. */
export function ageRangeError(minAge: number, maxAge: number): string | null {
  if (minAge < MIN_TARGET_AGE || maxAge > MAX_TARGET_AGE || minAge > maxAge) {
    return AGE_OUT_OF_RANGE_MESSAGE;
  }
  if (maxAge - minAge < MIN_AGE_SPAN) return AGE_RANGE_TOO_NARROW_MESSAGE;
  return null;
}
