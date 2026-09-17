"use client";

import { useEffect, useState } from "react";
import Link from "next/link";

const MBWAY_RECEIVER_PHONE = "9********";
const MBWAY_RECEIVER_PHONE_DISPLAY = "9********";

type PersonalReservation = {
  number: number;
  name: string;
  phone: string;
  status: "pending" | "paid" | "released" | "expired" | "refunded";
  reservedAt: string;
  expiresAt: string | null;
  drawDate: string;
  closesAt: string;
  priceCents: number;
};

const PAYMENT_STATUSES = new Set<PersonalReservation["status"]>([
  "pending",
  "paid",
  "released",
  "expired",
  "refunded",
]);

function isPersonalReservation(value: unknown): value is PersonalReservation {
  if (!value || typeof value !== "object") return false;
  const reservation = value as Partial<PersonalReservation>;
  return (
    Number.isInteger(reservation.number) &&
    typeof reservation.name === "string" &&
    typeof reservation.phone === "string" &&
    typeof reservation.status === "string" &&
    PAYMENT_STATUSES.has(reservation.status as PersonalReservation["status"]) &&
    typeof reservation.reservedAt === "string" &&
    (reservation.expiresAt === null ||
      typeof reservation.expiresAt === "string") &&
    typeof reservation.drawDate === "string" &&
    typeof reservation.closesAt === "string" &&
    typeof reservation.priceCents === "number" &&
    Number.isFinite(reservation.priceCents)
  );
}

function removeStoredReservation(key: string) {
  try {
    window.sessionStorage.removeItem(key);
  } catch {
    // O armazenamento local é apenas uma conveniência e nunca é obrigatório.
  }
}

function readStoredReservation(key: string) {
  try {
    const stored = window.sessionStorage.getItem(key);
    if (!stored) return null;
    const parsed: unknown = JSON.parse(stored);
    if (isPersonalReservation(parsed)) return parsed;
  } catch {
    // Ignora armazenamento indisponível ou dados antigos/corrompidos.
  }
  removeStoredReservation(key);
  return null;
}

function storeReservation(key: string, reservation: PersonalReservation) {
  try {
    window.sessionStorage.setItem(key, JSON.stringify(reservation));
  } catch {
    // Uma resposta válida do servidor prevalece mesmo sem sessionStorage.
  }
}

function formatClosingSchedule(value: string) {
  const close = new Date(value);
  if (Number.isNaN(close.getTime())) {
    return {
      short: "por confirmar",
      full: "Data e hora por confirmar",
    };
  }

  const date = new Intl.DateTimeFormat("pt-PT", {
    weekday: "long",
    day: "2-digit",
    month: "long",
    year: "numeric",
    timeZone: "Europe/Lisbon",
  }).format(close);
  const shortDate = new Intl.DateTimeFormat("pt-PT", {
    day: "2-digit",
    month: "2-digit",
    timeZone: "Europe/Lisbon",
  }).format(close);
  const time = new Intl.DateTimeFormat("pt-PT", {
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
    timeZone: "Europe/Lisbon",
  }).format(close);

  return {
    short: `${shortDate} · ${time}`,
    full: `${date} às ${time}`,
  };
}

export function ConfirmationArea({ token }: { token: string }) {
  const [reservation, setReservation] = useState<PersonalReservation | null>(null);
  const [loading, setLoading] = useState(true);
  const [serverVerified, setServerVerified] = useState(false);
  const [connectionError, setConnectionError] = useState("");
  const [copied, setCopied] = useState(false);
  const [paymentPhoneCopied, setPaymentPhoneCopied] = useState(false);
  const [observedAt, setObservedAt] = useState(() => Date.now());

  useEffect(() => {
    let active = true;
    let requestSequence = 0;
    const storageKey = `sexta50:confirmation:${token}`;

    async function load() {
      const requestId = requestSequence + 1;
      requestSequence = requestId;
      try {
        const response = await fetch(`/api/reservations/${encodeURIComponent(token)}`, { cache: "no-store" });
        if (!active || requestId !== requestSequence) return;

        if (
          response.status === 400 ||
          response.status === 404 ||
          response.status === 410
        ) {
          removeStoredReservation(storageKey);
          setReservation(null);
          setServerVerified(true);
          setConnectionError("");
          return;
        }
        if (!response.ok) throw new Error("temporary-error");
        const payload = (await response.json()) as { reservation?: unknown };
        if (!isPersonalReservation(payload.reservation)) {
          throw new Error("invalid-response");
        }
        if (!active || requestId !== requestSequence) return;

        setReservation(payload.reservation);
        setServerVerified(true);
        setConnectionError("");
        storeReservation(storageKey, payload.reservation);
      } catch {
        if (!active || requestId !== requestSequence) return;
        const fallback = readStoredReservation(storageKey);
        setReservation((current) => current ?? fallback);
        setServerVerified(false);
        setConnectionError(
          "Não foi possível confirmar o estado atual. Não envies nenhum pagamento enquanto este aviso estiver visível.",
        );
      } finally {
        if (active && requestId === requestSequence) {
          setObservedAt(Date.now());
          setLoading(false);
        }
      }
    }

    void load();
    const refreshTimer = window.setInterval(load, 15000);
    return () => {
      active = false;
      window.clearInterval(refreshTimer);
    };
  }, [token]);

  const amount = reservation
    ? (reservation.priceCents / 100).toLocaleString("pt-PT", {
        style: "currency",
        currency: "EUR",
      })
    : "—";

  async function copyLink() {
    await navigator.clipboard.writeText(window.location.href);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 2200);
  }

  async function copyPaymentPhone() {
    await navigator.clipboard.writeText(MBWAY_RECEIVER_PHONE);
    setPaymentPhoneCopied(true);
    window.setTimeout(() => setPaymentPhoneCopied(false), 2200);
  }

  if (loading) {
    return (
      <main className="personal-page loading-personal">
        <span className="spinner" />
        <p>A preparar a tua área individual…</p>
      </main>
    );
  }

  if (!reservation) {
    if (connectionError) {
      return (
        <main className="personal-page invalid-personal">
          <Link className="brand" href="/">
            <span className="brand-mark">50</span><span>Sexta<sup>+</sup></span>
          </Link>
          <div className="invalid-card">
            <span>!</span>
            <h1>Não conseguimos confirmar esta ligação.</h1>
            <p>Não efetues nenhum pagamento. Tenta novamente quando a ligação estiver disponível.</p>
            <button className="primary-button" type="button" onClick={() => window.location.reload()}>
              Tentar novamente <b>↻</b>
            </button>
          </div>
        </main>
      );
    }

    return (
      <main className="personal-page invalid-personal">
        <Link className="brand" href="/">
          <span className="brand-mark">50</span><span>Sexta<sup>+</sup></span>
        </Link>
        <div className="invalid-card">
          <span>?</span>
          <h1>Esta ligação já não está disponível.</h1>
          <p>Volta ao mapa e confirma o número novamente, ou pede ajuda ao organizador.</p>
          <Link className="primary-button" href="/">Voltar ao mapa <b>→</b></Link>
        </div>
      </main>
    );
  }

  const paid = reservation.status === "paid";
  const released = reservation.status === "released";
  const inactive =
    released ||
    reservation.status === "expired" ||
    reservation.status === "refunded";
  const closesAt = new Date(reservation.closesAt).getTime();
  const validClosingTime = Number.isFinite(closesAt);
  const drawClosed = validClosingTime && observedAt >= closesAt;
  const closingSchedule = formatClosingSchedule(reservation.closesAt);
  const canShowPaymentInstructions =
    serverVerified && validClosingTime && !drawClosed && !paid && !inactive;

  return (
    <main className="personal-page">
      <div className="personal-topbar">
        <Link className="brand" href="/">
          <span className="brand-mark">50</span><span>Sexta<sup>+</sup></span>
        </Link>
        <span><i /> Área individual de {reservation.name}</span>
      </div>

      <section className="personal-hero">
        <div className={`personal-copy ${inactive ? "expired-copy" : ""}`}>
          <div className="eyebrow"><span>●</span> A TUA SEXTA-FEIRA</div>
          <h1>
            {inactive
              ? "A reserva foi libertada,"
              : serverVerified
                ? "Está reservado,"
                : "Estamos a confirmar,"}
            <br /><em>{reservation.name}.</em>
          </h1>
          {connectionError && (
            <p className="expired-warning" role="alert">
              {connectionError} Estamos a mostrar apenas os últimos dados disponíveis.
            </p>
          )}
          {inactive && (
            <p className="expired-warning">
              {released
                ? "O organizador desbloqueou esta participação e o número voltou a ficar disponível. Não envies agora o pagamento."
                : "Esta participação já não está ativa. Não envies agora o pagamento e fala com o organizador se precisares de ajuda."}
            </p>
          )}
          <p>Esta é a tua área pessoal. Guarda esta ligação para acompanhares o pagamento, o número e o resultado.</p>
          <button className="copy-button" onClick={copyLink}>{copied ? "Ligação copiada ✓" : "Copiar ligação pessoal"} <span>↗</span></button>
        </div>
        <div className="personal-ticket">
          <div className="ticket-top"><span>O TEU NÚMERO</span><b>{paid ? "CONFIRMADO" : inactive ? "DESBLOQUEADO" : serverVerified ? "RESERVADO" : "POR CONFIRMAR"}</b></div>
          <strong>{String(reservation.number).padStart(2, "0")}</strong>
          <div className="ticket-bottom"><span>FECHO<br />{closingSchedule.short}</span><span>{amount}<br />{reservation.phone}</span></div>
        </div>
      </section>

      <section className="personal-dashboard">
        <article className="payment-focus">
          <div className="focus-head">
            <div>
              <div className="eyebrow">ESTADO DO PAGAMENTO</div>
              <h2>
                {paid
                  ? "Pagamento confirmado."
                  : inactive
                    ? "Número desbloqueado."
                    : !serverVerified
                      ? "Estado por confirmar."
                      : drawClosed || !validClosingTime
                      ? "A aguardar decisão do organizador."
                      : "Envia por MB WAY."}
              </h2>
            </div>
            <span className={paid ? "paid-state" : inactive ? "expired-state" : "pending-state"}>
              {paid ? "● pago" : inactive ? "● desbloqueado" : serverVerified ? "● pendente" : "● por confirmar"}
            </span>
          </div>
          <p>
            {paid
              ? "O teu número está garantido para esta semana."
              : inactive
                ? "Este número já não está reservado em teu nome. Volta ao mapa e escolhe um número livre antes de pagares."
                : !serverVerified
                  ? "Não conseguimos confirmar se esta participação continua pendente. Não envies dinheiro até esta página voltar a validar o estado."
                  : !validClosingTime
                    ? "Não foi possível confirmar a data de fecho. Não envies dinheiro e fala com o organizador."
                    : drawClosed
                  ? "A semana já fechou. O número continua bloqueado, mas não envies agora um novo pagamento; aguarda a confirmação do organizador."
                  : `Envia ${amount} para o contacto abaixo. Sempre que possível, usa o MB WAY associado ao telemóvel terminado em ${reservation.phone.slice(-2)}.`}
          </p>
          {inactive && <Link className="primary-button expired-return" href="/">Voltar ao mapa <span>→</span></Link>}
          {!paid && !inactive && (
            <>
              {serverVerified && (
                <div className="reservation-lock-note">
                  <span aria-hidden="true">●</span>
                  <div>
                    <strong>Número bloqueado em teu nome</strong>
                    <small>Permanece reservado até o organizador confirmar o pagamento ou decidir desbloqueá-lo.</small>
                  </div>
                </div>
              )}
              {canShowPaymentInstructions && (
                <>
                  <div className="mbway-payment-box">
                    <div className="mbway-payment-head">
                      <span>ENVIAR DINHEIRO PARA</span>
                      <b>{amount}</b>
                    </div>
                    <strong>{MBWAY_RECEIVER_PHONE_DISPLAY}</strong>
                    <button className="copy-payment-phone" type="button" onClick={copyPaymentPhone}>
                      {paymentPhoneCopied ? "Número copiado ✓" : "Copiar número MB WAY"}
                      <span>↗</span>
                    </button>
                    <ol>
                      <li>Abre a app MB WAY e escolhe “Enviar Dinheiro”.</li>
                      <li>Introduz o número {MBWAY_RECEIVER_PHONE_DISPLAY} e o valor {amount}.</li>
                      <li>Confirma o nome do destinatário apresentado pela app antes de enviar.</li>
                    </ol>
                    <a href="https://www.mbway.pt/enviar-dinheiro/" target="_blank" rel="noreferrer">
                      Consultar instruções oficiais MB WAY ↗
                    </a>
                  </div>
                  <small className="payment-manual-note">A transferência é imediata. Esta página verifica o estado automaticamente e muda para “pago” depois de o organizador confirmar o recebimento.</small>
                </>
              )}
            </>
          )}
        </article>

        <aside className="personal-summary">
          <div className="eyebrow">RESUMO</div>
          <dl>
            <div><dt>Nome</dt><dd>{reservation.name}</dd></div>
            <div><dt>Número</dt><dd>{reservation.number}</dd></div>
            <div><dt>Valor</dt><dd>{amount}</dd></div>
            <div><dt>Sorteio</dt><dd>{reservation.drawDate}</dd></div>
            <div><dt>Fecho</dt><dd>{closingSchedule.full}</dd></div>
            <div><dt>Contacto</dt><dd>{reservation.phone}</dd></div>
          </dl>
        </aside>
      </section>

      <section className="personal-timeline">
        <div className="eyebrow">O QUE ACONTECE AGORA</div>
        <h2>A tua semana, passo a passo</h2>
        <div className="timeline-grid">
          <article className={serverVerified ? "done" : ""}><span>{serverVerified ? "✓" : "?"}</span><div><b>Número reservado</b><small>{serverVerified ? "Confirmado pelo servidor" : "Estado por confirmar"}</small></div></article>
          <article className={paid ? "done" : inactive ? "" : "current"}>
            <span>{paid ? "✓" : inactive ? "×" : "2"}</span>
            <div><b>Pagamento MB WAY</b><small>{paid ? "Confirmado" : inactive ? "Participação desbloqueada" : serverVerified ? "Envia e aguarda confirmação do organizador" : "Aguarda a confirmação do estado"}</small></div>
          </article>
          <article><span>3</span><div><b>Fecho da semana</b><small>{closingSchedule.full}</small></div></article>
          <article><span>4</span><div><b>Resultado e prémios</b><small>Recebes uma notificação</small></div></article>
        </div>
      </section>

      <section className="personal-help">
        <div><div className="eyebrow">PRECISAS DE AJUDA?</div><h2>Fala com o organizador.</h2><p>Indica o teu nome e o número {reservation.number} para ser mais rápido.</p></div>
        <Link className="secondary-button" href="/">Voltar ao mapa <span>→</span></Link>
      </section>

      <footer className="personal-footer">
        <p>Não partilhes esta ligação: permite consultar os dados desta participação.</p>
        <p>Transferência MB WAY · confirmação manual do organizador</p>
      </footer>
    </main>
  );
}
