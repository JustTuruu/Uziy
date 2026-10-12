import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  ApiError,
  analyticsApi,
  auth,
  type AnalyticsReport,
  type CampaignPerformance,
} from "@/lib/api";
import { formatTugrik } from "@/lib/utils";
import AnalyticsPage from "./page";

const router = { replace: vi.fn(), push: vi.fn(), refresh: vi.fn() };
vi.mock("next/navigation", () => ({ useRouter: () => router }));

function performance(over: Partial<CampaignPerformance> = {}): CampaignPerformance {
  return {
    campaignId: 1,
    title: "Шинэ 5G багц",
    status: "ACTIVE",
    hasVideo: true,
    targetViewers: 10,
    responses: 6,
    reachPercent: 60,
    spent: 6000,
    rewardsPaid: 4200,
    costPerResponse: 1000,
    remainingResponses: 4,
    responsesLast7Days: 6,
    daysLeft: 5,
    ...over,
  };
}

function report(over: Partial<AnalyticsReport> = {}): AnalyticsReport {
  return {
    days: 30,
    totals: {
      campaignCount: 2,
      activeCount: 1,
      responses: 6,
      rewardsPaid: 4200,
      spent: 6000,
      costPerResponse: 1000,
    },
    campaigns: [
      performance(),
      performance({
        campaignId: 2,
        title: "Оюутны зээл",
        responses: 0,
        reachPercent: 0,
        spent: 0,
        costPerResponse: null,
        remainingResponses: 0,
        responsesLast7Days: 0,
        daysLeft: null,
        status: "PAUSED",
      }),
    ],
    daily: [
      { date: "2026-10-06", responses: 0 },
      { date: "2026-10-07", responses: 6 },
    ],
    hourly: Array.from({ length: 24 }, (_, h) => (h === 19 ? 12 : 0)),
    audience: {
      gender: [
        { label: "MALE", count: 4 },
        { label: "FEMALE", count: 2 },
      ],
      ageBands: [
        { label: "13–17", count: 0 },
        { label: "18–24", count: 6 },
      ],
      cities: [{ label: "Улаанбаатар", count: 6 }],
    },
    questions: [],
    segments: [],
    ...over,
  };
}

beforeEach(() => {
  vi.spyOn(auth, "getToken").mockReturnValue("company-tok");
});
afterEach(() => {
  vi.restoreAllMocks();
  router.replace.mockReset();
});

describe("Company analytics page", () => {
  it("sends a visitor without a token to login", () => {
    vi.spyOn(auth, "getToken").mockReturnValue(null);
    const get = vi.spyOn(analyticsApi, "get").mockResolvedValue(report());

    render(<AnalyticsPage />);

    expect(router.replace).toHaveBeenCalledWith("/login");
    expect(get).not.toHaveBeenCalled();
  });

  it("loads the last 30 days of every campaign by default", async () => {
    const get = vi.spyOn(analyticsApi, "get").mockResolvedValue(report());

    render(<AnalyticsPage />);

    expect(await screen.findByText("Нийт хариулт")).toBeInTheDocument();
    expect(get).toHaveBeenCalledWith({ days: 30, campaignId: undefined });
  });

  it("shows the headline numbers", async () => {
    vi.spyOn(analyticsApi, "get").mockResolvedValue(report());
    render(<AnalyticsPage />);

    expect(await screen.findByText("1 идэвхтэй / 2 судалгаа")).toBeInTheDocument();
    expect(screen.getAllByText(formatTugrik(6000)).length).toBeGreaterThan(0);
    expect(screen.getByText("Хариулт тутмын өртөг")).toBeInTheDocument();
  });

  it("compares the campaigns, with a dash where nothing was answered", async () => {
    vi.spyOn(analyticsApi, "get").mockResolvedValue(report());
    render(<AnalyticsPage />);

    const table = await screen.findByRole("table");
    const rows = within(table).getAllByRole("row");
    expect(rows[1]).toHaveTextContent("Шинэ 5G багц");
    expect(rows[1]).toHaveTextContent("60%");
    expect(rows[2]).toHaveTextContent("Оюутны зээл");
    expect(rows[2]).toHaveTextContent("—");
  });

  it("shows who answered when the backend sends an audience", async () => {
    vi.spyOn(analyticsApi, "get").mockResolvedValue(report());
    render(<AnalyticsPage />);

    expect(await screen.findByRole("region", { name: "Хүйс" })).toHaveTextContent("Эрэгтэй");
    expect(screen.getByRole("region", { name: "Нас" })).toHaveTextContent("18–24");
    expect(screen.getByRole("region", { name: "Хот" })).toHaveTextContent("Улаанбаатар");
  });

  it("explains why the audience is hidden when there are too few responses", async () => {
    vi.spyOn(analyticsApi, "get").mockResolvedValue(report({ audience: null }));
    render(<AnalyticsPage />);

    expect(await screen.findByText(/дор хаяж 5 хариулт/)).toBeInTheDocument();
    expect(screen.queryByRole("region", { name: "Хүйс" })).not.toBeInTheDocument();
  });

  it("says so when nothing came in during the window", async () => {
    vi.spyOn(analyticsApi, "get").mockResolvedValue(
      report({ daily: [{ date: "2026-10-07", responses: 0 }] }),
    );
    render(<AnalyticsPage />);

    expect(await screen.findByText("Энэ хугацаанд хариулт ирээгүй байна.")).toBeInTheDocument();
  });

  it("switches the chart to a table and back", async () => {
    vi.spyOn(analyticsApi, "get").mockResolvedValue(report());
    render(<AnalyticsPage />);

    await userEvent.click(await screen.findByRole("button", { name: "Хүснэгт" }));
    expect(screen.getByRole("columnheader", { name: "Огноо" })).toBeInTheDocument();
    expect(screen.getByRole("row", { name: /10\.07/ })).toBeInTheDocument();

    await userEvent.click(screen.getByRole("button", { name: "График" }));
    expect(screen.getByRole("img", { name: "Өдөр тутмын хариултын тоо" })).toBeInTheDocument();
  });

  it("reloads for another window", async () => {
    const get = vi.spyOn(analyticsApi, "get").mockResolvedValue(report());
    render(<AnalyticsPage />);
    await screen.findByText("Нийт хариулт");

    await userEvent.click(screen.getByRole("radio", { name: "7 хоног" }));

    await waitFor(() =>
      expect(get).toHaveBeenLastCalledWith({ days: 7, campaignId: undefined }),
    );
  });

  it("narrows to one campaign from the picker and shows its question results", async () => {
    const get = vi
      .spyOn(analyticsApi, "get")
      .mockResolvedValueOnce(report())
      .mockResolvedValue(
        report({
          questions: [
            {
              questionId: 7,
              prompt: "Таалагдсан уу?",
              type: "SINGLE_CHOICE",
              answered: 6,
              options: [
                { label: "Тийм", count: 4 },
                { label: "Үгүй", count: 2 },
              ],
            },
            {
              questionId: 8,
              prompt: "Санал",
              type: "TEXT",
              answered: 3,
              options: [],
            },
          ],
        }),
      );
    render(<AnalyticsPage />);
    await screen.findByText("Нийт хариулт");

    await userEvent.selectOptions(screen.getByLabelText("Судалгаа сонгох"), "1");

    expect(await screen.findByText("Таалагдсан уу?")).toBeInTheDocument();
    expect(get).toHaveBeenLastCalledWith({ days: 30, campaignId: 1 });
    expect(
      within(screen.getByRole("region", { name: "Таалагдсан уу?" })).getByText("4 · 67%"),
    ).toBeInTheDocument();
    expect(screen.getByText(/хувь хүний хариултыг харуулахгүй/)).toBeInTheDocument();
  });

  it("clicking a campaign name in the table selects it", async () => {
    const get = vi.spyOn(analyticsApi, "get").mockResolvedValue(report());
    render(<AnalyticsPage />);

    await userEvent.click(await screen.findByRole("button", { name: "Оюутны зээл" }));

    await waitFor(() =>
      expect(get).toHaveBeenLastCalledWith({ days: 30, campaignId: 2 }),
    );
  });

  it("invites a company with no campaigns to create one", async () => {
    vi.spyOn(analyticsApi, "get").mockResolvedValue(
      report({ campaigns: [], daily: [] }),
    );
    render(<AnalyticsPage />);

    expect(await screen.findByText(/Судалгаа байхгүй байна/)).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Шинэ судалгаа" })).toHaveAttribute(
      "href",
      "/campaigns/new",
    );
  });

  it("shows a failure instead of a blank page", async () => {
    vi.spyOn(analyticsApi, "get").mockRejectedValue(new ApiError("Сервер унтарсан", 500, null));
    render(<AnalyticsPage />);

    expect(await screen.findByRole("alert")).toHaveTextContent("Сервер унтарсан");
  });

  it("signs out and goes to login when the token is refused", async () => {
    const clear = vi.spyOn(auth, "clear").mockImplementation(() => {});
    vi.spyOn(analyticsApi, "get").mockRejectedValue(new ApiError("no", 401, null));
    render(<AnalyticsPage />);

    await waitFor(() => expect(router.replace).toHaveBeenCalledWith("/login"));
    expect(clear).toHaveBeenCalled();
  });

  it("draws the hour-of-day chart next to the daily one", async () => {
    vi.spyOn(analyticsApi, "get").mockResolvedValue(report());
    render(<AnalyticsPage />);

    expect(await screen.findByRole("img", { name: "Цаг тутмын хариултын тоо" })).toBeInTheDocument();
    expect(screen.getByRole("img", { name: "Өдөр тутмын хариултын тоо" })).toBeInTheDocument();
  });

  it("writes the findings as sentences", async () => {
    vi.spyOn(analyticsApi, "get").mockResolvedValue(report());
    render(<AnalyticsPage />);

    expect(await screen.findByText(/19:00–20:00 цагт ирдэг/)).toBeInTheDocument();
  });

  it("shows how long each campaign's budget lasts", async () => {
    vi.spyOn(analyticsApi, "get").mockResolvedValue(report());
    render(<AnalyticsPage />);

    expect(await screen.findByText("~5 хоног")).toBeInTheDocument();
    expect(screen.getByText("4 хариулт үлдсэн")).toBeInTheDocument();
  });

  it("compares who answered what once a campaign with big-enough segments is selected", async () => {
    vi.spyOn(analyticsApi, "get")
      .mockResolvedValueOnce(report())
      .mockResolvedValue(
        report({
          segments: [
            {
              questionId: 7,
              prompt: "Таалагдсан уу?",
              segments: [
                { label: "MALE", count: 5 },
                { label: "FEMALE", count: 5 },
              ],
              options: [{ label: "Тийм", counts: [5, 0] }],
            },
          ],
        }),
      );
    render(<AnalyticsPage />);
    await screen.findByText("Нийт хариулт");

    await userEvent.selectOptions(screen.getByLabelText("Судалгаа сонгох"), "1");

    expect(await screen.findByText("Хэн ямар хариулт өгсөн бэ")).toBeInTheDocument();
    expect(screen.getByRole("table", { name: "Таалагдсан уу?" })).toHaveTextContent("100%");
  });

  it("hides the segment card when no segment is big enough", async () => {
    vi.spyOn(analyticsApi, "get").mockResolvedValue(report({ segments: [] }));
    render(<AnalyticsPage />);
    await screen.findByText("Нийт хариулт");

    expect(screen.queryByText("Хэн ямар хариулт өгсөн бэ")).not.toBeInTheDocument();
  });
});
