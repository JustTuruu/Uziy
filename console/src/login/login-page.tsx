"use client";

import Image from "next/image";
import { useRouter } from "next/navigation";
import { BarChart3, Crosshair, PlayCircle } from "lucide-react";
import { ConsoleLoginPage, useConsoleLogin, type LoginHighlight, type SignedIn } from "@uziy/ui";
import { auth, authApi, GENERIC_ERROR_MESSAGE, type Me } from "@/lib/api";
import { handOffToAdmin } from "@/lib/admin-handoff";

const NOT_CONSOLE_ACCOUNT = "Энэ дансаар самбарт нэвтрэх эрхгүй байна";
const SALES_EMAIL = "sales@uziy.mn";

const HIGHLIGHTS: readonly LoginHighlight[] = [
  {
    icon: <Crosshair size={18} />,
    title: "Нарийн зорилт",
    text: "Нас, хүйс, байршлаар яг хэрэгтэй үзэгчдээ сонгоно.",
  },
  {
    icon: <PlayCircle size={18} />,
    title: "Бүтэн үзэлт",
    text: "Видеог эцэст нь хүртэл үзсэн хүн л судалгаанд хариулна.",
  },
  {
    icon: <BarChart3 size={18} />,
    title: "Шууд үр дүн",
    text: "Хариулт, хүрэлт, зардлаа бодит хугацаанд харна.",
  },
];

export default function LoginPage() {
  const router = useRouter();
  // The one sign-in page (owner, 2026-10-22): companies stay here, admins are handed to the admin panel by role.
  // An admin's token is never stored on this site.
  const login = useConsoleLogin<Me>({
    api: authApi,
    roles: ["COMPANY", "ADMIN"],
    notRoleMessage: NOT_CONSOLE_ACCOUNT,
    genericError: GENERIC_ERROR_MESSAGE,
    onSignedIn: async (res: SignedIn<Me>) => {
      if (res.user.role === "ADMIN") {
        await handOffToAdmin(res.token);
        return;
      }
      auth.setToken(res.token);
      auth.setUser(res.user);
      router.push("/");
    },
  });

  return (
    <ConsoleLoginPage
      login={login}
      logo={<Image src="/logo.png" alt="" width={28} height={28} priority className="h-7 w-7 object-contain" />}
      consoleName="Компанийн самбар"
      headline={
        <>
          Зорилтот үзэгчдэдээ хүрч,{" "}
          <span className="text-[var(--color-primary)]">жинхэнэ санал</span> цуглуул.
        </>
      }
      lead="Урамшуулалт видео ба судалгааны платформ: та видеогоо зөв хүмүүст хүргэж, тэдний бодит санал бодлыг сонсоно."
      highlights={HIGHLIGHTS}
      title="Компанийн самбарт нэвтрэх"
      subtitle="Компанийн дансаараа нэвтэрнэ үү"
      note={
        <>
          Компанийн дансыг Uziy үүсгэж өгнө. Данс авах бол{" "}
          <a href={`mailto:${SALES_EMAIL}`} className="font-medium text-[var(--color-primary)] hover:underline">
            {SALES_EMAIL}
          </a>{" "}
          хаягаар холбогдоно уу.
        </>
      }
    />
  );
}
