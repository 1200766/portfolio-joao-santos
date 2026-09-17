import type { Metadata } from "next";
import { ConfirmationArea } from "./confirmation-area";

export const metadata: Metadata = {
  title: "A tua confirmação",
  description: "Acompanha o teu número e o estado do pagamento.",
  robots: { index: false, follow: false },
};

export default async function ConfirmationPage({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await params;
  return <ConfirmationArea token={token} />;
}
