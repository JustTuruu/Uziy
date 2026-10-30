import type { SelectOption } from "@uziy/ui";
import { CITIES, EVERYWHERE_LABEL } from "@uziy/ui/regions";
import type { AdminUser } from "@admin/lib/api";

/**
 * The users page's filters (owner, 2026-10-22): the admin types only the
 * phone number; the place and the company are picked from ready lists. Every
 * filter narrows the list further (AND).
 */

export type VerificationFilter = "ALL" | "VERIFIED" | "UNVERIFIED";

/** Value of the "no narrowing" option in the city and company pickers. */
export const ANY = "ALL";

export const ALL_COMPANIES_LABEL = "Бүх компани";

/** Mongolia's country code — a pasted "+976 8811 2233" still finds the user. */
const COUNTRY_CODE = "976";
const NATIONAL_NUMBER_LENGTH = 8;

export interface UserFilters {
  verification: VerificationFilter;
  /** Digits of the phone number, typed freely (spaces, dashes, +976 allowed). */
  phone: string;
  /** A city name from the list, or [ANY]. */
  city: string;
  /** A company account's id as a string, or [ANY]. */
  companyId: string;
}

export const NO_USER_FILTERS: UserFilters = {
  verification: "ALL",
  phone: "",
  city: ANY,
  companyId: ANY,
};

/** True when any filter differs from [NO_USER_FILTERS]. */
export function hasActiveFilters(filters: UserFilters): boolean {
  return (
    filters.verification !== NO_USER_FILTERS.verification ||
    phoneDigits(filters.phone) !== "" ||
    filters.city !== ANY ||
    filters.companyId !== ANY
  );
}

/** The digits worth matching: separators and a leading +976 are dropped. */
export function phoneDigits(input: string): string {
  const digits = input.replace(/\D/g, "");
  return digits.length > NATIONAL_NUMBER_LENGTH && digits.startsWith(COUNTRY_CODE)
    ? digits.slice(COUNTRY_CODE.length)
    : digits;
}

export function filterUsers(
  users: readonly AdminUser[],
  filters: UserFilters,
): AdminUser[] {
  const digits = phoneDigits(filters.phone);
  return users.filter(
    (u) =>
      matchesVerification(u, filters.verification) &&
      (digits === "" || u.phoneNumber.includes(digits)) &&
      (filters.city === ANY || u.city === filters.city) &&
      (filters.companyId === ANY || String(u.id) === filters.companyId),
  );
}

function matchesVerification(u: AdminUser, filter: VerificationFilter) {
  if (filter === "VERIFIED") return u.isVerified;
  if (filter === "UNVERIFIED") return !u.isVerified;
  return true;
}

/**
 * 'Бүх аймаг, хот', the capital, the 21 aimags, then any older value found in
 * the loaded users that is not on the official list (e.g. 'Бусад'), so those
 * users stay findable.
 */
export function cityOptions(users: readonly AdminUser[]): SelectOption[] {
  const listed = new Set(CITIES);
  const unlisted = [
    ...new Set(
      users
        .map((u) => u.city?.trim())
        .filter((c): c is string => !!c && !listed.has(c)),
    ),
  ].sort(byMongolianName);
  return [
    { value: ANY, label: EVERYWHERE_LABEL },
    ...[...CITIES, ...unlisted].map((city) => ({ value: city, label: city })),
  ];
}

/** 'Бүх компани', then every company account by name (phone when unnamed). */
export function companyOptions(users: readonly AdminUser[]): SelectOption[] {
  const companies = users
    .filter((u) => u.role === "COMPANY")
    .map((u) => ({ value: String(u.id), label: u.companyName?.trim() || u.phoneNumber }))
    .sort((a, b) => byMongolianName(a.label, b.label));
  return [{ value: ANY, label: ALL_COMPANIES_LABEL }, ...companies];
}

function byMongolianName(a: string, b: string) {
  return a.localeCompare(b, "mn", { sensitivity: "base" });
}

/** Card title: the total, or "found / total" while a filter narrows the list. */
export function resultCountLabel(shown: number, total: number, active: boolean) {
  return active ? `Олдсон: ${shown} / ${total}` : `Нийт: ${total}`;
}
