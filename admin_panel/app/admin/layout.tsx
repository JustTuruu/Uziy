import {
  Banknote,
  LayoutDashboard,
  LogOut,
  PlaySquare,
  ShieldCheck,
  Users,
  Wallet,
} from "lucide-react";
import { ContentShell, Sidebar, type NavItem } from "@/components/sidebar";
import { platformStats } from "@/lib/mock-data";

const nav: NavItem[] = [
  {
    href: "/admin",
    label: "Хяналтын самбар",
    icon: <LayoutDashboard size={18} />,
  },
  {
    href: "/admin/payouts",
    label: "Мөнгө татах",
    icon: <Wallet size={18} />,
    badge: platformStats.pendingPayouts,
  },
  {
    href: "/admin/campaigns",
    label: "Кампани модераци",
    icon: <PlaySquare size={18} />,
    badge: platformStats.pendingCampaigns,
  },
  {
    href: "/admin/users",
    label: "Хэрэглэгчид",
    icon: <Users size={18} />,
  },
  {
    href: "/admin/finance",
    label: "Санхүү",
    icon: <Banknote size={18} />,
  },
];

export default function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div>
      <Sidebar
        brand="Zoos"
        subtitle="Супер Админ"
        items={nav}
        footer={
          <div className="flex items-center justify-between">
            <div className="flex min-w-0 items-center gap-2">
              <ShieldCheck
                size={16}
                className="text-[var(--color-primary)]"
              />
              <div className="min-w-0">
                <div className="truncate text-xs font-semibold text-[var(--color-text-primary)]">
                  Админ
                </div>
                <div className="truncate text-[10px] text-[var(--color-text-muted)]">
                  +976 9999 0000
                </div>
              </div>
            </div>
            <a
              href="/login"
              className="text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)]"
              title="Гарах"
            >
              <LogOut size={16} />
            </a>
          </div>
        }
      />
      <ContentShell>{children}</ContentShell>
    </div>
  );
}
