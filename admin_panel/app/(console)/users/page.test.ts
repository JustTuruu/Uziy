import { describe, expect, it } from "vitest";
import type { AdminUser } from "@/lib/api";
import { filterUsers } from "./page";

function u(overrides: Partial<AdminUser>): AdminUser {
  return {
    id: 1,
    phoneNumber: "88112233",
    role: "VIEWER",
    gender: "MALE",
    age: 24,
    city: "Улаанбаатар",
    balance: 3400,
    isVerified: true,
    companyName: null,
    createdAt: "2026-08-01T00:00:00Z",
    ...overrides,
  };
}

const sample: AdminUser[] = [
  u({ id: 1, phoneNumber: "88112233", city: "Улаанбаатар", isVerified: true }),
  u({ id: 2, phoneNumber: "99114455", city: "Дархан", isVerified: false }),
  u({
    id: 3,
    phoneNumber: "88221199",
    role: "COMPANY",
    companyName: "MobiCom",
    isVerified: true,
    city: null,
    age: null,
    gender: null,
  }),
];

describe("filterUsers", () => {
  it("returns everything when filter=ALL and no query", () => {
    expect(filterUsers(sample, "ALL", "").length).toBe(3);
  });

  it("returns only verified when filter=VERIFIED", () => {
    const r = filterUsers(sample, "VERIFIED", "");
    expect(r.map((x) => x.id).sort()).toEqual([1, 3]);
  });

  it("returns only unverified when filter=UNVERIFIED", () => {
    const r = filterUsers(sample, "UNVERIFIED", "");
    expect(r.map((x) => x.id)).toEqual([2]);
  });

  it("matches by phone-number substring (case-insensitive)", () => {
    expect(filterUsers(sample, "ALL", "8811").map((u) => u.id)).toEqual([1]);
  });

  it("matches by city", () => {
    expect(filterUsers(sample, "ALL", "Дархан").map((u) => u.id)).toEqual([2]);
  });

  it("matches by company name", () => {
    expect(
      filterUsers(sample, "ALL", "mobicom").map((u) => u.id),
    ).toEqual([3]);
  });

  it("combines filter + query (verified + query)", () => {
    expect(
      filterUsers(sample, "VERIFIED", "8811").map((u) => u.id),
    ).toEqual([1]);
  });

  it("returns empty when query matches nothing", () => {
    expect(filterUsers(sample, "ALL", "no-match")).toEqual([]);
  });

  it("trims whitespace on the query", () => {
    expect(filterUsers(sample, "ALL", "   ").length).toBe(3);
  });
});
