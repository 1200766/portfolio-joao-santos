import type { Metadata } from "next";
import seedItems from "../../data/clothes.json";
import CatalogClient from "./CatalogClient";

export const metadata: Metadata = {
  title: "Inventário",
  description:
    "Consulta o inventário e experimenta editar detalhes apenas no navegador.",
};

export default function CatalogPage() {
  return <CatalogClient initialItems={seedItems} />;
}
