import { useEffect, useState } from "react";
import { SidebarLink, usePathname } from "@shared/navigation";
import {
  Banknote,
  BarChart3,
  Bell,
  Building2,
  LayoutDashboard,
  Percent,
  PlaySquare,
  ShieldCheck,
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
import { adminApi, auth, useStoredUser } from "@admin/lib/api";
import { formatPhone } from "@admin/lib/utils";

/** Sidebar entries; the badges are the live pending counts from the backend. */
function buildNav(pendingPayouts: number, pendingCampaigns: number): NavItem[] {
  return [
    {
      href: "/admin",
      exact: true,
      label: "Хяналтын самбар",
      icon: <LayoutDashboard size={16} />,
      section: "Ерөнхий",
    },
    {
      href: "/admin/payouts",
      label: "Мөнгө татах",
      icon: <Wallet size={16} />,
      badge: pendingPayouts,
      section: "Хяналт",
    },
    {
      href: "/admin/campaigns",
      label: "Судалгаа",
      icon: <PlaySquare size={16} />,
      badge: pendingCampaigns,
    },
    {
      href: "/admin/users",
      label: "Хэрэглэгчид",
      icon: <Users size={16} />,
    },
    {
      href: "/admin/companies",
      label: "Компаниуд",
      icon: <Building2 size={16} />,
    },
    {
      href: "/admin/insights",
      label: "Статистик",
      icon: <BarChart3 size={16} />,
    },
    {
      href: "/admin/finance",
      label: "Санхүү",
      icon: <Banknote size={16} />,
      section: "Тохиргоо",
    },
    {
      href: "/admin/pricing",
      label: "Шимтгэл",
      icon: <Percent size={16} />,
    },
    {
      href: "/admin/admins",
      label: "Админууд",
      icon: <ShieldCheck size={16} />,
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
        pathname={pathname}
        linkComponent={SidebarLink}
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
              <span className="hidden items-center gap-1.5 rounded-full border border-[var(--color-divider)] bg-[var(--color-surface)] px-2.5 py-1 text-2xs font-medium text-[var(--color-text-secondary)] sm:inline-flex">
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
                  <span className="absolute -right-1 -top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-[var(--color-primary)] px-1 text-4xs font-bold text-[var(--color-on-primary)]">
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
