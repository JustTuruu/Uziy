import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ApiError, auth, companyApi, type Campaign } from "@/lib/api";
import CampaignDetailPage from "./page";

const router = { replace: vi.fn(), push: vi.fn(), refresh: vi.fn() };
const params = { id: "42" };
vi.mock("next/navigation", () => ({
  useRouter: () => router,
  useParams: () => params,
}));

function campaign(over: Partial<Campaign> = {}): Campaign {
  return {
    id: 42,
    title: "Шинэ 5G багц",
    videoUrl: "",
    durationSeconds: 30,
    hasVideo: true,
    targetGender: "ALL",
    minAge: 18,
    maxAge: 45,
    targetCity: "ALL",
    totalBudget: 1_000_000,
    remainingBudget: 1_000_000,
    costPerView: 1_000,
    rewardPerUser: 700,
    targetViewers: 1_000,
    commissionPercent: 30,
    paidAt: null,
    status: "ACTIVE",
    createdAt: "2026-09-28T10:00:00Z",
    ...over,
  };
}

beforeEach(() => {
  vi.spyOn(auth, "getToken").mockReturnValue("company-tok");
});
afterEach(() => vi.restoreAllMocks());

describe("Company campaign detail", () => {
  it("shows the payment card for an unpaid campaign and no status controls", async () => {
    vi.spyOn(companyApi, "get").mockResolvedValue(campaign({ status: "AWAITING_PAYMENT" }));
    render(<CampaignDetailPage />);
    expect(await screen.findByRole("button", { name: "Төлөх" })).toBeInTheDocument();
    expect(screen.getAllByText("Төлбөр хүлээгдэж буй").length).toBeGreaterThan(0);
    expect(screen.queryByRole("button", { name: /Түр зогсоох/ })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Үргэлжлүүлэх/ })).not.toBeInTheDocument();
  });

  it("after paying, flips to PENDING and keeps the success message", async () => {
    vi.spyOn(companyApi, "get").mockResolvedValue(campaign({ status: "AWAITING_PAYMENT" }));
    vi.spyOn(companyApi, "pay").mockResolvedValue({
      campaign: campaign({ status: "PENDING", paidAt: "2026-09-28T10:05:00Z" }),
      payment: {
        id: 1,
        campaignId: 42,
        campaignTitle: "Шинэ 5G багц",
        amount: 1_000_000,
        provider: "SIMULATED",
        status: "PAID",
        reference: "UZ-20260928-42",
        createdAt: "2026-09-28T10:05:00Z",
        paidAt: "2026-09-28T10:05:00Z",
      },
    });
    render(<CampaignDetailPage />);
    await userEvent.click(await screen.findByRole("button", { name: "Төлөх" }));
    expect(await screen.findByText("Төлбөр амжилттай төлөгдлөө")).toBeInTheDocument();
    expect(screen.getByText("Хянагдаж буй")).toBeInTheDocument();
  });

  it("a PENDING (paid) campaign cannot be activated by the company", async () => {
    vi.spyOn(companyApi, "get").mockResolvedValue(
      campaign({ status: "PENDING", paidAt: "2026-09-28T10:05:00Z" }),
    );
    render(<CampaignDetailPage />);
    expect(await screen.findByText(/Админ шалгаж баталгаажуулсны дараа/)).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Үргэлжлүүлэх/ })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Дуусгах/ })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Төлөх" })).not.toBeInTheDocument();
  });

  it("ACTIVE offers pause and complete", async () => {
    vi.spyOn(companyApi, "get").mockResolvedValue(campaign({ status: "ACTIVE" }));
    const setStatus = vi
      .spyOn(companyApi, "setStatus")
      .mockResolvedValue(campaign({ status: "PAUSED" }));
    render(<CampaignDetailPage />);

    await userEvent.click(await screen.findByRole("button", { name: /Түр зогсоох/ }));
    expect(setStatus).toHaveBeenCalledWith(42, "PAUSED");
    expect(await screen.findByRole("button", { name: /Үргэлжлүүлэх/ })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Дуусгах/ })).toBeInTheDocument();
  });

  it("asks for confirmation before completing and shows a 409 inline", async () => {
    vi.spyOn(companyApi, "get").mockResolvedValue(campaign({ status: "PAUSED" }));
    const setStatus = vi
      .spyOn(companyApi, "setStatus")
      .mockRejectedValue(new ApiError("Энэ төлөвөөс шилжих боломжгүй", 409, null));
    // happy-dom has no window.confirm; install a stub for this test.
    const confirm = vi.fn().mockReturnValueOnce(false).mockReturnValueOnce(true);
    Object.defineProperty(window, "confirm", {
      value: confirm,
      configurable: true,
      writable: true,
    });
    render(<CampaignDetailPage />);

    const complete = await screen.findByRole("button", { name: /Дуусгах/ });
    await userEvent.click(complete);
    expect(setStatus).not.toHaveBeenCalled();

    await userEvent.click(complete);
    expect(confirm).toHaveBeenCalledTimes(2);
    expect(setStatus).toHaveBeenCalledWith(42, "COMPLETED");
    expect(await screen.findByRole("alert")).toHaveTextContent("Энэ төлөвөөс шилжих боломжгүй");
    // The campaign stays on screen.
    expect(screen.getByText("Шинэ 5G багц")).toBeInTheDocument();
  });
});
