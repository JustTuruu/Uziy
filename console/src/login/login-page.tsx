import { useRouter } from "@shared/navigation";
import { BarChart3, Crosshair, PlayCircle } from "lucide-react";
import { ConsoleLoginPage, useConsoleLogin, type LoginHighlight, type SignedIn } from "@uziy/ui";
import { auth, GENERIC_ERROR_MESSAGE } from "@shared/api/http";
import { authApi } from "@shared/api/auth-api";
import type { Me } from "@shared/api/types";
import { homeFor } from "@shared/session";

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
  // The one sign-in page (owner, 2026-10-22): companies land on their dashboard, admins under /admin — one app,
  // so both keep their session here.
  const login = useConsoleLogin<Me>({
    api: authApi,
    roles: ["COMPANY", "ADMIN"],
    notRoleMessage: NOT_CONSOLE_ACCOUNT,
    genericError: GENERIC_ERROR_MESSAGE,
    onSignedIn: (res: SignedIn<Me>) => {
      auth.setToken(res.token);
      auth.setUser(res.user);
      router.push(homeFor(res.user.role));
    },
  });

  return (
    <ConsoleLoginPage
      login={login}
      logo={<img src="/logo.png" alt="" width={28} height={28} className="h-7 w-7 object-contain" />}
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
