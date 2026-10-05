import { describe, expect, it } from "vitest";
import {
  cn,
  formatDate,
  formatDuration,
  formatNumber,
  formatTugrik,
  parseIntInput,
  relativeTime,
  sanitizeIntInput,
} from "./utils";

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

describe("sanitizeIntInput", () => {
  it("allows an empty field so the user can clear the value", () => {
    expect(sanitizeIntInput("")).toBe("");
  });

  it("strips leading zeros left over after clearing and retyping", () => {
    expect(sanitizeIntInput("05")).toBe("5");
    expect(sanitizeIntInput("0025")).toBe("25");
    expect(sanitizeIntInput("0001000000")).toBe("1000000");
  });

  it("keeps a lone zero and zeros inside the number", () => {
    expect(sanitizeIntInput("0")).toBe("0");
    expect(sanitizeIntInput("000")).toBe("0");
    expect(sanitizeIntInput("1000")).toBe("1000");
  });

  it("drops non-digit characters (signs, decimals, separators, letters)", () => {
    expect(sanitizeIntInput("-12")).toBe("12");
    expect(sanitizeIntInput("1,000,000")).toBe("1000000");
    expect(sanitizeIntInput("12.5")).toBe("125");
    expect(sanitizeIntInput("1e5")).toBe("15");
    expect(sanitizeIntInput(" 45 ₮")).toBe("45");
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

describe("formatDuration", () => {
  it("formats seconds as m:ss", () => {
    expect(formatDuration(0)).toBe("0:00");
    expect(formatDuration(5)).toBe("0:05");
    expect(formatDuration(45)).toBe("0:45");
    expect(formatDuration(60)).toBe("1:00");
    expect(formatDuration(90)).toBe("1:30");
    expect(formatDuration(180)).toBe("3:00");
  });

  it("floors fractions and clamps negatives to zero", () => {
    expect(formatDuration(44.9)).toBe("0:44");
    expect(formatDuration(-3)).toBe("0:00");
  });
});
