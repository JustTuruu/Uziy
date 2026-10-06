import { renderHook } from "@testing-library/react";
import { renderToString } from "react-dom/server";
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

  it("renders as signed-out on the server even when storage has a user", () => {
    // Hydration safety: the server snapshot must not depend on localStorage.
    auth.setUser(me);
    function Probe() {
      return <span>{useStoredUser()?.phoneNumber ?? "anon"}</span>;
    }
    expect(renderToString(<Probe />)).toContain("anon");
  });
});
