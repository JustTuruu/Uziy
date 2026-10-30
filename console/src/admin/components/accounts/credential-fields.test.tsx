import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useState } from "react";
import { describe, expect, it } from "vitest";
import { TEMP_PASSWORD_LENGTH, type AccountCredentials } from "@admin/lib/account-form";
import { CredentialFields } from "./credential-fields";

function Harness() {
  const [value, setValue] = useState<AccountCredentials>({ phoneNumber: "", password: "" });
  return <CredentialFields value={value} onChange={(p) => setValue((v) => ({ ...v, ...p }))} />;
}

describe("CredentialFields", () => {
  it("keeps only the phone's eight digits", async () => {
    render(<Harness />);
    await userEvent.type(screen.getByLabelText("Утасны дугаар"), "88-11 22a33");
    expect(screen.getByLabelText("Утасны дугаар")).toHaveValue("88112233");
  });

  it("suggests a temporary password on request", async () => {
    render(<Harness />);
    await userEvent.click(screen.getByRole("button", { name: "Нууц үг үүсгэх" }));
    expect((screen.getByLabelText(/^Түр нууц үг/) as HTMLInputElement).value).toHaveLength(
      TEMP_PASSWORD_LENGTH,
    );
  });
});
