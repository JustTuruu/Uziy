import { MessageSquare, RefreshCw } from "lucide-react";
import { Button, ButtonLink } from "./button";
import { cn } from "./cn";

/** Where a phone check stands, as the backend's `GET /auth/phone-verifications/{id}` says. */
export type SmsVerificationStatus = "PENDING" | "VERIFIED" | "EXPIRED";

/** The only link schemes "SMS илгээх" may open; the link comes from the provider, so anything else is dropped. */
const SMS_SCHEMES = ["sms:", "smsto:"];

/** The provider's SMS link, or null when it is not an `sms:` link (a `javascript:` URL must never become a href). */
export function safeSmsHref(uri: string | null | undefined): string | null {
  if (!uri) return null;
  const trimmed = uri.trim();
  const lower = trimmed.toLowerCase();
  return SMS_SCHEMES.some((scheme) => lower.startsWith(scheme)) ? trimmed : null;
}

/** Same wording as the viewer app's phone check (viewer_app phone_verify_logic.dart). */
export const SMS_COPY = {
  sendSms: "SMS илгээх",
  smsTo: "Хүлээн авах дугаар",
  smsText: "Текст",
  price: "SMS-ийн төлбөр 150₮ (операторын үнэ). Нэг удаа илгээхэд хангалттай.",
  waiting: "Таны SMS-ийг хүлээж байна…",
  verified: "Утас баталгаажлаа…",
  expiredTitle: "Кодын хугацаа дууслаа",
  expiredBody: "Хуучин код хүчингүй боллоо. Шинэ код аваад дахин илгээнэ үү.",
  newCode: "Шинэ код авах",
} as const;

interface SmsVerificationCardProps {
  shortcode: string;
  smsText: string;
  /** The provider's own instruction; shown unchanged (it names the phone to send from). */
  instruction: string;
  smsUri?: string | null;
  status: SmsVerificationStatus;
  /** Shown when the check expired; opens a new check. */
  onNewCode?: () => void;
  newCodeBusy?: boolean;
  className?: string;
}

/**
 * The "text this code from your phone" step (verify.mn, short code 144773): the code and where to send it, the
 * provider's instruction, an "SMS илгээх" link for phones, and the live state of the check.
 */
export function SmsVerificationCard({
  shortcode,
  smsText,
  instruction,
  smsUri,
  status,
  onNewCode,
  newCodeBusy = false,
  className,
}: SmsVerificationCardProps) {
  const href = safeSmsHref(smsUri);
  const expired = status === "EXPIRED";
  return (
    <div
      className={cn(
        "rounded-xl border border-[var(--color-divider)] bg-[var(--color-surface)] p-4",
        className,
      )}
    >
      <dl className={cn("grid grid-cols-2 gap-3", expired && "opacity-50")}>
        <CodeField label={SMS_COPY.smsTo} value={shortcode} />
        <CodeField label={SMS_COPY.smsText} value={smsText} />
      </dl>
      <p className="mt-3 text-xs text-[var(--color-text-secondary)]">
        {instruction}
      </p>

      {expired ? (
        <div className="mt-4" role="alert">
          <div className="text-ui font-semibold text-[var(--color-danger)]">
            {SMS_COPY.expiredTitle}
          </div>
          <p className="mt-0.5 text-xs text-[var(--color-text-secondary)]">
            {SMS_COPY.expiredBody}
          </p>
          {onNewCode && (
            <Button
              type="button"
              variant="secondary"
              className="mt-3 w-full"
              onClick={onNewCode}
              disabled={newCodeBusy}
              leftIcon={<RefreshCw size={14} />}
            >
              {SMS_COPY.newCode}
            </Button>
          )}
        </div>
      ) : (
        <>
          {href && status === "PENDING" && (
            <ButtonLink
              href={href}
              className="mt-4 w-full"
              leftIcon={<MessageSquare size={14} />}
            >
              {SMS_COPY.sendSms}
            </ButtonLink>
          )}
          <p
            className="mt-3 text-xs text-[var(--color-text-muted)]"
            aria-live="polite"
          >
            {status === "VERIFIED" ? SMS_COPY.verified : SMS_COPY.waiting}
          </p>
          <p className="mt-1 text-2xs text-[var(--color-text-muted)]">
            {SMS_COPY.price}
          </p>
        </>
      )}
    </div>
  );
}

function CodeField({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-2xs font-semibold uppercase tracking-wider text-[var(--color-text-secondary)]">
        {label}
      </dt>
      <dd className="mt-1 font-mono text-xl font-semibold tabular-nums tracking-wider text-[var(--color-text-primary)]">
        {value}
      </dd>
    </div>
  );
}
