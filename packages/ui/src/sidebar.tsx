"use client";

import { LogOut } from "lucide-react";
import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";
import { cn } from "./cn";

export interface NavItem {
  href: string;
  label: string;
  icon: ReactNode;
  badge?: number;
  /** Group heading shown above this item (and the items after it). */
  section?: string;
}

interface Props {
  brand: string;
  subtitle: string;
  items: NavItem[];
  footer?: ReactNode;
}

export function isActive(pathname: string, href: string): boolean {
  return (
    pathname === href || (href !== "/" && pathname.startsWith(href + "/"))
  );
}

export function Sidebar({ brand, subtitle, items, footer }: Props) {
  const pathname = usePathname();

  return (
    <aside className="fixed inset-y-0 left-0 z-30 flex w-60 flex-col border-r border-[var(--color-divider)] bg-[color-mix(in_oklab,var(--color-surface)_92%,black)]">
      <div className="flex h-14 items-center gap-2.5 border-b border-[var(--color-divider)] px-4">
        <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-white shadow-[0_0_0_1px_rgb(255_255_255/0.08)]">
          <Image
            src="/logo.png"
            alt="Uziy"
            width={32}
            height={32}
            className="h-6 w-6 object-contain"
          />
        </div>
        <div className="flex min-w-0 items-baseline gap-2">
          <span className="text-[15px] font-bold tracking-tight text-[var(--color-text-primary)]">
            {brand}
          </span>
          <span className="truncate rounded border border-[var(--color-border-strong)] px-1.5 py-px text-[10px] font-semibold uppercase tracking-wider text-[var(--color-text-secondary)]">
            {subtitle}
          </span>
        </div>
      </div>

      <nav className="flex-1 overflow-y-auto px-3 py-4">
        {items.map((item, i) => {
          const active = isActive(pathname, item.href);
          return (
            <div key={item.href}>
              {item.section && (
                <div
                  className={cn(
                    "px-2.5 pb-1.5 text-[10px] font-semibold uppercase tracking-[0.12em] text-[var(--color-text-muted)]",
                    i === 0 ? "pt-0" : "pt-5",
                  )}
                >
                  {item.section}
                </div>
              )}
              <Link
                href={item.href}
                aria-current={active ? "page" : undefined}
                className={cn(
                  "group relative mb-0.5 flex items-center justify-between gap-3 rounded-lg px-2.5 py-2 text-[13px] transition-colors",
                  active
                    ? "bg-[var(--color-surface-elevated)] text-[var(--color-text-primary)]"
                    : "text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-elevated)]/60 hover:text-[var(--color-text-primary)]",
                )}
              >
                {active && (
                  <span className="absolute -left-3 top-1/2 h-5 w-[3px] -translate-y-1/2 rounded-r-full bg-[var(--color-primary)]" />
                )}
                <span className="flex items-center gap-2.5">
                  <span
                    className={cn(
                      "flex h-4 w-4 items-center justify-center",
                      active
                        ? "text-[var(--color-primary)]"
                        : "text-[var(--color-text-muted)] group-hover:text-[var(--color-text-secondary)]",
                    )}
                  >
                    {item.icon}
                  </span>
                  <span className={cn("font-medium", active && "font-semibold")}>
                    {item.label}
                  </span>
                </span>
                {item.badge !== undefined && item.badge > 0 && (
                  <span className="inline-flex h-[18px] min-w-[18px] items-center justify-center rounded-full bg-[color-mix(in_oklab,var(--color-primary)_16%,transparent)] px-1.5 text-[10px] font-bold tabular-nums text-[var(--color-primary)]">
                    {item.badge}
                  </span>
                )}
              </Link>
            </div>
          );
        })}
      </nav>

      {footer && (
        <div className="border-t border-[var(--color-divider)] p-3">
          {footer}
        </div>
      )}
    </aside>
  );
}

/** Sticky top bar: breadcrumb on the left, status + actions on the right. */
export function Topbar({
  items,
  pathname,
  right,
}: {
  items: NavItem[];
  pathname: string;
  right?: ReactNode;
}) {
  const current = items.find((i) => isActive(pathname, i.href));
  const sub = current && pathname !== current.href;
  return (
    <header className="sticky top-0 z-20 flex h-14 items-center justify-between gap-4 border-b border-[var(--color-divider)] bg-[color-mix(in_oklab,var(--color-background)_80%,transparent)] px-8 backdrop-blur-md">
      <nav
        aria-label="Breadcrumb"
        className="flex items-center gap-2 text-[13px] text-[var(--color-text-muted)]"
      >
        <span>Uziy</span>
        <span aria-hidden>/</span>
        <span
          className={
            sub
              ? undefined
              : "font-semibold text-[var(--color-text-primary)]"
          }
        >
          {current?.label ?? "—"}
        </span>
        {sub && (
          <>
            <span aria-hidden>/</span>
            <span className="font-semibold text-[var(--color-text-primary)]">
              Дэлгэрэнгүй
            </span>
          </>
        )}
      </nav>
      <div className="flex items-center gap-3">{right}</div>
    </header>
  );
}

export function ContentShell({ children }: { children: ReactNode }) {
  return (
    <main className="ml-60 min-h-screen">{children}</main>
  );
}

export function PageContainer({ children }: { children: ReactNode }) {
  return <div className="mx-auto max-w-7xl px-8 py-8">{children}</div>;
}

/** Signed-in user card for the sidebar footer, with a logout link. */
export function SidebarUser({
  initials,
  name,
  detail,
  onLogout,
  logoutHref = "/login",
}: {
  initials: string;
  name: string;
  detail: string;
  onLogout?: () => void;
  logoutHref?: string;
}) {
  return (
    <div className="flex items-center justify-between gap-2 rounded-lg p-1.5">
      <div className="flex min-w-0 items-center gap-2.5">
        <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-[var(--color-primary)] to-[#b8860b] text-[11px] font-bold text-[#14110a]">
          {initials}
        </div>
        <div className="min-w-0">
          <div className="truncate text-xs font-semibold text-[var(--color-text-primary)]">
            {name}
          </div>
          <div className="truncate text-[11px] text-[var(--color-text-muted)]">
            {detail}
          </div>
        </div>
      </div>
      <a
        href={logoutHref}
        onClick={onLogout}
        className="rounded-md p-1.5 text-[var(--color-text-muted)] transition-colors hover:bg-[var(--color-surface-elevated)] hover:text-[var(--color-text-primary)]"
        title="Гарах"
        aria-label="Гарах"
      >
        <LogOut size={15} />
      </a>
    </div>
  );
}
