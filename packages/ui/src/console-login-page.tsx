"use client";

import type { ReactNode } from "react";
import { Button } from "./button";
import { CONSOLE_LOGIN_COPY, type ConsoleLogin } from "./console-login";
import { ConsoleSmsStep, FormError } from "./console-login-step";
import { Input } from "./input";

/** One selling point on the brand panel. */
export interface LoginHighlight {
  icon: ReactNode;
  title: string;
  text: string;
}

export interface ConsoleLoginPageProps {
  /** State from {@link useConsoleLogin}: the password step, then the SMS step. */
  login: ConsoleLogin;
  /** The app's logo image (each app serves its own file). */
  logo: ReactNode;
  /** Which console this is, e.g. 'Компанийн самбар'. */
  consoleName: string;
  headline: ReactNode;
  lead: string;
  highlights: readonly LoginHighlight[];
  /** The form card's heading and the line under it. */
  title: string;
  subtitle: string;
  /** Under the form card, e.g. how to get an account. */
  note?: ReactNode;
}

export const CONSOLE_LOGIN_FOOTER = { copyright: "© 2026 Uziy", support: "support@uziy.mn" } as const;

function Brand({ logo, consoleName }: { logo: ReactNode; consoleName: string }) {
  return (
    <div className="flex items-center gap-3">
      <div className="flex h-10 w-10 items-center justify-center rounded-xl border border-[var(--color-divider)] bg-[var(--color-surface)] shadow-[var(--shadow-card)]">
        {logo}
      </div>
      <div className="leading-tight">
        <div className="text-lg font-bold tracking-tight">Uziy</div>
        <div className="text-2xs font-medium text-[var(--color-text-muted)]">{consoleName}</div>
      </div>
    </div>
  );
}

/**
 * The sign-in page both consoles share: a brand panel (what the console is for) beside a form card. Each app only
 * supplies its words, logo and role check, so the two pages cannot drift apart.
 * Pattern: Template — fixed layout, app-specific content slots.
 */
export function ConsoleLoginPage({
  login,
  logo,
  consoleName,
  headline,
  lead,
  highlights,
  title,
  subtitle,
  note,
}: ConsoleLoginPageProps) {
  return (
    <div className="grid min-h-screen bg-[var(--color-background)] lg:grid-cols-[minmax(0,5fr)_minmax(0,6fr)]">
      <aside className="relative hidden flex-col justify-between overflow-hidden border-r border-[var(--color-divider)] bg-[var(--color-surface)] px-12 py-10 lg:flex xl:px-16">
        {/* Faint grid fading out from the copy, and one soft gold glow. Decoration only. */}
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0 opacity-70 [background-image:linear-gradient(var(--color-divider)_1px,transparent_1px),linear-gradient(90deg,var(--color-divider)_1px,transparent_1px)] [background-size:44px_44px] [mask-image:radial-gradient(ellipse_at_20%_45%,black,transparent_65%)]"
        />
        <div
          aria-hidden
          className="pointer-events-none absolute -bottom-40 -left-32 h-[28rem] w-[28rem] rounded-full bg-[var(--color-primary)] opacity-[0.08] blur-3xl"
        />

        <div className="relative">
          <Brand logo={logo} consoleName={consoleName} />
        </div>

        <div className="relative max-w-lg">
          <h2 className="text-4xl font-bold leading-[1.15] tracking-tight">{headline}</h2>
          <p className="mt-4 text-sm leading-relaxed text-[var(--color-text-secondary)]">{lead}</p>
          <ul className="mt-10 space-y-5">
            {highlights.map((h) => (
              <li key={h.title} className="flex gap-4">
                <span
                  aria-hidden
                  className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-[color-mix(in_oklab,var(--color-primary)_10%,transparent)] text-[var(--color-primary)]"
                >
                  {h.icon}
                </span>
                <div>
                  <div className="text-sm font-semibold">{h.title}</div>
                  <div className="mt-0.5 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                    {h.text}
                  </div>
                </div>
              </li>
            ))}
          </ul>
        </div>

        <div className="relative flex gap-6 text-xs text-[var(--color-text-muted)]">
          <span>{CONSOLE_LOGIN_FOOTER.copyright}</span>
          <a href={`mailto:${CONSOLE_LOGIN_FOOTER.support}`} className="hover:text-[var(--color-text-secondary)]">
            {CONSOLE_LOGIN_FOOTER.support}
          </a>
        </div>
      </aside>

      <main className="flex flex-col items-center justify-center px-5 py-12 sm:px-8">
        <div className="mb-8 lg:hidden">
          <Brand logo={logo} consoleName={consoleName} />
        </div>

        <div className="w-full max-w-[26rem] rounded-2xl border border-[var(--color-divider)] bg-[var(--color-surface)] p-7 shadow-[var(--shadow-card)] sm:p-9">
          {login.sms ? (
            <ConsoleSmsStep
              step={login.sms}
              onNewCode={login.newCode}
              newCodeBusy={login.loading}
              notice={login.notice}
              error={login.error}
              onBack={login.back}
            />
          ) : (
            <>
              <h1 className="text-2xl font-bold tracking-tight">{title}</h1>
              <p className="mt-1.5 text-sm text-[var(--color-text-secondary)]">{subtitle}</p>

              <form onSubmit={login.submit} noValidate className="mt-7 space-y-4">
                <Input
                  label="Утасны дугаар"
                  inputMode="numeric"
                  autoComplete="username"
                  maxLength={8}
                  placeholder="8 оронтой дугаар"
                  value={login.phone}
                  onChange={(e) => login.setPhone(e.target.value)}
                />
                <Input
                  label="Нууц үг"
                  type="password"
                  autoComplete="current-password"
                  value={login.password}
                  onChange={(e) => login.setPassword(e.target.value)}
                />
                {login.error && <FormError message={login.error} />}
                <Button type="submit" disabled={login.loading} className="w-full" size="lg">
                  {login.loading ? CONSOLE_LOGIN_COPY.signingIn : CONSOLE_LOGIN_COPY.submit}
                </Button>
              </form>
            </>
          )}
        </div>

        {note && (
          <div className="mt-6 max-w-[26rem] text-center text-xs leading-relaxed text-[var(--color-text-muted)]">
            {note}
          </div>
        )}
      </main>
    </div>
  );
}
