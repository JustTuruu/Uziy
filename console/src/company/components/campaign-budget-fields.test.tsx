import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useState } from "react";
import { describe, expect, it, vi } from "vitest";
import {
  CampaignBudgetFields,
  DEFAULT_BUDGET_FIELDS,
  pricingFromFields,
  type BudgetFieldsValue,
} from "./campaign-budget-fields";
import { formatTugrik } from "@/lib/utils";

const settings = { commissionPercent: 30, minRewardPerViewer: 100 };

function Harness({
  initial = DEFAULT_BUDGET_FIELDS,
  onChange,
}: {
  initial?: BudgetFieldsValue;
  onChange?: (v: BudgetFieldsValue) => void;
}) {
  const [value, setValue] = useState(initial);
  return (
    <CampaignBudgetFields
      value={value}
      settings={settings}
      onChange={(v) => {
        setValue(v);
        onChange?.(v);
      }}
    />
  );
}

const budget = () => screen.getByLabelText(/Нийт төсөв/) as HTMLInputElement;
const viewers = () => screen.getByLabelText(/Хүрэх үзэгчийн тоо/) as HTMLInputElement;
const reward = () =>
  screen.getByLabelText(/Нэг үзэгчид олгох урамшуулал/) as HTMLInputElement;

describe("<CampaignBudgetFields>", () => {
  it("starts in viewers mode: 1,000,000 ₮ / 1,000 viewers → 700 ₮ each", () => {
    render(<Harness />);
    expect(budget()).toHaveValue("1000000");
    expect(viewers()).toHaveValue("1000");
    expect(reward()).toHaveValue("700");
    expect(reward().closest("label")).toHaveTextContent("Автоматаар тооцоолсон");
    expect(viewers().closest("label")).not.toHaveTextContent("Автоматаар тооцоолсон");
    expect(screen.getByText(`${formatTugrik(1_000_000)}`, { selector: "div.font-mono" }))
      .toBeInTheDocument();
    expect(screen.getByText(/Платформын шимтгэл \(30%\)/)).toBeInTheDocument();
    expect(screen.getByText(/үзэгч бүр 700 ₮ авна/)).toBeInTheDocument();
  });

  it("typing a viewer count updates the computed reward", async () => {
    render(<Harness />);
    await userEvent.clear(viewers());
    await userEvent.type(viewers(), "2000");
    expect(reward()).toHaveValue("350");
  });

  it("typing a reward switches the driver and recomputes the viewer count", async () => {
    const onChange = vi.fn();
    render(<Harness onChange={onChange} />);
    await userEvent.clear(reward());
    await userEvent.type(reward(), "500");

    expect(onChange).toHaveBeenLastCalledWith(
      expect.objectContaining({ mode: "REWARD", rewardText: "500" }),
    );
    expect(reward()).toHaveValue("500");
    expect(viewers()).toHaveValue("1398"); // V4: C = 715, N = 1,398
    expect(viewers().closest("label")).toHaveTextContent("Автоматаар тооцоолсон");
    expect(reward().closest("label")).not.toHaveTextContent("Автоматаар тооцоолсон");
  });

  it("typing in viewers again switches the driver back", async () => {
    render(<Harness initial={{ ...DEFAULT_BUDGET_FIELDS, mode: "REWARD", rewardText: "500" }} />);
    expect(viewers()).toHaveValue("1398");
    await userEvent.clear(viewers());
    await userEvent.type(viewers(), "1000");
    expect(reward()).toHaveValue("700");
  });

  it("shows BUDGET_TOO_SMALL for V6 (500 ₮ for 1,000 viewers)", () => {
    render(<Harness initial={{ ...DEFAULT_BUDGET_FIELDS, budgetText: "500" }} />);
    expect(screen.getByRole("alert")).toHaveTextContent(
      "Төсөв хэт бага байна — үзэгчийн тоог багасгах эсвэл төсвөө нэмнэ үү",
    );
  });

  it("shows REWARD_BELOW_MIN for V7 (100,000 ₮ for 1,000 viewers → 70 ₮)", () => {
    render(<Harness initial={{ ...DEFAULT_BUDGET_FIELDS, budgetText: "100000" }} />);
    expect(screen.getByRole("alert")).toHaveTextContent(
      "Нэг үзэгчид олгох урамшуулал хамгийн багадаа 100 ₮ байх ёстой",
    );
    expect(reward()).toHaveValue("70");
    // Summary is withheld while there is an error.
    expect(screen.queryByText(formatTugrik(100_000), { selector: "div.font-mono" }))
      .not.toBeInTheDocument();
  });

  it("notes the uncharged remainder for V2 (1,428 viewers)", async () => {
    render(<Harness />);
    await userEvent.clear(viewers());
    await userEvent.type(viewers(), "1428");
    expect(reward()).toHaveValue("490");
    expect(screen.getByText(`Үлдэгдэл ${formatTugrik(400)} төлбөрт орохгүй.`))
      .toBeInTheDocument();
    expect(screen.getByText(formatTugrik(999_600), { selector: "div.font-mono" }))
      .toBeInTheDocument();
  });

  it("does not show a remainder note when the budget divides evenly", () => {
    render(<Harness />);
    expect(screen.queryByText(/төлбөрт орохгүй/)).not.toBeInTheDocument();
  });

  it("blanks the computed field and asks for input when the driver is cleared", async () => {
    render(<Harness />);
    await userEvent.clear(viewers());
    expect(reward()).toHaveValue("");
    expect(screen.getByRole("alert")).toHaveTextContent("Үзэгчийн тоогоо оруулна уу");
  });
});

describe("pricingFromFields", () => {
  it("parses the raw texts and prices with the admin settings", () => {
    const p = pricingFromFields(
      { budgetText: "1000000", mode: "VIEWERS", viewersText: "1000", rewardText: "999" },
      settings,
    );
    expect(p).toMatchObject({ rewardPerViewer: 700, payable: 1_000_000, error: null });
  });

  it("ignores the non-driver text", () => {
    const p = pricingFromFields(
      { budgetText: "1000000", mode: "REWARD", viewersText: "5", rewardText: "700" },
      settings,
    );
    expect(p.targetViewers).toBe(1_000);
  });
});
