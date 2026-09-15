import type { Metadata } from "next";
import "./globals.css";

const siteUrl = new URL("https://joao-santos-biomedica.joaprs.chatgpt.site");
const title = "João Santos | Engenharia Biomédica, dados e sistemas de saúde";
const description =
  "Portefólio de João Santos, Engenheiro Biomédico em início de carreira, com experiência curricular em EEG, Python, DICOM, IA e prototipagem.";

export const metadata: Metadata = {
  metadataBase: siteUrl,
  title,
  description,
  keywords: [
    "João Pedro Ribeiro dos Santos",
    "Engenharia Biomédica",
    "Sinais EEG",
    "Python",
    "MNE",
    "DICOM",
    "HL7 FHIR",
    "Inteligência Artificial",
    "Dispositivos médicos",
    "MedTech",
    "HealthTech",
    "ISEP",
  ],
  authors: [{ name: "João Pedro Ribeiro dos Santos", url: siteUrl.toString() }],
  creator: "João Pedro Ribeiro dos Santos",
  alternates: {
    canonical: "/",
  },
  icons: {
    icon: "/joao-santos.jpg",
  },
  robots: {
    index: true,
    follow: true,
  },
  openGraph: {
    title,
    description,
    url: siteUrl.toString(),
    type: "profile",
    locale: "pt_PT",
    images: [
      {
        url: "/og.png",
        width: 1732,
        height: 908,
        alt: "João Pedro Ribeiro dos Santos — Engenharia Biomédica",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title,
    description,
    images: ["/og.png"],
  },
};

const personData = {
  "@context": "https://schema.org",
  "@type": "Person",
  name: "João Pedro Ribeiro dos Santos",
  url: siteUrl.toString(),
  jobTitle: "Engenheiro Biomédico",
  alumniOf: {
    "@type": "CollegeOrUniversity",
    name: "Instituto Superior de Engenharia do Porto",
  },
  knowsAbout: [
    "Engenharia Biomédica",
    "Sinais EEG",
    "Python",
    "DICOM",
    "HL7 FHIR",
    "Aprendizagem automática",
    "Dispositivos médicos",
  ],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pt-PT">
      <body>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(personData) }}
        />
        {children}
      </body>
    </html>
  );
}
