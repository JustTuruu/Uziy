import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { CONSOLE_LOGIN_COPY, type ConsoleLogin, type SmsStep } from "./console-login";
import { CONSOLE_LOGIN_FOOTER, ConsoleLoginPage, type ConsoleLoginPageProps } from "./console-login-page";

function login(overrides: Partial<ConsoleLogin> = {}): ConsoleLogin {
  return {
    phone: "",
    setPhone: vi.fn(),
    password: "",
    setPassword: vi.fn(),
    loading: false,
    error: null,
    notice: null,
    sms: null,
    submit: vi.fn(async (e) => e.preventDefault()),
    newCode: vi.fn(async () => {}),
    back: vi.fn(),
    ...overrides,
  };
}

function renderPage(over: Partial<ConsoleLoginPageProps> = {}) {
  const props: ConsoleLoginPageProps = {
    login: login(),
    logo: <span>logo</span>,
    consoleName: "Компанийн самбар",
    headline: "Гарчиг",
    lead: "Тайлбар",
    highlights: [
      { icon: <span>i</span>, title: "Нарийн зорилт", text: "Нас, хүйсээр" },
      { icon: <span>i</span>, title: "Шууд үр дүн", text: "Бодит хугацаанд" },
    ],
    title: "Компанийн самбарт нэвтрэх",
    subtitle: "Компанийн дансаараа нэвтэрнэ үү",
    ...over,
  };
  render(<ConsoleLoginPage {...props} />);
  return props;
}

describe("ConsoleLoginPage", () => {
  it("shows the brand panel: headline, lead, every highlight and the footer", () => {
    renderPage();
    expect(screen.getByRole("heading", { level: 2, name: "Гарчиг" })).toBeTruthy();
    expect(screen.getByText("Тайлбар")).toBeTruthy();
    const items = within(screen.getByRole("list")).getAllByRole("listitem");
    expect(items).toHaveLength(2);
    expect(items[0]).toHaveTextContent("Нарийн зорилт");
    expect(screen.getByRole("link", { name: CONSOLE_LOGIN_FOOTER.support })).toHaveAttribute(
      "href",
      `mailto:${CONSOLE_LOGIN_FOOTER.support}`,
    );
  });

  it("shows the password form in a card with its title", async () => {
    const props = renderPage();
    expect(screen.getByRole("heading", { level: 1, name: "Компанийн самбарт нэвтрэх" })).toBeTruthy();
    await userEvent.type(screen.getByLabelText("Утасны дугаар"), "8");
    expect(props.login.setPhone).toHaveBeenCalled();
    await userEvent.click(screen.getByRole("button", { name: "Нэвтрэх" }));
    expect(props.login.submit).toHaveBeenCalledOnce();
  });

  it("lets the browser fill saved sign-ins", () => {
    renderPage();
    expect(screen.getByLabelText("Утасны дугаар")).toHaveAttribute("autocomplete", "username");
    expect(screen.getByLabelText("Нууц үг")).toHaveAttribute("autocomplete", "current-password");
  });

  it("shows the error and a busy button while signing in", () => {
    renderPage({ login: login({ error: "Утас эсвэл нууц үг буруу байна", loading: true }) });
    expect(screen.getByRole("alert")).toHaveTextContent("Утас эсвэл нууц үг буруу байна");
    expect(screen.getByRole("button", { name: CONSOLE_LOGIN_COPY.signingIn })).toBeDisabled();
  });

  it("shows the note under the card only when given", () => {
    renderPage({ note: "Данс авах бол холбогдоно уу" });
    expect(screen.getByText("Данс авах бол холбогдоно уу")).toBeTruthy();
  });

  it("switches the card to the SMS step when the backend asks for it", () => {
    const sms: SmsStep = {
      status: "PENDING",
      challenge: {
        verificationId: "c0ffee00-0000-0000-0000-000000000001",
        phoneNumber: "•••• 2233",
        role: "COMPANY",
        shortcode: "144773",
        smsText: "482916",
        smsUri: "sms:144773?body=482916",
        displayInstruction: "SMS илгээнэ үү",
        expiresAt: "2999-01-01T00:00:00Z",
      },
    };
    renderPage({ login: login({ sms }) });
    expect(screen.queryByLabelText("Нууц үг")).toBeNull();
    expect(screen.getByText("482916")).toBeTruthy();
  });
});
