"use client";

import Image from "next/image";
import { useRouter } from "next/navigation";
import { ClipboardCheck, ShieldCheck, Wallet } from "lucide-react";
import { ConsoleLoginPage, useConsoleLogin, type LoginHighlight, type SignedIn } from "@uziy/ui";
import { auth, authApi, GENERIC_ERROR_MESSAGE, type Me } from "@/lib/api";

const NOT_ADMIN = "Энэ данс админ эрхгүй байна";

const HIGHLIGHTS: readonly LoginHighlight[] = [
  {
    icon: <ClipboardCheck size={18} />,
    title: "Судалгаа батлах",
    text: "Компаниудын илгээсэн судалгааг шалгаж, нийтэлнэ.",
  },
  {
    icon: <Wallet size={18} />,
    title: "Мөнгө татах хүсэлт",
    text: "Үзэгчдийн хүсэлтийг дансных нь мэдээлэлтэй тулгаж шийднэ.",
  },
  {
    icon: <ShieldCheck size={18} />,
    title: "Хоёр шаттай нэвтрэлт",
    text: "Нууц үгийн дараа бүртгэлтэй утаснаасаа SMS илгээж баталгаажуулна.",
  },
];

export default function LoginPage() {
  const router = useRouter();
  const login = useConsoleLogin<Me>({
    api: authApi,
    role: "ADMIN",
    notRoleMessage: NOT_ADMIN,
    genericError: GENERIC_ERROR_MESSAGE,
    onSignedIn: (res: SignedIn<Me>) => {
      auth.setToken(res.token);
      auth.setUser(res.user);
      router.push("/");
    },
  });

  return (
    <ConsoleLoginPage
      login={login}
      logo={<Image src="/logo.png" alt="" width={28} height={28} priority className="h-7 w-7 object-contain" />}
      consoleName="Админ самбар"
      headline={
        <>
          Uziy платформыг <span className="text-[var(--color-primary)]">нэг дороос</span> хянана.
        </>
      }
      lead="Судалгаа, мөнгө татах хүсэлт, хэрэглэгч, компаниудын бүх үйл ажиллагаа энд."
      highlights={HIGHLIGHTS}
      title="Админ самбарт нэвтрэх"
      subtitle="Зөвхөн платформын админуудад"
    />
  );
}
