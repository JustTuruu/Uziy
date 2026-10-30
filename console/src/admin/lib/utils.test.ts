import { describe, expect, it } from "vitest";
import {
  formatDate,
  formatNumber,
  formatPhone,
  formatTugrik,
  parseIntInput,
  relativeTime,
} from "./utils";

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

  it("adds 'өмнө' (ago) so short forms aren't ambiguous", () => {
    const t = new Date(Date.now() - 5 * 60_000);
    expect(relativeTime(t)).toBe("5 мин өмнө");
  });

  it("uses 'цагийн өмнө' for hour-range timestamps", () => {
    const t = new Date(Date.now() - 3 * 60 * 60_000);
    expect(relativeTime(t)).toBe("3 цагийн өмнө");
  });

  it("uses 'өдрийн өмнө' for day-range timestamps", () => {
    const t = new Date(Date.now() - 2 * 24 * 60 * 60_000);
    expect(relativeTime(t)).toBe("2 өдрийн өмнө");
  });

  it("falls back to a formatted date for timestamps older than a week", () => {
    const t = new Date(Date.now() - 30 * 24 * 60 * 60_000);
    expect(relativeTime(t)).toMatch(/\d{4}/); // contains a year
  });

  it("prints an absolute date for future timestamps (no negative 'өмнө')", () => {
    const t = new Date(Date.now() + 10 * 60_000); // 10 min in the future
    expect(relativeTime(t)).toMatch(/\d{4}/);
    expect(relativeTime(t)).not.toContain("өмнө");
  });
});

describe("parseIntInput", () => {
  it("parses digits", () => {
    expect(parseIntInput("45")).toBe(45);
    expect(parseIntInput("1000000")).toBe(1_000_000);
  });

  it("treats an empty field as 0", () => {
    expect(parseIntInput("")).toBe(0);
  });
});

describe("formatPhone", () => {
  it("groups 8-digit numbers as 4 + 4", () => {
    expect(formatPhone("99001122")).toBe("9900 1122");
  });
  it("leaves other lengths untouched", () => {
    expect(formatPhone("123")).toBe("123");
    expect(formatPhone("")).toBe("");
  });
});
