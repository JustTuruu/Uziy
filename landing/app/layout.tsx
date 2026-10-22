import type { Metadata } from "next";
import { Onest } from "next/font/google";
import "./globals.css";

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3002";
const TITLE = "Uziy — Брэндүүдтэй танилцаж, санал бодлоо хэлээрэй";
const DESCRIPTION =
  "Компаниуд шинэ бүтээгдэхүүнээ богино видеогоор танилцуулж, таны бодлыг 2–3 асуултаар асууна. Танд хамаатайг нь л харуулна.";

const body = Onest({
  // cyrillic-ext carries the Mongolian letters Ө ө Ү ү; without it they fell back to another font mid-word.
  subsets: ["cyrillic", "cyrillic-ext", "latin"],
  variable: "--font-body",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: TITLE,
  description: DESCRIPTION,
  icons: {
    icon: [{ url: "/logo.png", type: "image/png" }],
    apple: "/logo.png",
  },
  openGraph: {
    title: TITLE,
    description: DESCRIPTION,
    images: ["/logo.png"],
    siteName: "Uziy",
    type: "website",
    locale: "mn_MN",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="mn" className={`${body.variable} h-full antialiased`}>
      <body className="flex min-h-full flex-col">{children}</body>
    </html>
  );
}
