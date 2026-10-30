import { KeyRound } from "lucide-react";
import { Button, Input } from "@uziy/ui";
import {
  PASSWORD_MAX,
  PHONE_DIGITS,
  generateTempPassword,
  phoneDigits,
  type AccountCredentials,
} from "@admin/lib/account-form";

/**
 * The phone + temporary password half of every "open an account" form (companies, admins), so both look and
 * behave the same: digits only, and a suggested password on request.
 */
export function CredentialFields({
  value,
  onChange,
}: {
  value: AccountCredentials;
  onChange: (patch: Partial<AccountCredentials>) => void;
}) {
  return (
    <>
      <Input
        label="Утасны дугаар"
        inputMode="numeric"
        maxLength={PHONE_DIGITS}
        placeholder="8 оронтой дугаар"
        value={value.phoneNumber}
        onChange={(e) => onChange({ phoneNumber: phoneDigits(e.target.value) })}
      />
      <div>
        <Input
          label="Түр нууц үг"
          autoComplete="off"
          maxLength={PASSWORD_MAX}
          hint="Хамгийн багадаа 6 тэмдэгт"
          value={value.password}
          onChange={(e) => onChange({ password: e.target.value })}
        />
        <Button
          type="button"
          size="sm"
          variant="ghost"
          className="mt-1"
          leftIcon={<KeyRound size={12} />}
          onClick={() => onChange({ password: generateTempPassword() })}
        >
          Нууц үг үүсгэх
        </Button>
      </div>
    </>
  );
}
