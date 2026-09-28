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
  const mins = Math.round(diffMs / 60000);
  if (mins < 1) return "яг одоо";
  if (mins < 60) return `${mins} мин`;
  const hrs = Math.round(mins / 60);
  if (hrs < 24) return `${hrs} цаг`;
  const days = Math.round(hrs / 24);
  if (days < 7) return `${days} өдөр`;
  return formatDate(d);
}
