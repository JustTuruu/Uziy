"use client";

import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";
import {
  Banknote,
  Bell,
  LayoutDashboard,
  Percent,
  PlaySquare,
  Users,
  Wallet,
} from "lucide-react";
import {
  ContentShell,
  PageContainer,
  Sidebar,
  SidebarUser,
  Topbar,
  type NavItem,
} from "@uziy/ui";
import { adminApi, auth, useStoredUser } from "@/lib/api";
import { formatPhone } from "@/lib/utils";

/** Sidebar entries; the badges are the live pending counts from the backend. */
function buildNav(pendingPayouts: number, pendingCampaigns: number): NavItem[] {
  return [
    {
      href: "/",
      label: "Хяналтын самбар",
      icon: <LayoutDashboard size={16} />,
      section: "Ерөнхий",
    },
    {
      href: "/payouts",
      label: "Мөнгө татах",
      icon: <Wallet size={16} />,
      badge: pendingPayouts,
      section: "Хяналт",
    },
    {
      href: "/campaigns",
      label: "Кампани модераци",
      icon: <PlaySquare size={16} />,
      badge: pendingCampaigns,
    },
    {
      href: "/users",
      label: "Хэрэглэгчид",
      icon: <Users size={16} />,
    },
    {
      href: "/finance",
      label: "Санхүү",
      icon: <Banknote size={16} />,
      section: "Тохиргоо",
    },
    {
      href: "/pricing",
      label: "Шимтгэл",
      icon: <Percent size={16} />,
    },
  ];
}

export default function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const phone = useStoredUser()?.phoneNumber ?? null;
  const [pendingPayouts, setPendingPayouts] = useState(0);
  const [pendingCampaigns, setPendingCampaigns] = useState(0);
  useEffect(() => {
    // Best effort: the badges are decoration, each page handles auth errors itself.
    adminApi
      .stats()
      .then((st) => {
        setPendingPayouts(st.pendingPayouts);
        setPendingCampaigns(st.pendingCampaigns);
      })
      .catch(() => {});
  }, []);
  const nav = buildNav(pendingPayouts, pendingCampaigns);

  const pending = pendingPayouts + pendingCampaigns;

  return (
    <div>
      <Sidebar
        brand="Uziy"
        subtitle="Админ"
        items={nav}
        footer={
          <SidebarUser
            initials="SA"
            name="Супер Админ"
            detail={phone ? `+976 ${formatPhone(phone)}` : "—"}
            onLogout={() => auth.clear()}
          />
        }
      />
      <ContentShell>
        <Topbar
          items={nav}
          pathname={pathname}
          right={
            <>
              <span className="hidden items-center gap-1.5 rounded-full border border-[var(--color-divider)] bg-[var(--color-surface)] px-2.5 py-1 text-[11px] font-medium text-[var(--color-text-secondary)] sm:inline-flex">
                <span className="h-1.5 w-1.5 rounded-full bg-[var(--color-success)] shadow-[0_0_6px_var(--color-success)]" />
                Систем хэвийн
              </span>
              <span
                className="relative inline-flex h-8 w-8 items-center justify-center rounded-lg border border-[var(--color-divider)] bg-[var(--color-surface)] text-[var(--color-text-secondary)]"
                title={`${pending} хүлээгдэж буй`}
                role="img"
                aria-label={`${pending} хүлээгдэж буй`}
              >
                <Bell size={15} />
                {pending > 0 && (
                  <span className="absolute -right-1 -top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-[var(--color-primary)] px-1 text-[9px] font-bold text-[#14110a]">
                    {pending}
                  </span>
                )}
              </span>
            </>
          }
        />
        <PageContainer>{children}</PageContainer>
      </ContentShell>
    </div>
  );
}
