import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { headers } from "next/headers";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export async function generateMetadata(): Promise<Metadata> {
  const incomingHeaders = await headers();
  const host = incomingHeaders.get("x-forwarded-host") ?? incomingHeaders.get("host") ?? "localhost:3000";
  const protocol = incomingHeaders.get("x-forwarded-proto") ?? (host.startsWith("localhost") ? "http" : "https");
  const origin = `${protocol}://${host}`;
  const imageUrl = `${origin}/og.png`;

  return {
    metadataBase: new URL(origin),
    title: {
      default: "Sexta 50",
      template: "%s · Sexta 50",
    },
    description: "O mapa simples e transparente para gerir 50 números todas as sextas-feiras.",
    openGraph: {
      title: "Sexta 50 — a semana toda num só mapa",
      description: "Escolhe. Confirma. Acompanha.",
      type: "website",
      locale: "pt_PT",
      images: [{ url: imageUrl, width: 1731, height: 909, alt: "Sexta 50 — a semana toda num só mapa" }],
    },
    twitter: {
      card: "summary_large_image",
      title: "Sexta 50 — a semana toda num só mapa",
      description: "Escolhe. Confirma. Acompanha.",
      images: [imageUrl],
    },
  };
}

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="pt-PT">
      <body className={`${geistSans.variable} ${geistMono.variable}`}>{children}</body>
    </html>
  );
}
