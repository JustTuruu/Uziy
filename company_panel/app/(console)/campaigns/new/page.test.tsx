import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  ApiError,
  auth,
  companyApi,
  platformSettingsApi,
  type Campaign,
  type CreateCampaignBody,
} from "@/lib/api";
import { formatTugrik } from "@/lib/utils";
import NewCampaignPage from "./page";

const replace = vi.fn();
const push = vi.fn();
// Stable object, like Next's real router — effects depend on it.
const router = { replace, push, refresh: vi.fn() };
vi.mock("next/navigation", () => ({
  useRouter: () => router,
}));

const settings = {
  commissionPercent: 30,
  minRewardPerViewer: 100,
  updatedAt: "2026-09-28T10:00:00Z",
};

function serverCampaign(over: Partial<Campaign> = {}): Campaign {
  return {
    id: 77,
    title: "Хэрэглэгчийн судалгаа",
    videoUrl: "",
    durationSeconds: 0,
    hasVideo: false,
    targetGender: "ALL",
    minAge: 18,
    maxAge: 45,
    targetCity: "Улаанбаатар",
    totalBudget: 1_000_000,
    remainingBudget: 1_000_000,
    costPerView: 1_000,
    rewardPerUser: 700,
    targetViewers: 1_000,
    commissionPercent: 30,
    paidAt: null,
    status: "AWAITING_PAYMENT",
    createdAt: "2026-09-28T10:00:00Z",
    ...over,
  };
}

const next = () => screen.getByRole("button", { name: "Дараах" });

/** Walks a survey-only campaign from the type step to the budget step. */
async function toBudgetStep() {
  render(<NewCampaignPage />);
  await userEvent.click(screen.getByRole("button", { name: /Судалгаа зөвхөн/ }));
  await userEvent.type(screen.getByLabelText("Кампанийн гарчиг"), "Хэрэглэгчийн судалгаа");
  await userEvent.click(next()); // → targeting
  await userEvent.click(next()); // → budget
}

async function budgetToReview() {
  await userEvent.click(next()); // → survey
  await userEvent.type(screen.getByLabelText("Асуулт 1"), "Та манай үйлчилгээг ашигладаг уу?");
  await userEvent.type(screen.getByPlaceholderText("Хариулт 1"), "Тийм");
  await userEvent.type(screen.getByPlaceholderText("Хариулт 2"), "Үгүй");
  await userEvent.click(next()); // → review
}

beforeEach(() => {
  replace.mockReset();
  push.mockReset();
  vi.spyOn(auth, "getToken").mockReturnValue("company-tok");
});
afterEach(() => vi.restoreAllMocks());

describe("New campaign wizard — pricing and payment", () => {
  it("creates in VIEWERS mode, then pays on the final step", async () => {
    vi.spyOn(platformSettingsApi, "get").mockResolvedValue(settings);
    const create = vi.spyOn(companyApi, "create").mockResolvedValue(serverCampaign());
    const pay = vi.spyOn(companyApi, "pay").mockResolvedValue({
      campaign: serverCampaign({ status: "PENDING", paidAt: "2026-09-28T10:01:00Z" }),
      payment: {
        id: 1,
        campaignId: 77,
        campaignTitle: "Хэрэглэгчийн судалгаа",
        amount: 1_000_000,
        provider: "SIMULATED",
        status: "PAID",
        reference: "UZ-20260928-77",
        createdAt: "2026-09-28T10:01:00Z",
        paidAt: "2026-09-28T10:01:00Z",
      },
    });

    await toBudgetStep();
    const reward = await screen.findByLabelText(/Нэг үзэгчид олгох урамшуулал/);
    expect(reward).toHaveValue("700");
    expect(screen.queryByText(/Тооцоолсон үнэ/)).not.toBeInTheDocument();

    await budgetToReview();
    expect(screen.getByText("Хүрэх үзэгч").nextSibling).toHaveTextContent("1,000");
    expect(screen.getByText("Платформын шимтгэл (30%)").nextSibling).toHaveTextContent(
      formatTugrik(300_000),
    );
    expect(screen.getByText("Төлөх дүн").nextSibling).toHaveTextContent(
      formatTugrik(1_000_000),
    );

    await userEvent.click(screen.getByRole("button", { name: "Үүсгэх" }));

    expect(create).toHaveBeenCalledTimes(1);
    const body = create.mock.calls[0][0] as CreateCampaignBody & Record<string, unknown>;
    expect(body).toMatchObject({
      title: "Хэрэглэгчийн судалгаа",
      hasVideo: false,
      totalBudget: 1_000_000,
      targetViewers: 1_000,
    });
    expect(body).not.toHaveProperty("rewardPerUser");
    expect(body).not.toHaveProperty("costPerView");
    expect(body.questions).toEqual([
      {
        prompt: "Та манай үйлчилгээг ашигладаг уу?",
        type: "SINGLE_CHOICE",
        options: ["Тийм", "Үгүй"],
        required: true,
      },
    ]);

    // Payment step: invoice from the server's campaign, no Back/Next bar.
    expect(await screen.findByText("Туршилтын горим: одоогоор бодит төлбөр хийгдэхгүй"))
      .toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Буцах/ })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Дараах" })).not.toBeInTheDocument();

    await userEvent.click(screen.getByRole("button", { name: "Төлөх" }));
    expect(pay).toHaveBeenCalledWith(77);
    expect(await screen.findByText("Төлбөр амжилттай төлөгдлөө")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Аян руу очих" })).toHaveAttribute(
      "href",
      "/campaigns/77",
    );
    expect(push).not.toHaveBeenCalled();
  });

  it("sends only rewardPerUser when the company drove the reward field", async () => {
    vi.spyOn(platformSettingsApi, "get").mockResolvedValue(settings);
    const create = vi
      .spyOn(companyApi, "create")
      .mockResolvedValue(
        serverCampaign({ totalBudget: 999_570, costPerView: 715, rewardPerUser: 500, targetViewers: 1_398 }),
      );

    await toBudgetStep();
    const reward = await screen.findByLabelText(/Нэг үзэгчид олгох урамшуулал/);
    await userEvent.clear(reward);
    await userEvent.type(reward, "500");
    expect(screen.getByLabelText(/Хүрэх үзэгчийн тоо/)).toHaveValue("1398");

    await budgetToReview();
    await userEvent.click(screen.getByRole("button", { name: "Үүсгэх" }));

    const body = create.mock.calls[0][0] as CreateCampaignBody & Record<string, unknown>;
    expect(body).toMatchObject({ totalBudget: 1_000_000, rewardPerUser: 500 });
    expect(body).not.toHaveProperty("targetViewers");
    // The invoice uses the server-returned amount.
    expect(await screen.findByText(formatTugrik(999_570))).toBeInTheDocument();
  });

  it("blocks 'Дараах' on the budget step while pricing has an error", async () => {
    vi.spyOn(platformSettingsApi, "get").mockResolvedValue(settings);
    await toBudgetStep();
    const budget = await screen.findByLabelText(/Нийт төсөв/);
    await userEvent.clear(budget);
    await userEvent.type(budget, "500");
    expect(screen.getByRole("alert")).toHaveTextContent("Төсөв хэт бага байна");
    expect(next()).toBeDisabled();

    await userEvent.clear(budget);
    await userEvent.type(budget, "1000000");
    expect(next()).toBeEnabled();
  });

  it("shows a retryable error when the commission settings fail to load", async () => {
    const get = vi
      .spyOn(platformSettingsApi, "get")
      .mockRejectedValueOnce(new Error("Сүлжээний алдаа"))
      .mockResolvedValueOnce(settings);

    await toBudgetStep();
    expect(await screen.findByRole("alert")).toHaveTextContent("Сүлжээний алдаа");
    expect(next()).toBeDisabled();

    await userEvent.click(screen.getByRole("button", { name: "Дахин оролдох" }));
    expect(await screen.findByLabelText(/Хүрэх үзэгчийн тоо/)).toHaveValue("1000");
    expect(get).toHaveBeenCalledTimes(2);
    expect(next()).toBeEnabled();
  });

  it("keeps the company on the review step when the server rejects the price", async () => {
    vi.spyOn(platformSettingsApi, "get").mockResolvedValue(settings);
    vi.spyOn(companyApi, "create").mockRejectedValue(
      new ApiError("Нэг үзэгчид олгох урамшуулал хамгийн багадаа 150 ₮ байх ёстой", 400, null),
    );

    await toBudgetStep();
    await screen.findByLabelText(/Хүрэх үзэгчийн тоо/);
    await budgetToReview();
    await userEvent.click(screen.getByRole("button", { name: "Үүсгэх" }));

    await waitFor(() =>
      expect(screen.getByRole("alert")).toHaveTextContent("хамгийн багадаа 150 ₮"),
    );
    expect(screen.getByRole("button", { name: "Үүсгэх" })).toBeEnabled();
    expect(screen.getByRole("button", { name: /Буцах/ })).toBeEnabled();
  });
});
