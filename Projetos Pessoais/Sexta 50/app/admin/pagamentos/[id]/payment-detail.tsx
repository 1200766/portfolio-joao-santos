"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

type AdminReservation = {
  id: number;
  number: number;
  name: string;
  phone: string;
  status: "pending" | "paid" | "released" | "expired" | "refunded";
  paymentReference: string | null;
  reservedAt: string;
  expiresAt: string | null;
  paidAt: string | null;
  releasedAt: string | null;
  contest: string;
  drawDate: string;
  closesAt: string;
  drawStatus: "open" | "closed" | "resulted" | "archived";
  priceCents: number;
};

function parseStoredDate(value: string) {
  if (value.includes("T")) return new Date(value);
  return new Date(`${value.replace(" ", "T")}Z`);
}

function formatDateTime(value: string | null) {
  if (!value) return "—";
  const date = parseStoredDate(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("pt-PT", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "Europe/Lisbon",
  }).format(date);
}

function formatDrawDate(value: string) {
  const date = new Date(`${value}T12:00:00`);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("pt-PT", {
    weekday: "long",
    day: "2-digit",
    month: "long",
    year: "numeric",
  }).format(date);
}

function formatPhone(value: string) {
  const digits = value.replace(/\D/g, "");
  if (digits.length !== 9) return value;
  return `+351 ${digits.slice(0, 3)} ${digits.slice(3, 6)} ${digits.slice(6)}`;
}

function statusLabel(status: AdminReservation["status"]) {
  if (status === "paid") return "Pagamento confirmado";
  if (status === "released") return "Desbloqueado pelo administrador";
  if (status === "expired") return "Reserva expirada";
  if (status === "refunded") return "Pagamento devolvido";
  return "A aguardar confirmação";
}

export function AdminPaymentDetail({ reservationId }: { reservationId: number }) {
  const router = useRouter();
  const [reservation, setReservation] = useState<AdminReservation | null>(null);
  const [loading, setLoading] = useState(true);
  const [confirming, setConfirming] = useState(false);
  const [releasing, setReleasing] = useState(false);
  const [refunding, setRefunding] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;

    fetch(`/api/admin/reservations/${reservationId}`, { cache: "no-store" })
      .then(async (response) => {
        if (response.status === 401) {
          router.replace("/admin/login");
          return null;
        }
        const payload = (await response.json()) as {
          reservation?: AdminReservation;
          error?: string;
        };
        if (!response.ok || !payload.reservation) {
          throw new Error(payload.error ?? "Não foi possível abrir este pagamento.");
        }
        return payload.reservation;
      })
      .then((details) => {
        if (active && details) setReservation(details);
      })
      .catch((reason: unknown) => {
        if (active) {
          setError(
            reason instanceof Error
              ? reason.message
              : "Não foi possível abrir este pagamento.",
          );
        }
      })
      .finally(() => {
        if (active) setLoading(false);
      });

    return () => {
      active = false;
    };
  }, [reservationId, router]);

  const amount = useMemo(
    () =>
      ((reservation?.priceCents ?? 250) / 100).toLocaleString("pt-PT", {
        style: "currency",
        currency: "EUR",
      }),
    [reservation?.priceCents],
  );

  async function confirmPayment() {
    if (!reservation || reservation.status !== "pending") return;
    const accepted = window.confirm(
      `Confirmar que recebeste ${amount} de ${reservation.name} para o número ${reservation.number}?`,
    );
    if (!accepted) return;

    setConfirming(true);
    setError("");
    try {
      const response = await fetch(`/api/admin/reservations/${reservation.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "confirm-payment" }),
      });
      if (response.status === 401) {
        router.replace("/admin/login");
        return;
      }
      const payload = (await response.json()) as {
        reservation?: AdminReservation;
        error?: string;
      };
      if (!response.ok || !payload.reservation) {
        throw new Error(payload.error ?? "Não foi possível confirmar o pagamento.");
      }
      setReservation(payload.reservation);
    } catch (reason) {
      setError(
        reason instanceof Error
          ? reason.message
          : "Não foi possível confirmar o pagamento.",
      );
    } finally {
      setConfirming(false);
    }
  }

  async function releaseReservation() {
    if (!reservation || reservation.status !== "pending") return;
    const accepted = window.confirm(
      `Desbloquear o número ${reservation.number} de ${reservation.name}? O número ficará imediatamente disponível e esta participação deixa de poder receber prémio.`,
    );
    if (!accepted) return;

    setReleasing(true);
    setError("");
    try {
      const response = await fetch(`/api/admin/reservations/${reservation.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "release" }),
      });
      if (response.status === 401) {
        router.replace("/admin/login");
        return;
      }
      const payload = (await response.json()) as {
        reservation?: AdminReservation;
        error?: string;
      };
      if (!response.ok || !payload.reservation) {
        throw new Error(payload.error ?? "Não foi possível desbloquear o número.");
      }
      setReservation(payload.reservation);
    } catch (reason) {
      setError(
        reason instanceof Error
          ? reason.message
          : "Não foi possível desbloquear o número.",
      );
    } finally {
      setReleasing(false);
    }
  }

  async function refundAndRelease() {
    if (!reservation || reservation.status !== "paid") return;
    const confirmation = window.prompt(
      `Só deves desbloquear o número ${reservation.number} depois de devolveres ${amount} a ${reservation.name}.\n\nEscreve DEVOLVIDO para confirmar a correção:`,
    );
    if (confirmation?.trim().toLocaleUpperCase("pt-PT") !== "DEVOLVIDO") return;

    setRefunding(true);
    setError("");
    try {
      const response = await fetch(`/api/admin/reservations/${reservation.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: "refund-and-release",
          refundConfirmed: true,
        }),
      });
      if (response.status === 401) {
        router.replace("/admin/login");
        return;
      }
      const payload = (await response.json()) as {
        reservation?: AdminReservation;
        error?: string;
      };
      if (!response.ok || !payload.reservation) {
        throw new Error(
          payload.error ?? "Não foi possível corrigir este pagamento.",
        );
      }
      setReservation(payload.reservation);
    } catch (reason) {
      setError(
        reason instanceof Error
          ? reason.message
          : "Não foi possível corrigir este pagamento.",
      );
    } finally {
      setRefunding(false);
    }
  }

  if (loading) {
    return (
      <main className="admin-payment-page loading-personal">
        <span className="spinner" aria-hidden="true" />
        <p>A abrir a ficha do pagamento…</p>
      </main>
    );
  }

  if (!reservation) {
    return (
      <main className="admin-payment-page invalid-personal">
        <Link className="brand" href="/" aria-label="Sexta 50, início">
          <span className="brand-mark">50</span>
          <span>Sexta<sup>+</sup></span>
        </Link>
        <section className="invalid-card">
          <span>!</span>
          <h1>Pagamento não encontrado.</h1>
          <p>{error || "Esta ficha já não está disponível."}</p>
          <Link className="primary-button" href="/admin#pagamentos">
            Voltar aos pagamentos <b>→</b>
          </Link>
        </section>
      </main>
    );
  }

  const paid = reservation.status === "paid";
  const released = reservation.status === "released";
  const refunded = reservation.status === "refunded";
  const inactive =
    released || refunded || reservation.status === "expired";
  const pending = reservation.status === "pending";
  const canCorrectPaid =
    paid &&
    (reservation.drawStatus === "open" || reservation.drawStatus === "closed");
  const phone = formatPhone(reservation.phone);

  return (
    <main className="admin-payment-page">
      <div className="demo-strip private-strip">
        <span className="lock-dot" aria-hidden="true">●</span>
        Área privada · ficha individual
      </div>
      <header className="site-header">
        <Link className="brand" href="/" aria-label="Sexta 50, início">
          <span className="brand-mark">50</span>
          <span>Sexta<sup>+</sup></span>
        </Link>
        <nav className="view-switch" aria-label="Mudar de área">
          <Link href="/">Participar</Link>
          <Link className="active" href="/admin">Área do administrador</Link>
        </nav>
        <form action="/api/admin/logout" method="post" className="logout-form">
          <button type="submit">Terminar sessão ↗</button>
        </form>
      </header>

      <div className="payment-detail-shell">
        <Link className="payment-back" href="/admin#pagamentos">
          ← Voltar aos pagamentos
        </Link>

        <section className="payment-detail-hero">
          <div>
            <div className="eyebrow"><span>●</span> CONFIRMAÇÃO INDIVIDUAL</div>
            <h1>{reservation.name}</h1>
            <p>
              Confere os dados do MB WAY antes de alterar o estado desta
              participação.
            </p>
          </div>
          <div className={`payment-status-card ${paid ? "is-paid" : inactive ? "is-released" : ""}`}>
            <span>NÚMERO ESCOLHIDO</span>
            <strong>{String(reservation.number).padStart(2, "0")}</strong>
            <b>{statusLabel(reservation.status)}</b>
          </div>
        </section>

        <section className="payment-detail-grid">
          <article className="payment-data-card">
            <div className="panel-head">
              <div>
                <span>DADOS DA PARTICIPAÇÃO</span>
                <h2>Antes de confirmar</h2>
              </div>
              <span className={paid ? "paid-state" : inactive ? "expired-state" : "pending-state"}>
                {paid
                  ? "● pago"
                  : refunded
                    ? "● devolvido"
                    : inactive
                      ? "● desbloqueado"
                      : "● pendente"}
              </span>
            </div>
            <dl className="payment-data-list">
              <div><dt>Nome ou assinatura</dt><dd>{reservation.name}</dd></div>
              <div>
                <dt>Telemóvel MB WAY</dt>
                <dd><a href={`tel:+351${reservation.phone}`}>{phone}</a></dd>
              </div>
              <div><dt>Número escolhido</dt><dd>{reservation.number}</dd></div>
              <div><dt>Valor esperado</dt><dd>{amount}</dd></div>
              <div><dt>Reserva criada</dt><dd>{formatDateTime(reservation.reservedAt)}</dd></div>
              <div><dt>Sorteio</dt><dd>{formatDrawDate(reservation.drawDate)}</dd></div>
              <div><dt>Referência</dt><dd>{reservation.paymentReference || `S50-${reservation.id}`}</dd></div>
              {(paid || refunded) && <div><dt>Confirmado em</dt><dd>{formatDateTime(reservation.paidAt)}</dd></div>}
              {inactive && (
                <div>
                  <dt>{refunded ? "Devolvido e desbloqueado em" : "Desbloqueado em"}</dt>
                  <dd>{formatDateTime(reservation.releasedAt)}</dd>
                </div>
              )}
            </dl>
          </article>

          <aside className={`payment-action-card ${paid ? "is-paid" : inactive ? "is-released" : ""}`}>
            <span className="payment-action-icon">{paid ? "✓" : inactive ? "↗" : "€"}</span>
            <div className="eyebrow">
              {paid
                ? "CONCLUÍDO"
                : refunded
                  ? "PAGAMENTO DEVOLVIDO"
                  : inactive
                    ? "DESBLOQUEADO"
                    : "AÇÃO DO ADMINISTRADOR"}
            </div>
            <h2>
              {paid
                ? "Pagamento recebido."
                : refunded
                  ? "Pagamento corrigido."
                  : inactive
                    ? "Número libertado."
                    : "Recebeste no MB WAY?"}
            </h2>
            <p>
              {paid
                ? `${reservation.name} está confirmado no número ${reservation.number}.`
                : inactive
                  ? `O número ${reservation.number} voltou a ficar disponível e esta participação já não pode receber prémio.${refunded ? " O pagamento ficou registado como devolvido." : ""}`
                  : `Confirma apenas depois de veres o movimento de ${amount} associado ao contacto ${phone}.`}
            </p>
            {pending && (
              <div className="payment-action-buttons">
                <button
                  className="confirm-payment-button"
                  type="button"
                  onClick={confirmPayment}
                  disabled={confirming || releasing || refunding}
                >
                  <span>{confirming ? "A guardar…" : "Confirmar pagamento recebido"}</span>
                  <b>✓</b>
                </button>
                <button
                  className="release-payment-button"
                  type="button"
                  onClick={releaseReservation}
                  disabled={confirming || releasing || refunding}
                >
                  {releasing ? "A desbloquear…" : "Desbloquear este número"}
                </button>
              </div>
            )}
            {canCorrectPaid && (
              <button
                className="refund-payment-button"
                type="button"
                onClick={refundAndRelease}
                disabled={refunding}
              >
                {refunding
                  ? "A guardar a correção…"
                  : "Pagamento devolvido — desbloquear número"}
              </button>
            )}
            {!pending && (
              <Link className="secondary-button" href="/admin#pagamentos">
                Voltar ao painel <span>→</span>
              </Link>
            )}
            {error && <p className="payment-action-error" role="alert">{error}</p>}
            <small>
              Esta alteração fica guardada e atualiza imediatamente o mapa e os
              totais do painel.
            </small>
          </aside>
        </section>
      </div>

      <footer>
        <div className="brand footer-brand">
          <span className="brand-mark">50</span>
          <span>Sexta<sup>+</sup></span>
        </div>
        <p>Ficha individual de pagamento.</p>
        <p className="footer-small">A sessão termina automaticamente ao fim de oito horas.</p>
      </footer>
    </main>
  );
}
