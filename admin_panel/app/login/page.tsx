"use client";

import { useEffect } from "react";
import { leaveFor, SIGN_IN_URL } from "@/lib/handoff";

/**
 * There is no admin sign-in form (owner, 2026-10-22): everyone signs in on the one login page, and admins are
 * handed back here. A signed-out visitor is sent there at once.
 */
export default function LoginPage() {
  useEffect(() => leaveFor(SIGN_IN_URL), []);

  return (
    <div className="flex min-h-screen items-center justify-center bg-[var(--color-background)] px-6 text-sm text-[var(--color-text-secondary)]">
      <a href={SIGN_IN_URL} className="hover:text-[var(--color-text-primary)]">
        Нэвтрэх хуудас руу шилжиж байна...
      </a>
    </div>
  );
}
