"use client";

import { usePathname } from "next/navigation";
import {
  BarChart3,
  CreditCard,
  LayoutDashboard,
  PlaySquare,
  Settings,
} from "lucide-react";
import {
  ContentShell,
  PageContainer,
  Sidebar,
  SidebarUser,
  Topbar,
  type NavItem,
} from "@uziy/ui";
import { auth, useStoredUser } from "@/lib/api";
import { formatPhone } from "@/lib/utils";

const nav: NavItem[] = [
  {
    href: "/",
    label: "Хяналтын самбар",
    icon: <LayoutDashboard size={16} />,
  },
  {
    href: "/campaigns",
    label: "Судалгаа",
    icon: <PlaySquare size={16} />,
  },
  {
    href: "/analytics",
    label: "Аналитик",
    icon: <BarChart3 size={16} />,
  },
  {
    href: "/billing",
    label: "Төлбөр",
    icon: <CreditCard size={16} />,
  },
  {
    href: "/settings",
    label: "Тохиргоо",
    icon: <Settings size={16} />,
  },
];

export default function CompanyLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const me = useStoredUser();

  return (
    <div>
      <Sidebar
        brand="Uziy"
        subtitle={me?.companyName || "Компани"}
        items={nav}
        footer={
          <SidebarUser
            initials={(me?.companyName || "К").slice(0, 2).toUpperCase()}
            name={me?.companyName || "Компани"}
            detail={me ? `+976 ${formatPhone(me.phoneNumber)}` : "—"}
            onLogout={() => auth.clear()}
          />
        }
      />
      <ContentShell>
        <Topbar items={nav} pathname={pathname} />
        <PageContainer>{children}</PageContainer>
      </ContentShell>
    </div>
  );
}
