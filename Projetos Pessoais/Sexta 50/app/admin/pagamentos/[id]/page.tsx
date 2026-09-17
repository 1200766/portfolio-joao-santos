import type { Metadata } from "next";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { ADMIN_COOKIE, verifyAdminSession } from "../../../../lib/admin-auth";
import { AdminPaymentDetail } from "./payment-detail";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Confirmar pagamento",
  robots: { index: false, follow: false },
};

export default async function AdminPaymentPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const cookieStore = await cookies();
  const validSession = await verifyAdminSession(cookieStore.get(ADMIN_COOKIE)?.value);
  if (!validSession) redirect("/admin/login");

  const id = Number((await params).id);
  if (!Number.isInteger(id) || id < 1) redirect("/admin#pagamentos");

  return <AdminPaymentDetail reservationId={id} />;
}
