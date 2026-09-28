import {
  BarChart3,
  CreditCard,
  LayoutDashboard,
  LogOut,
  PlaySquare,
  Settings,
} from "lucide-react";
import { ContentShell, Sidebar, type NavItem } from "@/components/sidebar";

const nav: NavItem[] = [
  {
    href: "/company",
    label: "Хяналтын самбар",
    icon: <LayoutDashboard size={18} />,
  },
  {
    href: "/company/campaigns",
    label: "Кампаниуд",
    icon: <PlaySquare size={18} />,
  },
  {
    href: "/company/analytics",
    label: "Аналитик",
    icon: <BarChart3 size={18} />,
  },
  {
    href: "/company/billing",
    label: "Төлбөр",
    icon: <CreditCard size={18} />,
  },
  {
    href: "/company/settings",
    label: "Тохиргоо",
    icon: <Settings size={18} />,
  },
];

export default function CompanyLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div>
      <Sidebar
        brand="Uziy"
        subtitle="Компанийн самбар"
        items={nav}
        footer={
          <div className="flex items-center justify-between">
            <div className="min-w-0">
              <div className="truncate text-xs font-semibold text-[var(--color-text-primary)]">
                MobiCom
              </div>
              <div className="truncate text-[10px] text-[var(--color-text-muted)]">
                +976 8811 2233
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
