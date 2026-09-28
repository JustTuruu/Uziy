"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { Building2, Play, ShieldCheck } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";

type Role = "COMPANY" | "ADMIN";

export default function LoginPage() {
  const router = useRouter();
  const [role, setRole] = useState<Role>("COMPANY");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    if (phone.length < 8 || password.length < 6) {
      setError("Утасны дугаар болон нууц үгээ шалгана уу");
      return;
    }
    setLoading(true);
    // TODO: POST /auth/login → JWT; assert response.role === role.
    await new Promise((r) => setTimeout(r, 500));
    router.push(role === "ADMIN" ? "/admin" : "/company");
  };

  return (
    <div className="flex min-h-screen">
      {/* Left: brand */}
      <div className="hidden w-1/2 flex-col justify-between bg-[var(--color-surface)] p-12 lg:flex">
        <div className="flex items-center gap-3">
          <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-[var(--color-primary)] text-black">
            <Play size={22} fill="currentColor" />
          </div>
          <div className="text-xl font-extrabold tracking-tight">Zoos</div>
        </div>

        <div>
          <h2 className="max-w-md text-3xl font-extrabold leading-tight tracking-tight">
            Зорилтот үзэгчдэдээ хүрч,{" "}
            <span className="text-[var(--color-primary)]">
              жинхэнэ дата
            </span>{" "}
            цуглуул.
          </h2>
          <p className="mt-4 max-w-md text-sm text-[var(--color-text-secondary)]">
            Rewarded video сурталчилгааны платформ. Компаниуд нас, хүйс,
            байршлаар нарийн зорилтот хэрэглэгчдэдээ видеог хүргэж, судалгааны
            үр дүн бодит хугацаанд харна.
          </p>
        </div>

        <div className="flex gap-6 text-xs text-[var(--color-text-secondary)]">
          <span>© 2026 Zoos</span>
          <span>support@zoos.mn</span>
        </div>
      </div>

      {/* Right: form */}
      <div className="flex w-full items-center justify-center px-6 py-12 lg:w-1/2">
        <div className="w-full max-w-sm">
          <h1 className="text-2xl font-extrabold tracking-tight">
            Console-д нэвтрэх
          </h1>
          <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
            Өөрийн үүргийн дагуу нэвтрэнэ үү
          </p>

          <div className="mt-6 grid grid-cols-2 gap-2">
            <RolePicker
              active={role === "COMPANY"}
              onClick={() => setRole("COMPANY")}
              icon={<Building2 size={18} />}
              label="Компани"
              hint="Видео байршуулах"
            />
            <RolePicker
              active={role === "ADMIN"}
              onClick={() => setRole("ADMIN")}
              icon={<ShieldCheck size={18} />}
              label="Супер Админ"
              hint="Платформын хяналт"
            />
          </div>

          <form onSubmit={submit} className="mt-6 space-y-4">
            <Input
              label="Утасны дугаар"
              inputMode="numeric"
              maxLength={8}
              placeholder="99112233"
              value={phone}
              onChange={(e) =>
                setPhone(e.target.value.replace(/\D/g, "").slice(0, 8))
              }
            />
            <Input
              label="Нууц үг"
              type="password"
              placeholder="•••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
            {error && (
              <div className="rounded-lg border border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] px-3 py-2 text-xs text-[var(--color-danger)]">
                {error}
              </div>
            )}
            <Button
              type="submit"
              disabled={loading}
              className="w-full"
              size="lg"
            >
              {loading ? "Нэвтэрч байна..." : "Нэвтрэх"}
            </Button>
          </form>

          <div className="mt-6 text-center text-xs text-[var(--color-text-muted)]">
            Компаниар бүртгүүлэх бол{" "}
            <a
              href="mailto:sales@zoos.mn"
              className="text-[var(--color-primary)] hover:underline"
            >
              sales@zoos.mn
            </a>
          </div>
        </div>
      </div>
    </div>
  );
}

function RolePicker({
  active,
  onClick,
  icon,
  label,
  hint,
}: {
  active: boolean;
  onClick: () => void;
  icon: React.ReactNode;
  label: string;
  hint: string;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "flex flex-col items-start gap-1 rounded-xl border p-3 text-left transition-colors",
        active
          ? "border-[var(--color-primary)] bg-[color-mix(in_oklab,var(--color-primary)_10%,transparent)]"
          : "border-[var(--color-divider)] bg-[var(--color-surface)] hover:border-[var(--color-text-muted)]",
      )}
    >
      <span
        className={cn(
          active
            ? "text-[var(--color-primary)]"
            : "text-[var(--color-text-secondary)]",
        )}
      >
        {icon}
      </span>
      <span className="text-sm font-bold text-[var(--color-text-primary)]">
        {label}
      </span>
      <span className="text-xs text-[var(--color-text-secondary)]">
        {hint}
      </span>
    </button>
  );
}
