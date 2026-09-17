import type { Metadata } from "next";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { ADMIN_COOKIE, verifyAdminSession } from "../../../lib/admin-auth";
import { AdminHistory } from "./history-view";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Histórico de vencedores",
  robots: { index: false, follow: false },
};

export default async function AdminHistoryPage() {
  const cookieStore = await cookies();
  const validSession = await verifyAdminSession(
    cookieStore.get(ADMIN_COOKIE)?.value,
  );
  if (!validSession) redirect("/admin/login");

  return <AdminHistory />;
}
