import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { insightsApi, type InsightQuestion } from "@admin/lib/api";
import { AccessLogTable, actionLabel } from "./access-log-table";
import { groupFractions, hiddenLabel, peopleLabel } from "./insight-format";
import { PrivacyRulesCard } from "./privacy-rules-card";
import { QuestionExplorer, toFilter } from "./question-explorer";

vi.mock("@admin/lib/api", async (orig) => ({
  ...(await orig<typeof import("@admin/lib/api")>()),
  insightsApi: {
    distribution: vi.fn(),
    segments: vi.fn(),
    exportCsv: vi.fn(),
  },
}));

const QUESTIONS: InsightQuestion[] = [
  {
    questionId: 12,
    prompt: "Аль сошиал сүлжээг ашигладаг вэ?",
    type: "SINGLE_CHOICE",
    surveyTitle: "Сошиал",
    companyName: "MobiCom",
    respondents: 120,
    reportable: true,
  },
  {
    questionId: 13,
    prompt: "Подкаст сонсдог уу?",
    type: "SINGLE_CHOICE",
    surveyTitle: "Хөгжим",
    companyName: "MobiCom",
    respondents: 10,
    reportable: false,
  },
];

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(insightsApi.segments).mockResolvedValue({
    questionId: 12,
    prompt: "Аль сошиал сүлжээг ашигладаг вэ?",
    options: ["Facebook", "TikTok"],
    rows: [
      { dimension: "Бүгд", label: "Бүх оролцогч", suppressed: false, people: 120,
        shares: [{ option: "Facebook", percent: 70 }, { option: "TikTok", percent: 30 }] },
      { dimension: "Хүйс", label: "Эрэгтэй", suppressed: true, people: null, shares: [] },
    ],
  });
});

describe("format helpers", () => {
  it("never prints a number for a hidden group", () => {
    expect(hiddenLabel(50)).toBe("< 50");
    expect(peopleLabel(null, 50)).toBe("< 50");
    expect(peopleLabel(1200, 50)).toBe("≈ 1,200 хүн");
  });

  it("scales bars to the largest shown group", () => {
    expect(groupFractions([{ label: "a", people: 100 }, { label: "b", people: 50 }, { label: "c", people: null }]))
      .toEqual([1, 0.5, null]);
  });

  it("maps picked selects to API filters", () => {
    expect(toFilter("", "", "")).toEqual({ gender: null, ageBand: null, city: null });
    expect(toFilter("FEMALE", "25–34", "Ховд")).toEqual({ gender: "FEMALE", ageBand: "25–34", city: "Ховд" });
  });
});

describe("<PrivacyRulesCard>", () => {
  it("states the minimum group size and the other protections", () => {
    render(<PrivacyRulesCard minGroupSize={50} />);
    expect(screen.getByText(/50-аас цөөн хүнтэй бүлгийн/)).toBeInTheDocument();
    expect(screen.getByText(/Чөлөөт текст хариулт/)).toBeInTheDocument();
    expect(screen.getByText(/зөвшөөрсөн хэрэглэгчийн/)).toBeInTheDocument();
  });
});

describe("<AccessLogTable>", () => {
  it("shows who did what in Mongolian", () => {
    render(
      <AccessLogTable
        entries={[{ id: 1, adminPhone: "99990000", action: "EXPORT_CSV", detail: "question=12", at: "2026-10-14T04:00:00Z" }]}
      />,
    );
    expect(screen.getByText("CSV татсан")).toBeInTheDocument();
    expect(screen.getByText("99990000")).toBeInTheDocument();
    expect(actionLabel("UNKNOWN")).toBe("UNKNOWN");
  });

  it("names the admin reads of people and payouts the backend now logs", () => {
    for (const action of ["VIEW_USERS", "VIEW_USER", "VIEW_COMPANIES", "VIEW_PAYOUTS", "VIEW_PAYOUT_HISTORY"]) {
      expect(actionLabel(action)).toMatch(/[А-Яа-яӨөҮү]/);
    }
  });
});

describe("<QuestionExplorer>", () => {
  function renderExplorer() {
    return render(
      <QuestionExplorer questions={QUESTIONS} ageBands={["18–24", "25–34"]} cities={["Улаанбаатар", "Ховд"]}
        minGroupSize={50} />,
    );
  }

  it("marks which questions can be reported", () => {
    renderExplorer();
    expect(screen.getByText("Тайлагнана")).toBeInTheDocument();
    expect(screen.getByText("< 50 хүн")).toBeInTheDocument();
  });

  it("shows the shares and the segments of a picked question", async () => {
    vi.mocked(insightsApi.distribution).mockResolvedValue({
      questionId: 12, prompt: "Аль сошиал сүлжээг ашигладаг вэ?", type: "SINGLE_CHOICE",
      filter: { gender: null, ageBand: null, city: null }, suppressed: false, people: 120,
      shares: [{ option: "Facebook", percent: 70 }, { option: "TikTok", percent: 30 }],
    });
    renderExplorer();

    await userEvent.click(screen.getByText("Аль сошиал сүлжээг ашигладаг вэ?"));

    await waitFor(() => expect(screen.getAllByText("70%").length).toBeGreaterThan(0));
    expect(insightsApi.distribution).toHaveBeenCalledWith(12, { gender: null, ageBand: null, city: null });
    const table = screen.getByRole("table");
    expect(within(table).getByText("Эрэгтэй")).toBeInTheDocument();
    expect(within(table).getAllByText("—")).toHaveLength(2);
  });

  it("explains a hidden group instead of showing numbers", async () => {
    vi.mocked(insightsApi.distribution).mockResolvedValue({
      questionId: 12, prompt: "Аль сошиал сүлжээг ашигладаг вэ?", type: "SINGLE_CHOICE",
      filter: { gender: null, ageBand: null, city: null }, suppressed: true, people: null, shares: [],
    });
    renderExplorer();

    await userEvent.click(screen.getByText("Аль сошиал сүлжээг ашигладаг вэ?"));

    expect(await screen.findByText(/хувийн нууцыг хамгаалж/)).toBeInTheDocument();
  });

  it("downloads the CSV through the logged export call", async () => {
    vi.mocked(insightsApi.distribution).mockResolvedValue({
      questionId: 12, prompt: "Q", type: "SINGLE_CHOICE", filter: { gender: null, ageBand: null, city: null }, suppressed: true, people: null, shares: [],
    });
    vi.mocked(insightsApi.exportCsv).mockResolvedValue("csv");
    URL.createObjectURL = vi.fn(() => "blob:csv");
    URL.revokeObjectURL = vi.fn();
    const click = vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(() => {});
    renderExplorer();

    await userEvent.click(screen.getByText("Аль сошиал сүлжээг ашигладаг вэ?"));
    await userEvent.click(await screen.findByRole("button", { name: "CSV татах" }));

    await waitFor(() => expect(click).toHaveBeenCalled());
    expect(insightsApi.exportCsv).toHaveBeenCalledWith(12);
  });
});
