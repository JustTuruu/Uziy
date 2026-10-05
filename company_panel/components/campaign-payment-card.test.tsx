import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ApiError, companyApi, type Campaign, type PayCampaignResponse } from "@/lib/api";
import { formatTugrik } from "@/lib/utils";
import { CampaignPaymentCard } from "./campaign-payment-card";

const replace = vi.fn();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ replace, push: vi.fn(), refresh: vi.fn() }),
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
    totalBudget: 999_570,
    remainingBudget: 999_570,
    costPerView: 715,
    rewardPerUser: 500,
    targetViewers: 1_398,
    commissionPercent: 30,
    paidAt: null,
    status: "AWAITING_PAYMENT",
    createdAt: "2026-09-28T10:00:00Z",
    ...over,
  };
}

function paidResponse(): PayCampaignResponse {
  return {
    campaign: campaign({ status: "PENDING", paidAt: "2026-09-28T10:05:00Z" }),
    payment: {
      id: 9,
      campaignId: 42,
      campaignTitle: "Шинэ 5G багц",
      amount: 999_570,
      provider: "SIMULATED",
      status: "PAID",
      reference: "UZ-20260928-42",
      createdAt: "2026-09-28T10:05:00Z",
      paidAt: "2026-09-28T10:05:00Z",
    },
  };
}

const payButton = () => screen.getByRole("button", { name: /Төлөх|Дахин оролдох|Төлж байна/ });

beforeEach(() => replace.mockReset());
afterEach(() => vi.restoreAllMocks());

describe("<CampaignPaymentCard>", () => {
  it("shows the server-priced invoice and the test-mode notice", () => {
    render(<CampaignPaymentCard campaign={campaign()} />);
    expect(screen.getByText("Шинэ 5G багц")).toBeInTheDocument();
    expect(screen.getByText(formatTugrik(999_570))).toBeInTheDocument();
    expect(screen.getByText(formatTugrik(699_000))).toBeInTheDocument(); // 1,398 × 500
    expect(screen.getByText(formatTugrik(300_570))).toBeInTheDocument();
    expect(screen.getByText("Платформын шимтгэл (30%)")).toBeInTheDocument();
    expect(
      screen.getByText("Туршилтын горим: одоогоор бодит төлбөр хийгдэхгүй"),
    ).toBeInTheDocument();
    expect(payButton()).toHaveTextContent("Төлөх");
  });

  it("pays and shows the success state with navigation (wizard)", async () => {
    const pay = vi.spyOn(companyApi, "pay").mockResolvedValue(paidResponse());
    const onPaid = vi.fn();
    render(<CampaignPaymentCard campaign={campaign()} variant="wizard" onPaid={onPaid} />);

    await userEvent.click(payButton());

    expect(pay).toHaveBeenCalledWith(42);
    expect(await screen.findByText("Төлбөр амжилттай төлөгдлөө")).toBeInTheDocument();
    expect(
      screen.getByText("Админ шалгаж баталгаажуулсны дараа аян идэвхжинэ."),
    ).toBeInTheDocument();
    expect(screen.getByText(/UZ-20260928-42/)).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Аян руу очих" })).toHaveAttribute(
      "href",
      "/campaigns/42",
    );
    expect(screen.getByRole("link", { name: "Бүх аян" })).toHaveAttribute(
      "href",
      "/campaigns",
    );
    expect(onPaid).toHaveBeenCalledWith(paidResponse());
  });

  it("detail variant shows success without the wizard's navigation buttons", async () => {
    vi.spyOn(companyApi, "pay").mockResolvedValue(paidResponse());
    render(<CampaignPaymentCard campaign={campaign()} />);
    await userEvent.click(payButton());
    expect(await screen.findByText("Төлбөр амжилттай төлөгдлөө")).toBeInTheDocument();
    expect(screen.queryByRole("link", { name: "Аян руу очих" })).not.toBeInTheDocument();
  });

  it("disables the button while the payment is in flight (no double charge)", async () => {
    let resolve!: (r: PayCampaignResponse) => void;
    const pay = vi
      .spyOn(companyApi, "pay")
      .mockReturnValue(new Promise((r) => (resolve = r)));
    render(<CampaignPaymentCard campaign={campaign()} />);

    await userEvent.click(payButton());

    expect(payButton()).toBeDisabled();
    expect(payButton()).toHaveTextContent("Төлж байна...");
    await userEvent.click(payButton());
    expect(pay).toHaveBeenCalledTimes(1);

    resolve(paidResponse());
    expect(await screen.findByText("Төлбөр амжилттай төлөгдлөө")).toBeInTheDocument();
  });

  it("on error shows the message, a retry button and the saved-campaign note", async () => {
    const pay = vi
      .spyOn(companyApi, "pay")
      .mockRejectedValueOnce(
        new ApiError("Төлбөрийн систем хараахан холбогдоогүй байна", 503, null),
      )
      .mockResolvedValueOnce(paidResponse());
    render(<CampaignPaymentCard campaign={campaign()} variant="wizard" />);

    await userEvent.click(payButton());

    const alert = await screen.findByRole("alert");
    expect(alert).toHaveTextContent("Төлбөрийн систем хараахан холбогдоогүй байна");
    expect(alert).toHaveTextContent(/Аян хадгалагдсан тул дараа нь/);
    expect(alert).toHaveTextContent(/аяны хуудаснаас/);
    expect(screen.getByRole("link", { name: "аяны хуудаснаас" })).toHaveAttribute(
      "href",
      "/campaigns/42",
    );
    expect(payButton()).toHaveTextContent("Дахин оролдох");
    expect(payButton()).toBeEnabled();

    await userEvent.click(payButton());
    await waitFor(() =>
      expect(screen.getByText("Төлбөр амжилттай төлөгдлөө")).toBeInTheDocument(),
    );
    expect(pay).toHaveBeenCalledTimes(2);
  });

  it("uses a generic message for non-API failures and omits the saved note on detail", async () => {
    vi.spyOn(companyApi, "pay").mockRejectedValue(new TypeError("Failed to fetch"));
    render(<CampaignPaymentCard campaign={campaign()} />);
    await userEvent.click(payButton());
    const alert = await screen.findByRole("alert");
    expect(alert).toHaveTextContent("Төлбөр төлөхөд алдаа гарлаа");
    expect(alert).not.toHaveTextContent(/Аян хадгалагдсан/);
  });

  it("sends the user to login when the session has expired", async () => {
    vi.spyOn(companyApi, "pay").mockRejectedValue(new ApiError("Unauthorized", 401, null));
    render(<CampaignPaymentCard campaign={campaign()} />);
    await userEvent.click(payButton());
    await waitFor(() => expect(replace).toHaveBeenCalledWith("/login"));
  });
});
