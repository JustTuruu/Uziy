import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import {
  SMS_COPY,
  SmsVerificationCard,
  safeSmsHref,
} from "./sms-verification-card";

const base = {
  shortcode: "144773",
  smsText: "482916",
  instruction: 'Та өөрийн 99001122 дугаараас 144773 дугаарт "482916" гэж SMS илгээнэ үү.',
  smsUri: "sms:144773?body=482916",
};

describe("safeSmsHref", () => {
  it("keeps sms: and smsto: links", () => {
    expect(safeSmsHref("sms:144773?body=1")).toBe("sms:144773?body=1");
    expect(safeSmsHref(" SMSTO:144773 ")).toBe("SMSTO:144773");
  });

  it("drops any other scheme or an empty value", () => {
    expect(safeSmsHref("javascript:alert(1)")).toBeNull();
    expect(safeSmsHref("https://evil.example")).toBeNull();
    expect(safeSmsHref("")).toBeNull();
    expect(safeSmsHref(null)).toBeNull();
  });
});

describe("<SmsVerificationCard>", () => {
  it("shows the short code, the text and the provider's instruction unchanged", () => {
    render(<SmsVerificationCard {...base} status="PENDING" />);
    expect(screen.getByText("144773")).toBeInTheDocument();
    expect(screen.getByText("482916")).toBeInTheDocument();
    expect(screen.getByText(base.instruction)).toBeInTheDocument();
    expect(screen.getByText(SMS_COPY.waiting)).toBeInTheDocument();
  });

  it("offers an SMS link while waiting", () => {
    render(<SmsVerificationCard {...base} status="PENDING" />);
    expect(screen.getByRole("link", { name: SMS_COPY.sendSms })).toHaveAttribute(
      "href",
      "sms:144773?body=482916",
    );
  });

  it("never turns an unsafe link into a href", () => {
    render(
      <SmsVerificationCard {...base} smsUri="javascript:alert(1)" status="PENDING" />,
    );
    expect(screen.queryByRole("link")).toBeNull();
  });

  it("says the phone is confirmed once verified", () => {
    render(<SmsVerificationCard {...base} status="VERIFIED" />);
    expect(screen.getByText(SMS_COPY.verified)).toBeInTheDocument();
    expect(screen.queryByRole("link")).toBeNull();
  });

  it("asks for a new code when the old one expired", async () => {
    const onNewCode = vi.fn();
    render(
      <SmsVerificationCard {...base} status="EXPIRED" onNewCode={onNewCode} />,
    );
    expect(screen.getByRole("alert")).toHaveTextContent(SMS_COPY.expiredTitle);
    expect(screen.queryByRole("link")).toBeNull();
    await userEvent.click(screen.getByRole("button", { name: SMS_COPY.newCode }));
    expect(onNewCode).toHaveBeenCalledOnce();
  });

  it("does not offer a second new code while one is being made", () => {
    render(
      <SmsVerificationCard {...base} status="EXPIRED" onNewCode={() => {}} newCodeBusy />,
    );
    expect(screen.getByRole("button", { name: SMS_COPY.newCode })).toBeDisabled();
  });
});
