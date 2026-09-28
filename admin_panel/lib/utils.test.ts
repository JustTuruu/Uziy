import { describe, expect, it } from "vitest";
import { cn, formatDate, formatNumber, formatTugrik, relativeTime } from "./utils";

describe("cn", () => {
  it("joins truthy classNames", () => {
    expect(cn("a", "b")).toBe("a b");
  });

  it("skips falsy values", () => {
    expect(cn("a", false, null, undefined, "b")).toBe("a b");
  });

  it("dedupes and lets later Tailwind classes override earlier ones", () => {
    // twMerge behavior — the last conflicting utility wins.
    expect(cn("p-2", "p-4")).toBe("p-4");
  });
});

describe("formatTugrik", () => {
  it("appends the ₮ symbol and separates thousands", () => {
    const formatted = formatTugrik(1_500_000);
    expect(formatted).toMatch(/₮$/);
    expect(formatted.replace(/[\s, ]/g, "")).toContain("1500000");
  });

  it("rounds to whole ₮", () => {
    expect(formatTugrik(700.5)).toMatch(/701\s*₮$/);
  });

  it("handles zero", () => {
    expect(formatTugrik(0)).toMatch(/^0\s*₮$/);
  });
});

describe("formatNumber", () => {
  it("groups thousands using the mn-MN locale", () => {
    const s = formatNumber(1_234_567);
    // The specific separator (comma / space / nbsp) can vary by ICU
    // version, so assert on the digit sequence only.
    expect(s.replace(/[^\d]/g, "")).toBe("1234567");
  });
});

describe("formatDate", () => {
  it("returns YYYY-formatted date for a real date", () => {
    const s = formatDate("2026-09-28T00:00:00Z");
    // mn-MN locale renders differently depending on ICU, so just check
    // that the year and day appear.
    expect(s).toMatch(/2026/);
    expect(s).toMatch(/28/);
  });
});

describe("relativeTime", () => {
  it("returns 'яг одоо' for a timestamp less than a minute ago", () => {
    expect(relativeTime(new Date())).toBe("яг одоо");
  });

  it("returns a minute-count for a few minutes ago", () => {
    const t = new Date(Date.now() - 5 * 60_000);
    expect(relativeTime(t)).toBe("5 мин");
  });

  it("returns hours for a few hours ago", () => {
    const t = new Date(Date.now() - 3 * 60 * 60_000);
    expect(relativeTime(t)).toBe("3 цаг");
  });

  it("returns days for a few days ago", () => {
    const t = new Date(Date.now() - 2 * 24 * 60 * 60_000);
    expect(relativeTime(t)).toBe("2 өдөр");
  });

  it("falls back to a formatted date for older timestamps", () => {
    const t = new Date(Date.now() - 30 * 24 * 60 * 60_000);
    expect(relativeTime(t)).toMatch(/\d{4}/); // contains a year
  });
});
