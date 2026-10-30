// The admin's "Компани нэмэх" and "Админ нэмэх" forms: what they check before sending, and the temporary password
// they can suggest. Both open an account from a phone + temporary password; a company also has a name.

export interface AccountCredentials {
  phoneNumber: string;
  password: string;
}

export interface CompanyForm extends AccountCredentials {
  companyName: string;
}

/** Same limits as the backend's CreateCompanyReq / CreateAdminReq. */
export const COMPANY_NAME_MAX = 120;
export const PHONE_DIGITS = 8;
export const PASSWORD_MIN = 6;
export const PASSWORD_MAX = 100;
/** BCrypt reads at most 72 bytes; a longer password would be refused by the backend. */
export const PASSWORD_MAX_BYTES = 72;
export const TEMP_PASSWORD_LENGTH = 10;

/** No 0/O, 1/l/I: the password is read out or typed from a note, so look-alikes cause failed logins. */
const TEMP_PASSWORD_ALPHABET = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789";

const PHONE_PATTERN = new RegExp(`^\\d{${PHONE_DIGITS}}$`);

export const ACCOUNT_FORM_COPY = {
  nameRequired: "Компанийн нэрээ оруулна уу",
  nameTooLong: "Компанийн нэр хэт урт байна",
  phone: "Утасны дугаар 8 оронтой тоо байх ёстой",
  passwordLength: "Нууц үг 6–100 тэмдэгт байх ёстой",
  passwordTooLong: "Нууц үг хэт урт байна, богиносгоно уу",
} as const;

/** The first problem with the phone and temporary password, worded for the admin, or null when they can be sent. */
export function credentialsError(form: AccountCredentials): string | null {
  if (!PHONE_PATTERN.test(form.phoneNumber)) return ACCOUNT_FORM_COPY.phone;
  if (form.password.length < PASSWORD_MIN || form.password.length > PASSWORD_MAX) {
    return ACCOUNT_FORM_COPY.passwordLength;
  }
  if (new TextEncoder().encode(form.password).length > PASSWORD_MAX_BYTES) {
    return ACCOUNT_FORM_COPY.passwordTooLong;
  }
  return null;
}

/** The first problem with the company form (name first, then the credentials), or null when it can be sent. */
export function companyFormError(form: CompanyForm): string | null {
  const name = form.companyName.trim();
  if (!name) return ACCOUNT_FORM_COPY.nameRequired;
  if (name.length > COMPANY_NAME_MAX) return ACCOUNT_FORM_COPY.nameTooLong;
  return credentialsError(form);
}

/** Keeps only digits, at most a phone number's worth, as the admin types. */
export function phoneDigits(input: string): string {
  return input.replace(/\D/g, "").slice(0, PHONE_DIGITS);
}

/**
 * A random temporary password from a cryptographic source. {@code randomInts} is injectable for tests; it must
 * fill the array with uniformly random 32-bit values.
 */
export function generateTempPassword(
  randomInts: (into: Uint32Array) => Uint32Array = (into) => crypto.getRandomValues(into),
): string {
  const values = randomInts(new Uint32Array(TEMP_PASSWORD_LENGTH));
  return Array.from(values, (v) => TEMP_PASSWORD_ALPHABET[v % TEMP_PASSWORD_ALPHABET.length]).join("");
}
