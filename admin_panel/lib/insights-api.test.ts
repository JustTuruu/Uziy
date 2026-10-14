import { afterEach, expect, it, vi } from "vitest";
import { auth, insightFilterQuery, insightsApi } from "./api";

afterEach(() => {
  vi.unstubAllGlobals();
  localStorage.clear();
});

it("builds the query only from the filters that are set", () => {
  expect(insightFilterQuery({})).toBe("");
  expect(insightFilterQuery({ gender: null, ageBand: null, city: null })).toBe("");
  expect(insightFilterQuery({ gender: "FEMALE", ageBand: "25–34", city: "Дархан-Уул" })).toBe(
    "?gender=FEMALE&ageBand=25%E2%80%9334&city=%D0%94%D0%B0%D1%80%D1%85%D0%B0%D0%BD-%D0%A3%D1%83%D0%BB",
  );
});

it("asks for a filtered distribution with the admin's token", async () => {
  const fetch = vi.fn().mockResolvedValue(new Response(JSON.stringify({ suppressed: true })));
  vi.stubGlobal("fetch", fetch);
  auth.setToken("admin-token");

  await insightsApi.distribution(12, { gender: "MALE" });

  const [url, init] = fetch.mock.calls[0];
  expect(url).toContain("/admin/insights/questions/12?gender=MALE");
  expect(init.headers.Authorization).toBe("Bearer admin-token");
});

it("returns the CSV export as text, not parsed JSON", async () => {
  vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response("﻿\"Судалгаа\",\"X\"\r\n")));

  const csv = await insightsApi.exportCsv(12);

  expect(csv).toContain('"Судалгаа","X"');
});
