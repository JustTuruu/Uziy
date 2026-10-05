import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatTugrik(amount: number): string {
  return new Intl.NumberFormat("mn-MN").format(Math.round(amount)) + " ₮";
}

export function formatNumber(n: number): string {
  return new Intl.NumberFormat("mn-MN").format(n);
}

export function formatDate(iso: string | Date): string {
  const d = typeof iso === "string" ? new Date(iso) : iso;
  return d.toLocaleDateString("mn-MN", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
}

export function relativeTime(iso: string | Date): string {
  const d = typeof iso === "string" ? new Date(iso) : iso;
  const diffMs = Date.now() - d.getTime();
  if (diffMs < 0) return formatDate(d); // future date — just print it
  const mins = Math.round(diffMs / 60000);
  if (mins < 1) return "яг одоо";
  if (mins < 60) return `${mins} мин өмнө`;
  const hrs = Math.round(mins / 60);
  if (hrs < 24) return `${hrs} цагийн өмнө`;
  const days = Math.round(hrs / 24);
  if (days < 7) return `${days} өдрийн өмнө`;
  return formatDate(d);
}

export function sanitizeIntInput(raw: string): string {
  return raw.replace(/\D/g, "").replace(/^0+(?=\d)/, "");
}

export function parseIntInput(text: string): number {
  const n = Number.parseInt(text, 10);
  return Number.isFinite(n) ? n : 0;
}

export function formatDuration(totalSeconds: number): string {
  const s = Math.max(0, Math.floor(totalSeconds));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
}
