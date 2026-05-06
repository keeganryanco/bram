import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL("https://trybram.app"),
  title: {
    default: "Bram: Workout Notes",
    template: "%s | Bram",
  },
  description:
    "Bram turns natural workout notes into simple strength tracking, progress memory, and calmer training insights.",
  applicationName: "Bram",
  appleWebApp: {
    capable: true,
    title: "Bram",
  },
  icons: {
    icon: "/bram-icon.png",
    apple: "/bram-icon.png",
  },
  openGraph: {
    title: "Bram: Workout Notes",
    description:
      "Write your workout naturally. Bram tracks the rest.",
    url: "https://trybram.app",
    siteName: "Bram",
    images: [
      {
        url: "/bram-icon.png",
        width: 1024,
        height: 1024,
        alt: "Bram app icon",
      },
    ],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full">{children}</body>
    </html>
  );
}
