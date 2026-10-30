import { describe, expect, it } from "vitest";
import type { Me } from "./api/types";
import { ADMIN_HOME, COMPANY_HOME, LOGIN_PATH, areaRedirect, homeFor } from "./session";

const user = (role: Me["role"]): Me => ({
  id: 1,
  phoneNumber: "99112233",
  role,
  gender: null,
  age: null,
  city: null,
  district: null,
  balance: 0,
  isVerified: true,
  companyName: role === "COMPANY" ? "MobiCom" : null,
  lastName: null,
  firstName: null,
});

describe("homeFor", () => {
  it("sends companies to the root and admins under /admin", () => {
    expect(homeFor("COMPANY")).toBe(COMPANY_HOME);
    expect(homeFor("ADMIN")).toBe(ADMIN_HOME);
    expect(homeFor("VIEWER")).toBe(LOGIN_PATH);
  });
});

describe("areaRedirect", () => {
  it("lets an account into its own area", () => {
    expect(areaRedirect("COMPANY", "t", user("COMPANY"))).toBeNull();
    expect(areaRedirect("ADMIN", "t", user("ADMIN"))).toBeNull();
  });

  it("asks for a sign-in without a token or a stored user", () => {
    expect(areaRedirect("COMPANY", null, user("COMPANY"))).toBe(LOGIN_PATH);
    expect(areaRedirect("ADMIN", "t", null)).toBe(LOGIN_PATH);
  });

  it("sends an account of the other area to its own home", () => {
    expect(areaRedirect("ADMIN", "t", user("COMPANY"))).toBe(COMPANY_HOME);
    expect(areaRedirect("COMPANY", "t", user("ADMIN"))).toBe(ADMIN_HOME);
    expect(areaRedirect("COMPANY", "t", user("VIEWER"))).toBe(LOGIN_PATH);
  });
});
