import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  ApiError,
  analyticsApi,
  auth,
  companyApi,
  type AnalyticsReport,
  type Campaign,
} from "@company/lib/api";
import { MAX_DAYS } from "@company/lib/analytics";
import CampaignDetailPage from "./campaign-detail-page";

const router = { replace: vi.fn(), push: vi.fn(), refresh: vi.fn() };
const params = { id: "42" };
vi.mock("@shared/navigation", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@shared/navigation")>()),
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
    thumbnailUrl: null,
    ...over,
  };
}

function report(over: Partial<AnalyticsReport> = {}): AnalyticsReport {
  return {
    days: MAX_DAYS,
    totals: { campaignCount: 1, activeCount: 1, responses: 0, rewardsPaid: 0, spent: 0, costPerResponse: null },
    campaigns: [],
    daily: [],
    audience: null,
    questions: [],
    segments: [],
    ...over,
  };
}

/** 20 answerers: 8 men, 12 women; 9 aged 18–24, 6 aged 25–34 (5 more hidden, too few in their bands). */
const answered = report({
  questions: [
    {
      questionId: 1,
      prompt: "Багц таалагдсан уу?",
      type: "SINGLE_CHOICE",
      answered: 20,
      options: [
        { label: "Үгүй", count: 6 },
        { label: "Тийм", count: 14 },
      ],
    },
    {
      questionId: 2,
      prompt: "Үнэ ямар санагдсан бэ?",
      type: "RATING",
      answered: 20,
      options: [
        { label: "Маш муу", count: 1 },
        { label: "Муу", count: 2 },
        { label: "Дунд", count: 9 },
        { label: "Сайн", count: 6 },
        { label: "Маш сайн", count: 2 },
      ],
    },
    { questionId: 3, prompt: "Санал хүсэлт", type: "TEXT", answered: 12, options: [] },
  ],
  segments: [
    {
      questionId: 1,
      prompt: "Багц таалагдсан уу?",
      segments: [
        { label: "MALE", count: 8 },
        { label: "FEMALE", count: 12 },
        { label: "18–24", count: 9 },
        { label: "25–34", count: 6 },
      ],
      options: [
        { label: "Үгүй", counts: [4, 2, 1, 3] },
        { label: "Тийм", counts: [4, 10, 8, 3] },
      ],
    },
  ],
});

beforeEach(() => {
  vi.spyOn(auth, "getToken").mockReturnValue("company-tok");
  vi.spyOn(analyticsApi, "get").mockResolvedValue(report());
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

  it("asks in an in-app dialog before completing and shows a 409 inline", async () => {
    vi.spyOn(companyApi, "get").mockResolvedValue(campaign({ status: "PAUSED" }));
    const setStatus = vi
      .spyOn(companyApi, "setStatus")
      .mockRejectedValue(new ApiError("Энэ төлөвөөс шилжих боломжгүй", 409, null));
    const nativeConfirm = vi.fn();
    Object.defineProperty(window, "confirm", { value: nativeConfirm, configurable: true, writable: true });
    render(<CampaignDetailPage />);

    const complete = await screen.findByRole("button", { name: /Дуусгах/ });
    await userEvent.click(complete);
    const dialog = screen.getByRole("alertdialog", { name: "Судалгааг дуусгах уу?" });
    expect(dialog).toHaveAccessibleDescription("Дууссан судалгааг дахин идэвхжүүлэх боломжгүй.");
    await userEvent.click(within(dialog).getByRole("button", { name: "Болих" }));
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
    expect(setStatus).not.toHaveBeenCalled();

    await userEvent.click(complete);
    await userEvent.click(
      within(screen.getByRole("alertdialog")).getByRole("button", { name: "Дуусгах" }),
    );
    expect(nativeConfirm).not.toHaveBeenCalled();
    expect(setStatus).toHaveBeenCalledWith(42, "COMPLETED");
    expect(await screen.findByRole("alert")).toHaveTextContent("Энэ төлөвөөс шилжих боломжгүй");
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
    // The campaign stays on screen.
    expect(screen.getByText("Шинэ 5G багц")).toBeInTheDocument();
  });

  it("completes the campaign once the dialog is confirmed", async () => {
    vi.spyOn(companyApi, "get").mockResolvedValue(campaign({ status: "ACTIVE" }));
    const setStatus = vi
      .spyOn(companyApi, "setStatus")
      .mockResolvedValue(campaign({ status: "COMPLETED" }));
    render(<CampaignDetailPage />);

    await userEvent.click(await screen.findByRole("button", { name: /Дуусгах/ }));
    await userEvent.click(within(screen.getByRole("alertdialog")).getByRole("button", { name: "Дуусгах" }));

    expect(setStatus).toHaveBeenCalledWith(42, "COMPLETED");
    expect(await screen.findAllByText("Дууссан")).not.toHaveLength(0);
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
  });
});

describe("Company campaign detail — survey results", () => {
  it("loads this campaign's whole-life results", async () => {
    vi.spyOn(companyApi, "get").mockResolvedValue(campaign());
    const get = vi.spyOn(analyticsApi, "get").mockResolvedValue(answered);
    render(<CampaignDetailPage />);

    expect(await screen.findByText("Багц таалагдсан уу?")).toBeInTheDocument();
    expect(get).toHaveBeenCalledWith({ days: MAX_DAYS, campaignId: 42 });
    expect(screen.getByText("Судалгаа эхэлснээс хойшхи бүх хариулт")).toBeInTheDocument();
    expect(screen.queryByText(/agregate|агрегатор/)).not.toBeInTheDocument();
  });

  it("shows a loading placeholder first", async () => {
    vi.spyOn(companyApi, "get").mockResolvedValue(campaign());
    vi.spyOn(analyticsApi, "get").mockReturnValue(new Promise(() => {}));
    render(<CampaignDetailPage />);

    expect(await screen.findByRole("status", { name: "Хариултуудыг ачаалж байна..." })).toBeInTheDocument();
  });

  it("ranks choice answers by count and keeps a rating on its scale", async () => {
    vi.spyOn(companyApi, "get").mockResolvedValue(campaign());
    vi.spyOn(analyticsApi, "get").mockResolvedValue(answered);
    render(<CampaignDetailPage />);

    const choice = await screen.findByRole("region", { name: "Багц таалагдсан уу?" });
    const choiceRows = within(choice).getAllByRole("listitem").map((li) => li.textContent);
    expect(choiceRows[0]).toContain("Тийм");
    expect(choiceRows[0]).toContain("14 · 70%");
    expect(choiceRows[1]).toContain("Үгүй");

    const rating = screen.getByRole("region", { name: "Үнэ ямар санагдсан бэ?" });
    const ratingRows = within(rating).getAllByRole("listitem").map((li) => li.textContent ?? "");
    expect(ratingRows.map((t) => t.replace(/\d.*$/, ""))).toEqual(["Маш муу", "Муу", "Дунд", "Сайн", "Маш сайн"]);
  });

  it("shows who answered what by gender and age, and says small groups are hidden", async () => {
    vi.spyOn(companyApi, "get").mockResolvedValue(campaign());
    vi.spyOn(analyticsApi, "get").mockResolvedValue(answered);
    render(<CampaignDetailPage />);

    const table = await screen.findByRole("table", { name: /Багц таалагдсан уу\?/ });
    const yes = within(table).getByRole("row", { name: /Тийм/ });
    expect(within(yes).getAllByRole("cell").map((c) => c.textContent)).toEqual(["50%", "83%", "89%", "50%"]);
    expect(screen.getAllByText("Хэн юу гэж хариулсан").length).toBeGreaterThan(0);
    // Question 1: some age bands left out; question 2 (the rating): every group too small to send.
    expect(screen.getAllByText(/5-аас цөөн хүнтэй бүлгийг нууцлалын үүднээс харуулахгүй/)).toHaveLength(2);
    expect(screen.getByText(/Бүлэг тус бүрээр харуулахад хариулт хүрэлцэхгүй/)).toBeInTheDocument();
  });

  it("never shows written answers", async () => {
    vi.spyOn(companyApi, "get").mockResolvedValue(campaign());
    vi.spyOn(analyticsApi, "get").mockResolvedValue(answered);
    render(<CampaignDetailPage />);

    expect(await screen.findByText("Санал хүсэлт")).toBeInTheDocument();
    expect(
      screen.getByText("Бичгээр өгсөн хариултыг хариулагчдын нууцлалын үүднээс харуулахгүй."),
    ).toBeInTheDocument();
  });

  it("says so when nobody has answered yet", async () => {
    vi.spyOn(companyApi, "get").mockResolvedValue(campaign());
    vi.spyOn(analyticsApi, "get").mockResolvedValue(
      report({
        questions: [{ questionId: 1, prompt: "Таалагдсан уу?", type: "SINGLE_CHOICE", answered: 0, options: [] }],
      }),
    );
    render(<CampaignDetailPage />);

    expect(await screen.findByText(/Хариулт хараахан ирээгүй байна/)).toBeInTheDocument();
  });

  it("offers a retry after a failure", async () => {
    vi.spyOn(companyApi, "get").mockResolvedValue(campaign());
    const get = vi
      .spyOn(analyticsApi, "get")
      .mockRejectedValueOnce(new ApiError("Сервертэй холбогдож чадсангүй", 0, null))
      .mockResolvedValueOnce(answered);
    render(<CampaignDetailPage />);

    expect(await screen.findByRole("alert")).toHaveTextContent("Сервертэй холбогдож чадсангүй");
    await userEvent.click(screen.getByRole("button", { name: "Дахин оролдох" }));

    expect(await screen.findByText("Багц таалагдсан уу?")).toBeInTheDocument();
    expect(get).toHaveBeenCalledTimes(2);
  });

  it("signs out when the results call is refused", async () => {
    vi.spyOn(companyApi, "get").mockResolvedValue(campaign());
    vi.spyOn(analyticsApi, "get").mockRejectedValue(new ApiError("no", 401, null));
    const clear = vi.spyOn(auth, "clear");
    render(<CampaignDetailPage />);

    await vi.waitFor(() => expect(router.replace).toHaveBeenCalledWith("/login"));
    expect(clear).toHaveBeenCalled();
  });
});
