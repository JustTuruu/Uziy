import { describe, expect, it } from "vitest";
import { DEFAULT_COMPANY_PANEL_URL, resolveLinks } from "./links";

describe("resolveLinks", () => {
  it("has no store links and the local panel when nothing is configured", () => {
    expect(resolveLinks({})).toEqual({
      appStore: null,
      playStore: null,
      companyPanel: DEFAULT_COMPANY_PANEL_URL,
      contactEmail: null,
    });
  });

  it("uses the configured URLs", () => {
    expect(
      resolveLinks({
        NEXT_PUBLIC_APP_STORE_URL: "https://apps.apple.com/app/uziy",
        NEXT_PUBLIC_PLAY_STORE_URL: "https://play.google.com/store/apps/uziy",
        NEXT_PUBLIC_COMPANY_PANEL_URL: "https://company.uziy.mn",
        NEXT_PUBLIC_CONTACT_EMAIL: "hello@example.mn",
      }),
    ).toEqual({
      appStore: "https://apps.apple.com/app/uziy",
      playStore: "https://play.google.com/store/apps/uziy",
      companyPanel: "https://company.uziy.mn",
      contactEmail: "hello@example.mn",
    });
  });

  it("treats blank and whitespace-only values as not set", () => {
    const links = resolveLinks({
      NEXT_PUBLIC_APP_STORE_URL: "",
      NEXT_PUBLIC_PLAY_STORE_URL: "   ",
      NEXT_PUBLIC_COMPANY_PANEL_URL: " ",
      NEXT_PUBLIC_CONTACT_EMAIL: "  ",
    });
    expect(links.appStore).toBeNull();
    expect(links.playStore).toBeNull();
    expect(links.companyPanel).toBe(DEFAULT_COMPANY_PANEL_URL);
    expect(links.contactEmail).toBeNull();
  });
});
