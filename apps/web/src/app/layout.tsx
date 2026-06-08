import type { Metadata } from "next";
import localFont from "next/font/local";
import { Analytics } from "@vercel/analytics/next";
import "./globals.css";

const suisseIntl = localFont({
  variable: "--font-suisse-intl",
  display: "swap",
  fallback: ["ui-sans-serif", "system-ui", "sans-serif"],
  src: [
    {
      path: "../assets/fonts/suisse-intl/SuisseIntl-Book.otf",
      weight: "400",
      style: "normal",
    },
    {
      path: "../assets/fonts/suisse-intl/SuisseIntl-Regular.otf",
      weight: "450",
      style: "normal",
    },
    {
      path: "../assets/fonts/suisse-intl/SuisseIntl-Medium.otf",
      weight: "500",
      style: "normal",
    },
    {
      path: "../assets/fonts/suisse-intl/SuisseIntl-Semibold.otf",
      weight: "600",
      style: "normal",
    },
    {
      path: "../assets/fonts/suisse-intl/SuisseIntl-Bold.otf",
      weight: "700",
      style: "normal",
    },
    {
      path: "../assets/fonts/suisse-intl/SuisseIntl-RegularItalic.otf",
      weight: "450",
      style: "italic",
    },
  ],
});

const adobeCaslonPro = localFont({
  variable: "--font-adobe-caslon-pro",
  display: "swap",
  fallback: ["Georgia", "serif"],
  src: [
    {
      path: "../assets/fonts/adobe-caslon-pro/AdobeCaslonPro-Regular.woff",
      weight: "400",
      style: "normal",
    },
    {
      path: "../assets/fonts/adobe-caslon-pro/AdobeCaslonPro-Semibold.woff",
      weight: "600",
      style: "normal",
    },
    {
      path: "../assets/fonts/adobe-caslon-pro/AdobeCaslonPro-Bold.woff",
      weight: "700",
      style: "normal",
    },
    {
      path: "../assets/fonts/adobe-caslon-pro/AdobeCaslonPro-Italic.woff",
      weight: "400",
      style: "italic",
    },
  ],
});

export const metadata: Metadata = {
  metadataBase: new URL("https://trybram.app"),
  title: {
    default: "Bram: Workout Notes",
    template: "%s | Bram",
  },
  description:
    "Bram is a notes-style workout tracker for iPhone. Write workouts naturally like Notes, then track sets, reps, weights, PRs, volume, and progress.",
  keywords: [
    "notes-style workout tracker",
    "workout notes app",
    "freeform workout logger",
    "Apple Notes workout tracker",
    "minimal gym log app",
    "simple workout tracker",
  ],
  applicationName: "Bram",
  alternates: {
    canonical: "https://trybram.app",
  },
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
      "Get stronger without tracking harder. Write workouts naturally like Notes, then track progress.",
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
      className={`${suisseIntl.variable} ${adobeCaslonPro.variable} h-full antialiased`}
    >
      <body className="min-h-full">
        {children}
        <Analytics />
      </body>
    </html>
  );
}
