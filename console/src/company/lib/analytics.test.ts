import { describe, expect, it } from "vitest";
import type { AnalyticsReport, CampaignPerformance } from "./api";
import {
  audienceBase,
  axisTicks,
  buildInsights,
  dailyPoints,
  segmentTint,
  weekOverWeek,
  formatPercent,
  genderLabel,
  labelIndexes,
  niceCeil,
  peakDay,
  share,
  shortDate,
  sliceTotal,
} from "./analytics";

describe("genderLabel", () => {
  it("translates the two genders", () => {
    expect(genderLabel("MALE")).toBe("Эрэгтэй");
    expect(genderLabel("FEMALE")).toBe("Эмэгтэй");
  });
  it("shows an unknown value as it came", () => {
    expect(genderLabel("OTHER")).toBe("OTHER");
  });
});

describe("share", () => {
  it("is a whole-number percentage", () => {
    expect(share(1, 3)).toBe(33);
    expect(share(2, 3)).toBe(67);
    expect(share(5, 5)).toBe(100);
  });
  it("is 0 when there is nothing to share", () => {
    expect(share(0, 0)).toBe(0);
    expect(share(3, 0)).toBe(0);
    expect(share(3, -1)).toBe(0);
  });
});

describe("sliceTotal", () => {
  it("adds the counts", () => {
    expect(sliceTotal([{ label: "a", count: 2 }, { label: "b", count: 5 }])).toBe(7);
    expect(sliceTotal([])).toBe(0);
  });
});

describe("formatPercent", () => {
  it("keeps one decimal below ten", () => {
    expect(formatPercent(4.26)).toBe("4.3%");
    expect(formatPercent(0)).toBe("0%");
  });
  it("rounds to whole numbers from ten up", () => {
    expect(formatPercent(37.4)).toBe("37%");
    expect(formatPercent(100)).toBe("100%");
  });
});

describe("niceCeil", () => {
  it("rounds up to 1, 2 or 5 times a power of ten", () => {
    expect(niceCeil(1)).toBe(1);
    expect(niceCeil(3)).toBe(5);
    expect(niceCeil(6)).toBe(10);
    expect(niceCeil(11)).toBe(20);
    expect(niceCeil(37)).toBe(50);
    expect(niceCeil(51)).toBe(100);
    expect(niceCeil(1234)).toBe(2000);
  });
  it("leaves an exact round number alone", () => {
    expect(niceCeil(50)).toBe(50);
    expect(niceCeil(10)).toBe(10);
  });
  it("gives 1 for nothing", () => {
    expect(niceCeil(0)).toBe(1);
    expect(niceCeil(-4)).toBe(1);
  });
});

describe("axisTicks", () => {
  it("spaces gridlines evenly from 0 to the top", () => {
    expect(axisTicks(100)).toEqual([0, 25, 50, 75, 100]);
    expect(axisTicks(10, 2)).toEqual([0, 5, 10]);
  });
});

describe("shortDate", () => {
  it("is month.day", () => {
    expect(shortDate("2026-10-07")).toBe("10.07");
  });
});

describe("labelIndexes", () => {
  it("labels every point of a short series", () => {
    expect(labelIndexes(4)).toEqual([0, 1, 2, 3]);
  });
  it("spreads a long series, first and last included, never more than the cap", () => {
    const idx = labelIndexes(30, 6);
    expect(idx).toHaveLength(6);
    expect(idx[0]).toBe(0);
    expect(idx.at(-1)).toBe(29);
  });
  it("is empty for no points", () => {
    expect(labelIndexes(0)).toEqual([]);
  });
});

describe("peakDay", () => {
  it("finds the busiest day", () => {
    const daily = [
      { date: "2026-10-05", responses: 2 },
      { date: "2026-10-06", responses: 9 },
      { date: "2026-10-07", responses: 4 },
    ];
    expect(peakDay(daily)).toEqual({ date: "2026-10-06", responses: 9 });
  });
  it("is null when every day is empty", () => {
    expect(peakDay([{ date: "2026-10-05", responses: 0 }])).toBeNull();
    expect(peakDay([])).toBeNull();
  });
});

describe("dailyPoints", () => {
  it("maps the daily series to labelled points", () => {
    expect(dailyPoints([{ date: "2026-10-07", responses: 3 }])).toEqual([
      { key: "2026-10-07", label: "10.07", value: 3 },
    ]);
  });
});

describe("weekOverWeek", () => {
  const days = (counts: number[]) =>
    counts.map((responses, i) => ({ date: `2026-10-${String(i + 1).padStart(2, "0")}`, responses }));

  it("compares the latest seven days with the seven before", () => {
    expect(weekOverWeek(days([...Array(7).fill(2), ...Array(7).fill(3)]))).toBe(50);
    expect(weekOverWeek(days([...Array(7).fill(4), ...Array(7).fill(2)]))).toBe(-50);
  });

  it("is null for a short series or an empty earlier week", () => {
    expect(weekOverWeek(days(Array(10).fill(1)))).toBeNull();
    expect(weekOverWeek(days([...Array(7).fill(0), ...Array(7).fill(3)]))).toBeNull();
  });
});

describe("buildInsights", () => {
  function campaign(over: Partial<CampaignPerformance> = {}): CampaignPerformance {
    return {
      campaignId: 1,
      title: "Шинэ 5G багц",
      status: "ACTIVE",
      hasVideo: true,
      targetViewers: 10,
      responses: 10,
      reachPercent: 100,
      spent: 10_000,
      rewardsPaid: 7_000,
      costPerResponse: 1_000,
      remainingResponses: 40,
      responsesLast7Days: 10,
      daysLeft: 28,
      ...over,
    };
  }

  function report(over: Partial<AnalyticsReport> = {}): AnalyticsReport {
    return {
      days: 30,
      totals: {
        campaignCount: 1,
        activeCount: 1,
        responses: 12,
        rewardsPaid: 0,
        spent: 0,
        costPerResponse: null,
      },
      campaigns: [campaign()],
      daily: [],
      audience: null,
      questions: [],
      segments: [],
      ...over,
    };
  }

  /** Companies said the hour of day is not relevant to them (owner, 2026-10-22). */
  it("never talks about the hour of day", () => {
    const busy = Array.from({ length: 14 }, (_, i) => ({
      date: `2026-10-${String(i + 1).padStart(2, "0")}`,
      responses: 20,
    }));
    const texts = buildInsights(report({ daily: busy }), null).map((i) => i.text);
    expect(texts.length).toBeGreaterThan(0);
    expect(texts.join(" ")).not.toMatch(/цагт|\d{2}:00/);
  });

  it("reports the week-over-week change with the right tone", () => {
    const daily = (a: number, b: number) =>
      [...Array(7).fill(a), ...Array(7).fill(b)].map((responses, i) => ({
        date: `2026-10-${String(i + 1).padStart(2, "0")}`,
        responses,
      }));
    const up = buildInsights(report({ daily: daily(2, 3) }), null).find((i) => i.tone === "success");
    const down = buildInsights(report({ daily: daily(4, 2) }), null).find((i) => i.text.includes("цөөн"));
    expect(up?.text).toContain("50%");
    expect(down?.tone).toBe("warning");
  });

  it("warns when a running budget will be gone within a week", () => {
    const out = buildInsights(report({ campaigns: [campaign({ daysLeft: 3, remainingResponses: 6 })] }), null);
    const warning = out.find((i) => i.tone === "warning");
    expect(warning?.text).toContain("3 хоногт бюджет дуусна");
    expect(warning?.text).toContain("6 хариулт");
  });

  it("does not warn about a budget that lasts longer", () => {
    expect(
      buildInsights(report({ campaigns: [campaign({ daysLeft: 30 })] }), null).some(
        (i) => i.text.includes("бюджет дуусна"),
      ),
    ).toBe(false);
  });

  it("only talks about the selected campaign", () => {
    const campaigns = [
      campaign({ campaignId: 1, title: "A", daysLeft: 2 }),
      campaign({ campaignId: 2, title: "B", daysLeft: 2 }),
    ];
    const text = buildInsights(report({ campaigns }), 2).map((i) => i.text).join(" ");
    expect(text).toContain("B:");
    expect(text).not.toContain("A:");
  });

  it("compares the cheapest and the dearest answers", () => {
    const campaigns = [
      campaign({ campaignId: 1, title: "A", costPerResponse: 800 }),
      campaign({ campaignId: 2, title: "B", costPerResponse: 1500 }),
    ];
    const text = buildInsights(report({ campaigns }), null).map((i) => i.text).join(" ");
    expect(text).toContain("Хамгийн хямд хариулт: A");
    expect(text).toContain("Хамгийн үнэтэй нь: B");
  });

  it("does not compare prices without two well-sampled campaigns", () => {
    const campaigns = [
      campaign({ campaignId: 1, costPerResponse: 800 }),
      campaign({ campaignId: 2, costPerResponse: 1500, responses: 1 }),
    ];
    expect(
      buildInsights(report({ campaigns }), null).some((i) => i.text.includes("Хамгийн хямд")),
    ).toBe(false);
  });

  it("flags a running campaign that got nothing this week", () => {
    const out = buildInsights(
      report({ campaigns: [campaign({ responsesLast7Days: 0, daysLeft: null })] }),
      null,
    );
    expect(out.some((i) => i.text.includes("хариулт ирээгүй"))).toBe(true);
  });

  it("does not flag a paused campaign for being quiet", () => {
    const out = buildInsights(
      report({ campaigns: [campaign({ status: "PAUSED", responsesLast7Days: 0, daysLeft: null })] }),
      null,
    );
    expect(out.some((i) => i.text.includes("хариулт ирээгүй"))).toBe(false);
  });
});

describe("segmentTint", () => {
  it("grows with the share up to the strongest tint", () => {
    expect(segmentTint(0)).toBe(0);
    expect(segmentTint(20)).toBe(11);
    expect(segmentTint(100)).toBe(55);
  });
  it("never leaves the 0..55 range", () => {
    expect(segmentTint(-10)).toBe(0);
    expect(segmentTint(250)).toBe(55);
  });
});

describe("audienceBase", () => {
  const report = { totals: { responses: 40 } } as Pick<AnalyticsReport, "totals">;

  it("takes shares of every response of the selection, hidden groups included", () => {
    expect(audienceBase(report, null)).toBe(40);
    expect(audienceBase(report, { responses: 12 })).toBe(12);
  });
});
