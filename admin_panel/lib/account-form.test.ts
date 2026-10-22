import { describe, expect, it } from "vitest";
import {
  ACCOUNT_FORM_COPY,
  TEMP_PASSWORD_LENGTH,
  companyFormError,
  credentialsError,
  generateTempPassword,
  phoneDigits,
} from "./account-form";

const ok = { companyName: "MobiCom", phoneNumber: "88112233", password: "temp-pass1" };

describe("companyFormError", () => {
  it("accepts a complete form", () => {
    expect(companyFormError(ok)).toBeNull();
  });

  it("names the first problem in Mongolian", () => {
    expect(companyFormError({ ...ok, companyName: "  " })).toBe(ACCOUNT_FORM_COPY.nameRequired);
    expect(companyFormError({ ...ok, companyName: "x".repeat(121) })).toBe(ACCOUNT_FORM_COPY.nameTooLong);
    expect(companyFormError({ ...ok, phoneNumber: "8811223" })).toBe(ACCOUNT_FORM_COPY.phone);
    expect(companyFormError({ ...ok, password: "12345" })).toBe(ACCOUNT_FORM_COPY.passwordLength);
  });

  it("refuses a password BCrypt could not read in full", () => {
    // 37 Cyrillic letters: under 100 characters, over 72 bytes.
    expect(companyFormError({ ...ok, password: "ө".repeat(37) })).toBe(ACCOUNT_FORM_COPY.passwordTooLong);
  });
});

describe("credentialsError (the admin form uses it alone)", () => {
  const creds = { phoneNumber: "88112233", password: "temp-pass1" };

  it("accepts a phone and a temporary password with no company name", () => {
    expect(credentialsError(creds)).toBeNull();
  });

  it("names the first problem in Mongolian", () => {
    expect(credentialsError({ ...creds, phoneNumber: "881122334" })).toBe(ACCOUNT_FORM_COPY.phone);
    expect(credentialsError({ ...creds, password: "x".repeat(101) })).toBe(ACCOUNT_FORM_COPY.passwordLength);
    expect(credentialsError({ ...creds, password: "ө".repeat(37) })).toBe(ACCOUNT_FORM_COPY.passwordTooLong);
  });
});

describe("phoneDigits", () => {
  it("keeps at most eight digits and drops everything else", () => {
    expect(phoneDigits("8811-22 33")).toBe("88112233");
    expect(phoneDigits("+976 88112233")).toBe("97688112");
    expect(phoneDigits("abc")).toBe("");
  });
});

describe("generateTempPassword", () => {
  it("is long enough and passes the form's own rules", () => {
    const password = generateTempPassword();
    expect(password).toHaveLength(TEMP_PASSWORD_LENGTH);
    expect(companyFormError({ ...ok, password })).toBeNull();
  });

  it("never uses look-alike characters", () => {
    const all = Array.from({ length: 50 }, () => generateTempPassword()).join("");
    expect(all).not.toMatch(/[0O1lI]/);
  });

  it("maps the random values onto the alphabet", () => {
    expect(generateTempPassword((into) => into.fill(0))).toBe("a".repeat(TEMP_PASSWORD_LENGTH));
  });
});
