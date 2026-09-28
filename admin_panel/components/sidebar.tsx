"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

export interface NavItem {
  href: string;
  label: string;
  icon: ReactNode;
  badge?: number;
}

interface Props {
  brand: string;
  subtitle: string;
  items: NavItem[];
  footer?: ReactNode;
}

export function Sidebar({ brand, subtitle, items, footer }: Props) {
  const pathname = usePathname();

  return (
    <aside className="fixed inset-y-0 left-0 z-30 flex w-64 flex-col border-r border-[var(--color-divider)] bg-[var(--color-surface)]">
      <div className="flex items-center gap-3 border-b border-[var(--color-divider)] px-5 py-4">
        <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-white/95">
          <Image
            src="/logo.png"
            alt="Uziy"
            width={40}
            height={40}
            className="h-8 w-8 object-contain"
          />
        </div>
        <div>
          <div className="text-sm font-extrabold text-[var(--color-text-primary)]">
            {brand}
          </div>
          <div className="text-xs text-[var(--color-text-secondary)]">
            {subtitle}
          </div>
        </div>
      </div>

      <nav className="flex-1 space-y-0.5 overflow-y-auto px-3 py-4">
        {items.map((item) => {
          const active =
            pathname === item.href ||
            (item.href !== "/" && pathname.startsWith(item.href + "/"));
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center justify-between gap-3 rounded-lg px-3 py-2 text-sm transition-colors",
                active
                  ? "bg-[color-mix(in_oklab,var(--color-primary)_15%,transparent)] text-[var(--color-primary)]"
                  : "text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-elevated)] hover:text-[var(--color-text-primary)]",
              )}
            >
              <span className="flex items-center gap-3">
                <span
                  className={cn(
                    "flex h-5 w-5 items-center justify-center",
                    active
                      ? "text-[var(--color-primary)]"
                      : "text-[var(--color-text-muted)]",
                  )}
                >
                  {item.icon}
                </span>
                <span
                  className={cn("font-medium", active && "font-semibold")}
                >
                  {item.label}
                </span>
              </span>
              {item.badge !== undefined && item.badge > 0 && (
                <span className="inline-flex min-w-5 items-center justify-center rounded-full bg-[var(--color-danger)] px-1.5 text-[10px] font-bold text-white">
                  {item.badge}
                </span>
              )}
            </Link>
          );
        })}
      </nav>

      {footer && (
        <div className="border-t border-[var(--color-divider)] p-4">
          {footer}
        </div>
      )}
    </aside>
  );
}

export function ContentShell({ children }: { children: ReactNode }) {
  return (
    <main className="ml-64 min-h-screen">
      <div className="mx-auto max-w-7xl px-8 py-8">{children}</div>
    </main>
  );
}
