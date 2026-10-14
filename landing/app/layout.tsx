import type { Metadata } from "next";
import { Onest } from "next/font/google";
import "./globals.css";

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3002";
const TITLE = "Uziy — Танд хамаатай брэндүүд ба санал асуулга";
const DESCRIPTION =
  "Танд хамаатай брэндүүдийн танилцуулгыг үзэж, санал бодлоо хэлээрэй.";

const body = Onest({
  subsets: ["cyrillic", "latin"],
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
