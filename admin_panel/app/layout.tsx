import type { Metadata } from "next";
import { Rubik } from "next/font/google";
import "./globals.css";

/**
 * Admin UI font (owner, 2026-10-21: softer and easier on the eyes). Rubik has
 * rounded corners, a tall x-height, tabular figures for money columns, and
 * covers Mongolian Ө/Ү (cyrillic-ext) and the ₮ sign (latin-ext). next/font
 * self-hosts it, so the browser never calls Google. globals.css puts it first
 * in --font-sans.
 */
const rubik = Rubik({
  subsets: ["latin", "latin-ext", "cyrillic", "cyrillic-ext"],
  variable: "--font-rubik",
  display: "swap",
});

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: "Uziy — Console",
  description:
    "Rewarded video platform console (Company + Super Admin) for the Mongolian market.",
  icons: {
    icon: [{ url: "/logo.png", type: "image/png" }],
    apple: [{ url: "/logo.png" }],
  },
  openGraph: {
    title: "Uziy — Console",
    description: "Rewarded video platform console for the Mongolian market.",
    images: ["/logo.png"],
    siteName: "Uziy",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="mn" className={`${rubik.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
