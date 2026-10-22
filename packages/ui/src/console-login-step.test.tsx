import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { CONSOLE_LOGIN_COPY, type SmsStep } from "./console-login";
import { ConsoleSmsStep, FormError } from "./console-login-step";

const step: SmsStep = {
  status: "PENDING",
  challenge: {
    verificationId: "c0ffee00-0000-0000-0000-000000000001",
    phoneNumber: "•••• 2233",
    role: "COMPANY",
    shortcode: "144773",
    smsText: "482916",
    smsUri: "sms:144773?body=482916",
    displayInstruction: 'Та өөрийн 99112233 дугаараас 144773 дугаарт "482916" гэж SMS илгээнэ үү.',
    expiresAt: "2999-01-01T00:00:00Z",
  },
};

function renderStep(overrides: Partial<Parameters<typeof ConsoleSmsStep>[0]> = {}) {
  const props = {
    step,
    onNewCode: vi.fn(),
    newCodeBusy: false,
    notice: null,
    error: null,
    onBack: vi.fn(),
    ...overrides,
  };
  render(<ConsoleSmsStep {...props} />);
  return props;
}

describe("ConsoleSmsStep", () => {
  it("shows what to text from which phone, and that the browser will be remembered", () => {
    renderStep();
    expect(screen.getByRole("heading", { name: CONSOLE_LOGIN_COPY.title })).toBeTruthy();
    expect(screen.getByText(CONSOLE_LOGIN_COPY.subtitle("•••• 2233"))).toBeTruthy();
    expect(screen.getByText("144773")).toBeTruthy();
    expect(screen.getByText("482916")).toBeTruthy();
    expect(screen.getByText(step.challenge.displayInstruction)).toBeTruthy();
    expect(screen.getByText("Энэ хөтөч 30 хоног танигдана.")).toBeTruthy();
  });

  it("shows the notice and the error", () => {
    renderStep({ notice: CONSOLE_LOGIN_COPY.newCodeReady, error: "Алдаа гарлаа" });
    expect(screen.getByRole("status")).toHaveTextContent(CONSOLE_LOGIN_COPY.newCodeReady);
    expect(screen.getByRole("alert")).toHaveTextContent("Алдаа гарлаа");
  });

  it("offers a new code once the check expired", async () => {
    const props = renderStep({ step: { ...step, status: "EXPIRED" } });
    await userEvent.click(screen.getByRole("button", { name: "Шинэ код авах" }));
    expect(props.onNewCode).toHaveBeenCalled();
  });

  it("goes back to the password form", async () => {
    const props = renderStep();
    await userEvent.click(screen.getByRole("button", { name: CONSOLE_LOGIN_COPY.back }));
    expect(props.onBack).toHaveBeenCalled();
  });
});

describe("FormError", () => {
  it("is announced as an alert", () => {
    render(<FormError message="Утас эсвэл нууц үг буруу байна" />);
    expect(screen.getByRole("alert")).toHaveTextContent("Утас эсвэл нууц үг буруу байна");
  });
});
