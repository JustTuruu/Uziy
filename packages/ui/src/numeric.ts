/**
 * Normalises raw text typed into a whole-number field: keeps digits only and
 * drops leading zeros ("007" → "7") while still allowing an empty field, so
 * the user can clear a value and type a new one without a "0" sticking to
 * the front. A lone "0" is kept.
 */
export function sanitizeIntInput(raw: string): string {
  return raw.replace(/\D/g, "").replace(/^0+(?=\d)/, "");
}

/** Parses a whole-number field's text; an empty field counts as 0. */
export function parseIntInput(text: string): number {
  const n = Number.parseInt(text, 10);
  return Number.isFinite(n) ? n : 0;
}
