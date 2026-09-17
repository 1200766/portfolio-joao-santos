import type { Metadata } from "next";
import Link from "next/link";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { ADMIN_COOKIE, verifyAdminSession } from "../../../lib/admin-auth";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Entrar na área do administrador",
  robots: { index: false, follow: false },
};

export default async function AdminLoginPage({
  searchParams,
}: {
  searchParams: Promise<{ erro?: string }>;
}) {
  const cookieStore = await cookies();
  if (await verifyAdminSession(cookieStore.get(ADMIN_COOKIE)?.value)) redirect("/admin");
  const { erro } = await searchParams;

  return (
    <main className="login-page">
      <Link className="brand login-brand" href="/" aria-label="Sexta 50, início">
        <span className="brand-mark">50</span>
        <span>Sexta<sup>+</sup></span>
      </Link>
      <section className="login-card">
        <div className="login-aside">
          <span className="login-lock">●</span>
          <div>
            <span className="eyebrow">ÁREA RESERVADA</span>
            <h1>Apenas o administrador pode entrar.</h1>
            <p>Gestão de pagamentos, números e vencedores numa sessão protegida.</p>
          </div>
        </div>
        <form action="/api/admin/login" method="post" className="login-form">
          <div className="eyebrow">AUTENTICAÇÃO</div>
          <h2>Bem-vindo de volta.</h2>
          <p>Introduz as credenciais de administrador.</p>
          <label>
            Utilizador
            <input name="username" autoComplete="username" required autoFocus />
          </label>
          <label>
            Palavra-passe
            <input name="password" type="password" autoComplete="current-password" required />
          </label>
          {erro && <div className="login-error" role="alert">As credenciais não estão corretas.</div>}
          <button className="pay-button" type="submit">Entrar na área privada <b>→</b></button>
          <Link className="back-link" href="/">← Voltar ao mapa dos números</Link>
        </form>
      </section>
    </main>
  );
}
