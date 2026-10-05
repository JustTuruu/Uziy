import type { Metadata } from "next";
import "./globals.css";

// Base URL for resolving relative asset paths in Open Graph / Twitter cards.
// Prefer NEXT_PUBLIC_SITE_URL when deployed; falls back to localhost in dev.
const SITE_URL =
  process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: "Uziy — Console",
  description:
    "Rewarded video platform console (Company + Super Admin) for the Mongolian market.",
  icons: {
    icon: [
      { url: "/logo.png", type: "image/png" },
    ],
    apple: [{ url: "/logo.png" }],
  },
  openGraph: {
    title: "Uziy — Console",
    description:
      "Rewarded video platform console for the Mongolian market.",
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
    <html lang="mn" className="h-full antialiased">
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
