import type { Metadata } from "next";
import { getPublicWeekSnapshot } from "../lib/public-week";
import { WeeklyClub } from "./weekly-club";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export const metadata: Metadata = {
  title: "Sexta 50 — a semana toda num só mapa",
  description:
    "Escolha um número, acompanhe o pagamento e veja os vencedores com base na ordem oficial do Euromilhões.",
};

export default async function Home() {
  const initialSnapshot = await getPublicWeekSnapshot().catch((error) => {
    console.error("initial public week failed", error);
    return null;
  });
  return <WeeklyClub initialSnapshot={initialSnapshot} />;
}
