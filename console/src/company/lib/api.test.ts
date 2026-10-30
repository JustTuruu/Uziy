import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { auth } from "./api";

describe("companyApi — campaign creation, payment, status", () => {
  const originalFetch = globalThis.fetch;
  let calls: { url: string; init: RequestInit }[] = [];

  function respondWith(status: number, body: unknown) {
    calls = [];
    globalThis.fetch = vi.fn(async (url: RequestInfo | URL, init?: RequestInit) => {
      calls.push({ url: String(url), init: init ?? {} });
      return new Response(JSON.stringify(body), {
        status,
        headers: { "content-type": "application/json" },
      });
    }) as typeof fetch;
  }

  beforeEach(() => auth.setToken("company-tok"));
  afterEach(() => {
    globalThis.fetch = originalFetch;
    window.localStorage.clear();
  });

  const baseBody = {
    title: "Шинэ 5G багц",
    hasVideo: false,
    videoUrl: "",
    durationSeconds: 0,
    targetGender: "ALL" as const,
    minAge: 18,
    maxAge: 45,
    targetCity: "ALL",
    totalBudget: 1_000_000,
    questions: [
      { prompt: "Та 5G ашигладаг уу?", type: "TEXT" as const, options: [], required: true },
    ],
  };

  it("create() POSTs the budget + targetViewers and no costPerView", async () => {
    respondWith(200, { id: 7, status: "AWAITING_PAYMENT" });
    const { companyApi } = await import("./api");

    const res = await companyApi.create({ ...baseBody, targetViewers: 1_000 });

    expect(calls[0].url).toMatch(/\/company\/campaigns$/);
    expect(calls[0].init.method).toBe("POST");
    const sent = JSON.parse(calls[0].init.body as string);
    expect(sent.totalBudget).toBe(1_000_000);
    expect(sent.targetViewers).toBe(1_000);
    expect(sent).not.toHaveProperty("rewardPerUser");
    expect(sent).not.toHaveProperty("costPerView");
    expect(res.status).toBe("AWAITING_PAYMENT");
  });

  it("create() can drive pricing by rewardPerUser instead", async () => {
    respondWith(200, { id: 8 });
    const { companyApi } = await import("./api");

    await companyApi.create({ ...baseBody, rewardPerUser: 500 });

    const sent = JSON.parse(calls[0].init.body as string);
    expect(sent.rewardPerUser).toBe(500);
    expect(sent).not.toHaveProperty("targetViewers");
  });

  it("pay() POSTs /company/campaigns/{id}/pay with the auth header", async () => {
    respondWith(200, {
      campaign: { id: 42, status: "PENDING", paidAt: "2026-09-28T12:00:00Z" },
      payment: { id: 1, campaignId: 42, reference: "UZ-20260928-42", status: "PAID" },
    });
    const { companyApi } = await import("./api");

    const res = await companyApi.pay(42);

    expect(calls[0].url).toMatch(/\/company\/campaigns\/42\/pay$/);
    expect(calls[0].init.method).toBe("POST");
    expect(calls[0].init.body).toBeUndefined();
    expect((calls[0].init.headers as Record<string, string>).Authorization).toBe(
      "Bearer company-tok",
    );
    expect(res.campaign.status).toBe("PENDING");
    expect(res.payment.reference).toBe("UZ-20260928-42");
  });

  it("pay() surfaces the server's 409 message as an ApiError", async () => {
    respondWith(409, {
      message: "Энэ судалгааны төлбөр аль хэдийн төлөгдсөн эсвэл төлөх боломжгүй",
    });
    const { companyApi } = await import("./api");

    await expect(companyApi.pay(42)).rejects.toMatchObject({
      name: "ApiError",
      status: 409,
      message: "Энэ судалгааны төлбөр аль хэдийн төлөгдсөн эсвэл төлөх боломжгүй",
    });
  });

  it("payments() GETs /company/payments", async () => {
    respondWith(200, [{ id: 1, reference: "UZ-20260928-42", amount: 1_000_000 }]);
    const { companyApi } = await import("./api");

    const res = await companyApi.payments();

    expect(calls[0].url).toMatch(/\/company\/payments$/);
    expect(calls[0].init.method).toBe("GET");
    expect(res[0].reference).toBe("UZ-20260928-42");
  });

  it("setStatus() PATCHes the status as a query parameter", async () => {
    respondWith(200, { id: 5, status: "PAUSED" });
    const { companyApi } = await import("./api");

    await companyApi.setStatus(5, "PAUSED");

    expect(calls[0].url).toMatch(/\/company\/campaigns\/5\/status\?status=PAUSED$/);
    expect(calls[0].init.method).toBe("PATCH");
  });
});
