import { describe, expect, it } from "vitest";
import { AIMAGS, CAPITAL, EVERYWHERE_LABEL } from "@uziy/ui/regions";
import type { AdminUser } from "@/lib/api";
import {
  ALL_COMPANIES_LABEL,
  ANY,
  cityOptions,
  companyOptions,
  filterUsers,
  hasActiveFilters,
  NO_USER_FILTERS,
  phoneDigits,
  resultCountLabel,
  type UserFilters,
} from "./user-filters";

/** Builder for test users: a verified viewer in the capital unless overridden. */
function user(overrides: Partial<AdminUser>): AdminUser {
  return {
    id: 1,
    phoneNumber: "88112233",
    role: "VIEWER",
    gender: "MALE",
    age: 24,
    city: CAPITAL,
    balance: 3400,
    isVerified: true,
    companyName: null,
    createdAt: "2026-08-01T00:00:00Z",
    ...overrides,
  };
}

function company(id: number, name: string | null, phone = `9900000${id}`) {
  return user({
    id,
    role: "COMPANY",
    companyName: name,
    phoneNumber: phone,
    city: null,
    age: null,
    gender: null,
  });
}

const sample: AdminUser[] = [
  user({ id: 1, phoneNumber: "88112233", city: CAPITAL, isVerified: true }),
  user({ id: 2, phoneNumber: "99114455", city: "Дархан-Уул", isVerified: false }),
  user({ id: 3, phoneNumber: "88119900", city: "Дархан-Уул", isVerified: true }),
  user({ id: 4, phoneNumber: "95001122", city: "Бусад", isVerified: false }),
  company(5, "MobiCom", "88221199"),
  company(6, "Голомт банк", "70112233"),
];

const ids = (users: AdminUser[]) => users.map((u) => u.id);
const withFilters = (patch: Partial<UserFilters>) =>
  filterUsers(sample, { ...NO_USER_FILTERS, ...patch });

describe("filterUsers", () => {
  it("returns everyone with no filters", () => {
    expect(ids(withFilters({}))).toEqual([1, 2, 3, 4, 5, 6]);
  });

  it("keeps the verified / unverified split", () => {
    expect(ids(withFilters({ verification: "VERIFIED" }))).toEqual([1, 3, 5, 6]);
    expect(ids(withFilters({ verification: "UNVERIFIED" }))).toEqual([2, 4]);
  });

  it("finds a phone number by any part of it", () => {
    expect(ids(withFilters({ phone: "8811" }))).toEqual([1, 3]);
    expect(ids(withFilters({ phone: "2233" }))).toEqual([1, 6]);
  });

  it("ignores spaces, dashes and a +976 prefix in the typed phone", () => {
    expect(ids(withFilters({ phone: "8811-22 33" }))).toEqual([1]);
    expect(ids(withFilters({ phone: "+976 8811 2233" }))).toEqual([1]);
  });

  it("no longer matches a city or company typed into the phone box", () => {
    expect(withFilters({ phone: "MobiCom" })).toHaveLength(6);
    expect(withFilters({ phone: "Дархан" })).toHaveLength(6);
  });

  it("narrows to one city by its exact name", () => {
    expect(ids(withFilters({ city: "Дархан-Уул" }))).toEqual([2, 3]);
    expect(ids(withFilters({ city: "Бусад" }))).toEqual([4]);
  });

  it("narrows to the picked company account", () => {
    expect(ids(withFilters({ companyId: "6" }))).toEqual([6]);
  });

  it("combines every filter (AND)", () => {
    expect(
      ids(withFilters({ city: "Дархан-Уул", verification: "VERIFIED", phone: "8811" })),
    ).toEqual([3]);
    expect(ids(withFilters({ companyId: "5", phone: "8822" }))).toEqual([5]);
  });

  it("returns nothing when the filters exclude each other", () => {
    expect(withFilters({ companyId: "5", city: CAPITAL })).toEqual([]);
    expect(withFilters({ phone: "123456" })).toEqual([]);
    expect(filterUsers([], NO_USER_FILTERS)).toEqual([]);
  });
});

describe("phoneDigits", () => {
  it("keeps the digits and drops the country code only on a full number", () => {
    expect(phoneDigits(" 88-11 ")).toBe("8811");
    expect(phoneDigits("+97688112233")).toBe("88112233");
    expect(phoneDigits("9761")).toBe("9761");
    expect(phoneDigits("abc")).toBe("");
  });
});

describe("hasActiveFilters", () => {
  it("is false with no filters or a blank phone, true once anything is set", () => {
    expect(hasActiveFilters(NO_USER_FILTERS)).toBe(false);
    expect(hasActiveFilters({ ...NO_USER_FILTERS, phone: "  " })).toBe(false);
    expect(hasActiveFilters({ ...NO_USER_FILTERS, phone: "88" })).toBe(true);
    expect(hasActiveFilters({ ...NO_USER_FILTERS, city: CAPITAL })).toBe(true);
    expect(hasActiveFilters({ ...NO_USER_FILTERS, companyId: "5" })).toBe(true);
    expect(hasActiveFilters({ ...NO_USER_FILTERS, verification: "UNVERIFIED" })).toBe(true);
  });
});

describe("cityOptions", () => {
  it("offers every place, the capital and all 21 aimags even with no users", () => {
    const options = cityOptions([]);
    expect(options[0]).toEqual({ value: ANY, label: EVERYWHERE_LABEL });
    expect(options.slice(1).map((o) => o.value)).toEqual([CAPITAL, ...AIMAGS]);
  });

  it("adds older values found in the list once, after the official ones", () => {
    const options = cityOptions([
      ...sample,
      user({ id: 9, city: "Бусад" }),
      user({ id: 10, city: "Эрдэнэт" }),
    ]);
    expect(options).toHaveLength(1 + 1 + AIMAGS.length + 2);
    expect(options.slice(-2).map((o) => o.value)).toEqual(["Бусад", "Эрдэнэт"]);
  });
});

describe("companyOptions", () => {
  it("lists only company accounts, sorted by name (Mongolian order: Cyrillic first), after 'every company'", () => {
    const options = companyOptions([...sample, company(7, "Аз банк")]);
    expect(options).toEqual([
      { value: ANY, label: ALL_COMPANIES_LABEL },
      { value: "7", label: "Аз банк" },
      { value: "6", label: "Голомт банк" },
      { value: "5", label: "MobiCom" },
    ]);
  });

  it("names an unnamed company by its phone number", () => {
    expect(companyOptions([company(8, null, "77001100")])[1]).toEqual({
      value: "8",
      label: "77001100",
    });
  });

  it("has only 'every company' when there are no companies", () => {
    expect(companyOptions(sample.filter((u) => u.role !== "COMPANY"))).toEqual([
      { value: ANY, label: ALL_COMPANIES_LABEL },
    ]);
  });
});

describe("resultCountLabel", () => {
  it("shows the total, or found / total while filtering", () => {
    expect(resultCountLabel(6, 6, false)).toBe("Нийт: 6");
    expect(resultCountLabel(2, 6, true)).toBe("Олдсон: 2 / 6");
    expect(resultCountLabel(0, 6, true)).toBe("Олдсон: 0 / 6");
  });
});
