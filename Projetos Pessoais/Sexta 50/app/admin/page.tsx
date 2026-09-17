import type { Metadata } from "next";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { ADMIN_COOKIE, verifyAdminSession } from "../../lib/admin-auth";
import { AdminWorkspace } from "../weekly-club";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Área privada do administrador",
  robots: { index: false, follow: false },
};

export default async function AdminPage() {
  const cookieStore = await cookies();
  const validSession = await verifyAdminSession(cookieStore.get(ADMIN_COOKIE)?.value);
  if (!validSession) redirect("/admin/login");
  return <AdminWorkspace />;
}
