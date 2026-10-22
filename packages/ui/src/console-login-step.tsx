"use client";

import { ArrowLeft } from "lucide-react";
import { Button } from "./button";
import { cn } from "./cn";
import { CONSOLE_LOGIN_COPY, type SmsStep } from "./console-login";
import { SmsVerificationCard } from "./sms-verification-card";

/** A form's error, announced to screen readers. */
export function FormError({ message, className }: { message: string; className?: string }) {
  return (
    <div
      role="alert"
      className={cn(
        "rounded-lg border border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] px-3 py-2 text-xs text-[var(--color-danger)]",
        className,
      )}
    >
      {message}
    </div>
  );
}

interface ConsoleSmsStepProps {
  step: SmsStep;
  onNewCode: () => void;
  newCodeBusy: boolean;
  notice: string | null;
  error: string | null;
  onBack: () => void;
}

/**
 * The console login's second step: which phone must text what (`SmsVerificationCard`), that this browser will then
 * be remembered, and a way back to the password form. Used by both panels' login pages.
 */
export function ConsoleSmsStep({
  step,
  onNewCode,
  newCodeBusy,
  notice,
  error,
  onBack,
}: ConsoleSmsStepProps) {
  const { challenge, status } = step;
  return (
    <>
      <h1 className="text-2xl font-semibold tracking-tight">{CONSOLE_LOGIN_COPY.title}</h1>
      <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
        {CONSOLE_LOGIN_COPY.subtitle(challenge.phoneNumber)}
      </p>
      <SmsVerificationCard
        className="mt-6"
        shortcode={challenge.shortcode}
        smsText={challenge.smsText}
        instruction={challenge.displayInstruction}
        smsUri={challenge.smsUri}
        status={status}
        onNewCode={onNewCode}
        newCodeBusy={newCodeBusy}
      />
      <p className="mt-3 text-xs text-[var(--color-text-muted)]">
        {CONSOLE_LOGIN_COPY.deviceRemembered}
      </p>
      {notice && (
        <p className="mt-3 text-xs text-[var(--color-text-secondary)]" role="status">
          {notice}
        </p>
      )}
      {error && <FormError className="mt-4" message={error} />}
      <Button
        type="button"
        variant="ghost"
        className="mt-4 w-full"
        leftIcon={<ArrowLeft size={14} />}
        onClick={onBack}
      >
        {CONSOLE_LOGIN_COPY.back}
      </Button>
    </>
  );
}
