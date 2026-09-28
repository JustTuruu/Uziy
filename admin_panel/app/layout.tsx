import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Uziy — Console",
  description:
    "Rewarded video platform console (Company + Super Admin) for the Mongolian market.",
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
