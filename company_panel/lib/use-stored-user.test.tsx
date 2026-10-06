import { renderHook } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { auth, useStoredUser, type Me } from "./api";

const me: Me = {
  id: 1,
  phoneNumber: "99001122",
  role: "ADMIN",
  gender: null,
  age: null,
  city: null,
  balance: 0,
  isVerified: true,
  companyName: null,
};

describe("useStoredUser", () => {
  beforeEach(() => window.localStorage.clear());
  afterEach(() => window.localStorage.clear());

  it("is null when nobody is signed in", () => {
    expect(renderHook(() => useStoredUser()).result.current).toBeNull();
  });

  it("returns the stored user", () => {
    auth.setUser(me);
    expect(renderHook(() => useStoredUser()).result.current).toEqual(me);
  });

  it("ignores corrupt storage", () => {
    window.localStorage.setItem("uziy.user", "{not json");
    expect(renderHook(() => useStoredUser()).result.current).toBeNull();
  });
});
