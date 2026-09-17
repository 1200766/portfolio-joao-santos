"use client";

import { FormEvent, useCallback, useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import type { PublicWeekSnapshot } from "../lib/public-week";

type PaymentStatus = "paid" | "pending";

export type Reservation = {
  id?: number;
  drawId?: number;
  number: number;
  name: string;
  phone?: string;
  status: PaymentStatus;
  reservedAt?: string;
  expiresAt?: string | null;
  paidAt?: string | null;
  contest?: string;
  drawDate?: string;
  closesAt?: string;
  priceCents?: number;
};

export type OfficialResult = {
  contest: string;
  date: string;
  drawDate: string;
  drawOrder: number[];
  sourceUrl: string;
};

type ReservationConfirmation = {
  number: number;
  name: string;
  phone: string;
  status: "pending";
  reservedAt: string;
  expiresAt: string | null;
  drawDate: string;
  closesAt: string;
  priceCents: number;
};

type DrawInfo = {
  id: number;
  contest: string;
  drawDate: string;
  closesAt: string;
  status: "open" | "closed" | "resulted" | "archived";
  priceCents: number;
};

type AwaitingResult = {
  id: number;
  contest: string;
  drawDate: string;
  closesAt: string;
  status: "open" | "closed" | "resulted";
  lastResultCheckAt: string | null;
};

function formatPhone(value: string) {
  const digits = value.replace(/\D/g, "").slice(0, 9);
  return digits.replace(/(\d{3})(?=\d)/g, "$1 ");
}

function formatAdminPhone(value?: string) {
  if (!value) return "Contacto indisponível";
  const digits = value.replace(/\D/g, "");
  if (digits.length !== 9) return value;
  return `+351 ${digits.slice(0, 3)} ${digits.slice(3, 6)} ${digits.slice(6)}`;
}

function weekNumber(contest?: string) {
  return contest?.match(/W(\d{2})$/)?.[1] ?? "—";
}

function closeDetails(closesAt?: string) {
  if (!closesAt) return { day: "—", month: "—", time: "—" };
  const date = new Date(closesAt);
  if (Number.isNaN(date.getTime())) {
    return { day: "—", month: "—", time: "—" };
  }
  const parts = new Intl.DateTimeFormat("pt-PT", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
    timeZone: "Europe/Lisbon",
  }).formatToParts(date);
  const read = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((part) => part.type === type)?.value ?? "—";
  return {
    day: read("day"),
    month: read("month").replace(".", "").toUpperCase(),
    time: `${read("hour")}:${read("minute")}`,
  };
}

function formatMoneyCents(cents?: number) {
  if (typeof cents !== "number" || !Number.isFinite(cents)) return "—";
  return (cents / 100).toLocaleString("pt-PT", {
    style: "currency",
    currency: "EUR",
  });
}

function formatLongDrawDate(drawDate: string) {
  const date = new Date(`${drawDate}T12:00:00Z`);
  if (Number.isNaN(date.getTime())) return drawDate;
  return new Intl.DateTimeFormat("pt-PT", {
    weekday: "long",
    day: "2-digit",
    month: "long",
    year: "numeric",
    timeZone: "Europe/Lisbon",
  }).format(date);
}

export function WeeklyClub({
  initialSnapshot,
}: {
  initialSnapshot?: PublicWeekSnapshot | null;
}) {
  const router = useRouter();
  const [selectedNumber, setSelectedNumber] = useState<number | null>(null);
  const [reservations, setReservations] = useState<Reservation[]>(
    initialSnapshot?.reservations ?? [],
  );
  const [draw, setDraw] = useState<DrawInfo | null>(
    initialSnapshot?.draw ?? null,
  );
  const [mapLoading, setMapLoading] = useState(!initialSnapshot);
  const [mapError, setMapError] = useState("");
  const [alias, setAlias] = useState("");
  const [phone, setPhone] = useState("");
  const [accepted, setAccepted] = useState(false);
  const [result, setResult] = useState<OfficialResult | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [reservationError, setReservationError] = useState("");
  const mapRequestId = useRef(0);

  const reservedByNumber = useMemo(
    () => new Map(reservations.map((reservation) => [reservation.number, reservation])),
    [reservations],
  );

  const refreshMap = useCallback(async () => {
    const requestId = mapRequestId.current + 1;
    mapRequestId.current = requestId;
    try {
      const response = await fetch("/api/reservations", { cache: "no-store" });
      const payload = (await response.json()) as {
        reservations?: Reservation[];
        draw?: DrawInfo;
        error?: string;
      };
      if (!response.ok || !payload.draw) {
        throw new Error(payload.error ?? "Não foi possível atualizar o mapa.");
      }
      if (requestId !== mapRequestId.current) return;
      const nextReservations = payload.reservations ?? [];
      setReservations(nextReservations);
      setDraw(payload.draw);
      setMapError("");
      setSelectedNumber((current) => {
        if (payload.draw?.status !== "open") return null;
        if (current && nextReservations.some((item) => item.number === current)) return null;
        return current;
      });
    } catch {
      if (requestId !== mapRequestId.current) return;
      setMapError("Não foi possível atualizar o mapa. As escolhas estão temporariamente bloqueadas.");
    } finally {
      if (requestId === mapRequestId.current) setMapLoading(false);
    }
  }, []);

  useEffect(() => {
    const initialTimer = window.setTimeout(refreshMap, 0);
    const timer = window.setInterval(refreshMap, 15000);
    function refreshOnFocus() {
      if (document.visibilityState === "visible") void refreshMap();
    }
    document.addEventListener("visibilitychange", refreshOnFocus);
    return () => {
      window.clearTimeout(initialTimer);
      window.clearInterval(timer);
      document.removeEventListener("visibilitychange", refreshOnFocus);
    };
  }, [refreshMap]);

  const refreshLatestResult = useCallback(async () => {
    const response = await fetch("/api/results/latest", { cache: "no-store" });
    if (!response.ok) throw new Error("Resultado indisponível");
    setResult((await response.json()) as OfficialResult);
  }, []);

  useEffect(() => {
    const initialTimer = window.setTimeout(() => {
      void refreshLatestResult().catch(() => undefined);
    }, 0);
    const resultTimer = window.setInterval(() => {
      void refreshLatestResult().catch(() => undefined);
    }, 15 * 60 * 1000);
    function refreshOnFocus() {
      if (document.visibilityState === "visible") {
        void refreshLatestResult().catch(() => undefined);
      }
    }
    document.addEventListener("visibilitychange", refreshOnFocus);
    return () => {
      window.clearTimeout(initialTimer);
      window.clearInterval(resultTimer);
      document.removeEventListener("visibilitychange", refreshOnFocus);
    };
  }, [refreshLatestResult]);

  function chooseNumber(number: number) {
    if (mapLoading || mapError || draw?.status !== "open" || reservedByNumber.has(number)) return;
    setReservationError("");
    setSelectedNumber(number);
    window.requestAnimationFrame(() => {
      document.getElementById("checkout")?.scrollIntoView({ behavior: "smooth", block: "center" });
    });
  }

  async function submitReservation(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedNumber || !alias.trim() || phone.replace(/\D/g, "").length !== 9 || !accepted) return;

    setSubmitting(true);
    setReservationError("");
    try {
      const response = await fetch("/api/reservations", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          number: selectedNumber,
          name: alias,
          phone,
          consent: accepted,
          drawId: draw?.id,
          contest: draw?.contest,
        }),
      });
      const payload = (await response.json()) as {
        token?: string;
        reservation?: ReservationConfirmation;
        error?: string;
      };
      if (!response.ok || !payload.token || !payload.reservation) {
        await refreshMap();
        throw new Error(payload.error ?? "Não foi possível guardar a reserva.");
      }

      try {
        window.sessionStorage.setItem(
          `sexta50:confirmation:${payload.token}`,
          JSON.stringify(payload.reservation),
        );
      } catch {
        // A ligação individual continua a funcionar sem armazenamento local.
      }
      router.push(`/confirmacao/${payload.token}`);
    } catch (error) {
      setReservationError(
        error instanceof Error
          ? error.message
          : "Não foi possível guardar a reserva. Não efetues o pagamento.",
      );
      setSubmitting(false);
    }
  }

  return (
    <main>
      <div className="demo-strip">
        <span className="pulse-dot" aria-hidden="true" />
        Transferência MB WAY · confirmação manual do organizador
      </div>

      <header className="site-header">
        <a className="brand" href="#top" aria-label="Sexta 50, início">
          <span className="brand-mark">50</span>
          <span>Sexta<sup>+</sup></span>
        </a>
        <nav className="view-switch" aria-label="Mudar de área">
          <Link className="active" href="/">Participar</Link>
          <Link href="/admin">Área do administrador</Link>
        </nav>
        <div className="header-note">
          <span className="status-dot" />{" "}
          {mapLoading
            ? "A atualizar semana"
            : mapError || !draw
              ? "Mapa indisponível"
              : draw.status === "open"
                ? "Semana aberta"
                : "Escolhas encerradas"}
        </div>
      </header>

      <ParticipantView
        reservations={reservations}
        reservedByNumber={reservedByNumber}
        selectedNumber={selectedNumber}
        alias={alias}
        phone={phone}
        accepted={accepted}
        draw={draw}
        mapLoading={mapLoading}
        mapError={mapError}
        result={result}
        submitting={submitting}
        reservationError={reservationError}
        onChoose={chooseNumber}
        onAlias={setAlias}
        onPhone={(value) => setPhone(formatPhone(value))}
        onAccepted={setAccepted}
        onSubmit={submitReservation}
        onCancel={() => setSelectedNumber(null)}
      />

      <footer>
        <div className="brand footer-brand">
          <span className="brand-mark">50</span>
          <span>Sexta<sup>+</sup></span>
        </div>
        <p>Uma semana simples. Um mapa transparente. Três vencedores.</p>
        <p className="footer-small">Gestão independente · resultado consultado em Jogos Santa Casa</p>
      </footer>
    </main>
  );
}

type ParticipantProps = {
  reservations: Reservation[];
  reservedByNumber: Map<number, Reservation>;
  draw: DrawInfo | null;
  mapLoading: boolean;
  mapError: string;
  selectedNumber: number | null;
  alias: string;
  phone: string;
  accepted: boolean;
  result: OfficialResult | null;
  submitting: boolean;
  reservationError: string;
  onChoose: (number: number) => void;
  onAlias: (value: string) => void;
  onPhone: (value: string) => void;
  onAccepted: (value: boolean) => void;
  onSubmit: (event: FormEvent<HTMLFormElement>) => void;
  onCancel: () => void;
};

function ParticipantView(props: ParticipantProps) {
  const choicesUnavailable =
    props.mapLoading || Boolean(props.mapError) || props.draw?.status !== "open";
  const entriesClosed =
    !props.mapLoading && Boolean(props.draw) && props.draw?.status !== "open";
  const mapUnavailable =
    !props.mapLoading && (Boolean(props.mapError) || !props.draw);
  const date = closeDetails(props.draw?.closesAt);
  const price = formatMoneyCents(props.draw?.priceCents);

  return (
    <>
      <section className="hero" id="top">
        <div className="hero-copy">
          <div className="eyebrow"><span>●</span> Sexta-feira · semana {weekNumber(props.draw?.contest)}</div>
          <h1>O teu número.<br /><em>A tua sexta.</em></h1>
          <p className="hero-lede">Escolhe um dos 50 números, confirma por MB WAY e acompanha tudo num só lugar.</p>
          {entriesClosed ? (
            <span className="primary-button disabled" aria-disabled="true">Escolhas encerradas <span>×</span></span>
          ) : choicesUnavailable ? (
            <span className="primary-button disabled" aria-disabled="true">
              {props.mapLoading ? "A atualizar o mapa…" : "Mapa indisponível"} <span>…</span>
            </span>
          ) : (
            <a className="primary-button" href="#mapa">
              Escolher o meu número <span>↓</span>
            </a>
          )}
          <div className="trust-row">
            <span>✓ Sem contas complicadas</span>
            <span>
              {props.draw ? `✓ ${price} por semana` : "✓ Valor confirmado no mapa"}
            </span>
          </div>
        </div>
        <div className="week-card">
          <div className="week-card-top">
            <span>ESTA SEMANA</span>
            <span className={`live-pill ${entriesClosed || mapUnavailable ? "closed" : ""}`}>
              {props.mapLoading
                ? "A ATUALIZAR"
                : mapUnavailable
                  ? "INDISPONÍVEL"
                  : entriesClosed
                    ? "ENCERRADO"
                    : "ABERTO"}
            </span>
          </div>
          <div className="deadline">
            <span>Fecha em</span>
            <strong>SEX<br />{date.day}</strong>
            <small>{date.month}<br />{date.time}</small>
          </div>
          <div className="progress-label">
            <span>
              {props.mapLoading
                ? "A confirmar ocupação"
                : `${props.reservations.length} de 50 escolhidos`}
            </span>
            <strong>
              {props.mapLoading
                ? "— livres"
                : `${50 - props.reservations.length} livres`}
            </strong>
          </div>
          <div className="progress-track">
            <span
              style={{
                width: props.mapLoading
                  ? "0%"
                  : `${props.reservations.length * 2}%`,
              }}
            />
          </div>
          <div className="prize-order">
            <span><b>1</b> primeiro a sair</span>
            <span><b>2</b> segundo</span>
            <span><b>3</b> terceiro</span>
          </div>
        </div>
      </section>

      <section className="number-section" id="mapa">
        <div className="section-heading">
          <div>
            <div className="eyebrow">O MAPA DA SEMANA</div>
            <h2>
              {mapUnavailable
                ? "Mapa temporariamente indisponível"
                : entriesClosed
                  ? "As escolhas estão encerradas"
                  : props.mapLoading
                    ? "A confirmar os números disponíveis"
                    : "Escolhe um número livre"}
            </h2>
          </div>
          <div className="legend">
            <span><i className="legend-free" /> Livre</span>
            <span><i className="legend-taken" /> Escolhido</span>
            <span><i className="legend-pending" /> A aguardar</span>
          </div>
        </div>
        {props.mapError && <p className="map-notice error">{props.mapError}</p>}
        {props.reservationError && <p className="map-notice error">{props.reservationError}</p>}
        {entriesClosed && !props.mapError && (
          <p className="map-notice">O organizador encerrou as escolhas desta semana. Nenhuma nova reserva será aceite até a semana ser reaberta.</p>
        )}
        <div
          className="number-grid"
          aria-label="Números de 1 a 50"
          aria-busy={props.mapLoading}
        >
          {Array.from({ length: 50 }, (_, index) => index + 1).map((number) => {
            const reservation = props.reservedByNumber.get(number);
            const state =
              props.selectedNumber === number
                ? "selected"
                : reservation?.status ?? (choicesUnavailable ? "locked" : "free");
            const label = reservation
              ? `Número ${number}, escolhido`
              : choicesUnavailable
                ? `Número ${number}, escolhas indisponíveis`
                : `Escolher número ${number}`;
            return (
              <button
                key={number}
                className={`number-cell ${state}`}
                disabled={choicesUnavailable || Boolean(reservation)}
                onClick={() => props.onChoose(number)}
                aria-label={label}
              >
                <strong>{String(number).padStart(2, "0")}</strong>
                <small>
                  {state === "free"
                    ? "livre"
                    : state === "selected"
                      ? "o teu"
                      : state === "locked"
                        ? props.mapLoading
                          ? "a atualizar"
                          : mapUnavailable
                            ? "indisponível"
                            : "encerrado"
                        : reservation?.name}
                </small>
              </button>
            );
          })}
        </div>
      </section>

      {props.selectedNumber && !choicesUnavailable && (
        <section className="checkout-wrap" id="checkout">
          <form className="checkout-card" onSubmit={props.onSubmit}>
            <div className="selected-ticket">
              <span>O TEU NÚMERO</span>
              <strong>{props.selectedNumber}</strong>
              <small>{price}</small>
            </div>
            <div className="checkout-fields">
              <div className="section-heading compact">
                <div>
                  <div className="eyebrow">CRIAR A TUA ÁREA</div>
                  <h2>Como queres aparecer?</h2>
                </div>
                <button className="text-button" type="button" onClick={props.onCancel}>Cancelar</button>
              </div>
              <p className="personal-area-note">Depois de confirmares, recebes uma ligação pessoal para acompanhar o pagamento, o teu número e o resultado.</p>
              <label>
                Nome ou alcunha
                <input value={props.alias} onChange={(event) => props.onAlias(event.target.value)} placeholder="Ex.: Participante 1" maxLength={24} required />
              </label>
              <label>
                Telemóvel associado ao MB WAY
                <div className="phone-field"><span>+351</span><input inputMode="numeric" value={props.phone} onChange={(event) => props.onPhone(event.target.value)} placeholder="912 345 678" required /></div>
              </label>
              <label className="consent-row">
                <input type="checkbox" checked={props.accepted} onChange={(event) => props.onAccepted(event.target.checked)} required />
                <span>Concordo com o uso destes dados apenas para gerir esta semana e contactar os vencedores.</span>
              </label>
              <button className="pay-button" type="submit" disabled={props.submitting}>
                <span>mb way</span> {props.submitting ? "A criar a tua área…" : "Reservar número e pagar"}
              </button>
              {props.reservationError && <p className="form-error">{props.reservationError}</p>}
              <p className="microcopy">Assim que reservas, o número fica bloqueado. Só o organizador o pode confirmar ou desbloquear.</p>
            </div>
          </form>
        </section>
      )}

      <section className="how-section">
        <div className="eyebrow">SEM COMPLICAÇÕES</div>
        <h2>Três passos até sexta</h2>
        <div className="steps">
          <article><span>01</span><h3>Escolhe</h3><p>Um número livre entre 1 e 50. Só pode haver uma pessoa por número.</p></article>
          <article>
            <span>02</span>
            <h3>Paga</h3>
            <p>
              {props.draw
                ? `Envia ${price} por MB WAY para o número indicado na tua área individual.`
                : "O valor desta semana aparece assim que o mapa for confirmado."}
            </p>
          </article>
          <article><span>03</span><h3>Acompanha</h3><p>Os três primeiros números na ordem de saída definem os vencedores.</p></article>
        </div>
      </section>

      <section className="result-section">
        <div className="result-card">
          <div>
            <div className="eyebrow">
              {props.result
                ? `ÚLTIMA SEXTA-FEIRA · ${props.result.date}`
                : "A CONSULTAR A FONTE OFICIAL"}
            </div>
            <h2>Resultado oficial</h2>
            <p>
              {props.result
                ? `Ordem de saída verificada no concurso ${props.result.contest}.`
                : "O resultado aparece aqui assim que estiver disponível nos Jogos Santa Casa."}
            </p>
          </div>
          <div className="winning-balls">
            {props.result?.drawOrder.slice(0, 3).map((number, index) => (
              <span key={number} className={`ball ball-${index + 1}`}><small>{index + 1}.º</small>{number}</span>
            ))}
          </div>
          <a
            href={props.result?.sourceUrl ?? "https://www.jogossantacasa.pt/web/SCCartazResult/euroMilhoes"}
            target="_blank"
            rel="noreferrer"
          >
            Ver fonte oficial ↗
          </a>
        </div>
        <div className="winner-list private-history-promo">
          <div className="section-heading compact">
            <div>
              <div className="eyebrow">HISTÓRICO REAL</div>
              <h2>Sem nomes inventados.</h2>
            </div>
          </div>
          <span className="history-promo-mark">✓</span>
          <p>
            Depois de cada sorteio, o sistema guarda apenas os vencedores com
            pagamento confirmado. O arquivo completo está protegido na área do
            administrador.
          </p>
          <Link className="secondary-button" href="/admin">Entrar na área do administrador <span>→</span></Link>
        </div>
      </section>
    </>
  );
}

type AdminProps = {
  reservations: Reservation[];
  pendingFinalizationReservations: Reservation[];
  reservedByNumber: Map<number, Reservation>;
  draw: DrawInfo | null;
  awaitingResults: AwaitingResult[];
  paidCount: number;
  pendingCount: number;
  currentPendingCount: number;
  previousPendingCount: number;
  entriesClosed: boolean;
  result: OfficialResult | null;
  syncState: "idle" | "loading" | "ok" | "error";
  syncMessage: string;
  toggleState: "idle" | "loading";
  toggleError: string;
  loadError: string;
  reservationsLoading: boolean;
  onToggleClosed: () => void;
  onSync: () => void;
};

export function AdminWorkspace() {
  const router = useRouter();
  const [reservations, setReservations] = useState<Reservation[]>([]);
  const [
    pendingFinalizationReservations,
    setPendingFinalizationReservations,
  ] = useState<Reservation[]>([]);
  const [reservationsLoading, setReservationsLoading] = useState(true);
  const [draw, setDraw] = useState<DrawInfo | null>(null);
  const [awaitingResults, setAwaitingResults] = useState<AwaitingResult[]>([]);
  const [result, setResult] = useState<OfficialResult | null>(null);
  const [syncState, setSyncState] = useState<"idle" | "loading" | "ok" | "error">("idle");
  const [syncMessage, setSyncMessage] = useState("");
  const [toggleState, setToggleState] = useState<"idle" | "loading">("idle");
  const [toggleError, setToggleError] = useState("");
  const [loadError, setLoadError] = useState("");

  const loadAdminData = useCallback(async () => {
    try {
      const response = await fetch("/api/admin/reservations", {
        cache: "no-store",
      });
      if (response.status === 401) {
        router.replace("/admin/login");
        return;
      }
      const payload = (await response.json()) as {
        reservations?: Reservation[];
        draw?: DrawInfo | null;
        awaitingResults?: AwaitingResult[];
        pendingFinalizationReservations?: Reservation[];
        error?: string;
      };
      if (!response.ok) {
        throw new Error(payload.error ?? "Não foi possível atualizar o painel.");
      }
      setReservations(payload.reservations ?? []);
      setDraw(payload.draw ?? null);
      setAwaitingResults(payload.awaitingResults ?? []);
      setPendingFinalizationReservations(
        payload.pendingFinalizationReservations ?? [],
      );
      setLoadError("");
    } catch (error) {
      setLoadError(
        error instanceof Error
          ? error.message
          : "Não foi possível atualizar o painel.",
      );
    } finally {
      setReservationsLoading(false);
    }
  }, [router]);

  const loadLatestResult = useCallback(async () => {
    const response = await fetch("/api/results/latest", { cache: "no-store" });
    if (!response.ok) throw new Error("Resultado oficial indisponível.");
    setResult((await response.json()) as OfficialResult);
  }, []);

  useEffect(() => {
    const initialTimer = window.setTimeout(() => {
      void loadAdminData();
      void loadLatestResult().catch(() => undefined);
    }, 0);
    const dataTimer = window.setInterval(loadAdminData, 15000);
    const resultTimer = window.setInterval(() => {
      void loadLatestResult().catch(() => undefined);
    }, 15 * 60 * 1000);
    function refreshOnFocus() {
      if (document.visibilityState !== "visible") return;
      void loadAdminData();
      void loadLatestResult().catch(() => undefined);
    }
    document.addEventListener("visibilitychange", refreshOnFocus);
    return () => {
      window.clearTimeout(initialTimer);
      window.clearInterval(dataTimer);
      window.clearInterval(resultTimer);
      document.removeEventListener("visibilitychange", refreshOnFocus);
    };
  }, [loadAdminData, loadLatestResult]);

  const reservedByNumber = useMemo(
    () => new Map(reservations.map((reservation) => [reservation.number, reservation])),
    [reservations],
  );
  const paidCount = reservations.filter((item) => item.status === "paid").length;
  const currentPendingCount = reservations.filter(
    (item) => item.status === "pending",
  ).length;
  const previousPendingCount = pendingFinalizationReservations.length;
  const pendingCount = currentPendingCount + previousPendingCount;
  const entriesClosed = Boolean(draw && draw.status !== "open");

  async function toggleEntries() {
    if (!draw || (draw.status !== "open" && draw.status !== "closed")) return;
    setToggleState("loading");
    setToggleError("");
    try {
      const response = await fetch("/api/admin/draw", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          status: draw.status === "open" ? "closed" : "open",
          drawId: draw.id,
          contest: draw.contest,
        }),
      });
      const payload = (await response.json()) as { draw?: DrawInfo; error?: string };
      if (!response.ok || !payload.draw) {
        throw new Error(payload.error ?? "Não foi possível alterar o estado das escolhas.");
      }
      setDraw(payload.draw);
    } catch (error) {
      setToggleError(
        error instanceof Error
          ? error.message
          : "Não foi possível alterar o estado das escolhas.",
      );
    } finally {
      setToggleState("idle");
    }
  }

  async function syncOfficialResult() {
    const target = awaitingResults[0];
    if (!target) {
      setSyncState("loading");
      setSyncMessage("");
      try {
        await loadLatestResult();
        setSyncMessage("Não há nenhuma semana fechada por arquivar.");
        setSyncState("ok");
      } catch (error) {
        setSyncMessage(
          error instanceof Error
            ? error.message
            : "Não foi possível consultar o resultado oficial.",
        );
        setSyncState("error");
      }
      return;
    }

    const targetPending = pendingFinalizationReservations.filter(
      (reservation) => reservation.drawId === target.id,
    );
    if (targetPending.length > 0) {
      setSyncMessage(
        `Resolve primeiro ${targetPending.length} pagamento${targetPending.length === 1 ? "" : "s"} pendente${targetPending.length === 1 ? "" : "s"} da semana de ${formatLongDrawDate(target.drawDate)}.`,
      );
      setSyncState("error");
      return;
    }

    const confirmed = window.confirm(
      `Processar e arquivar a semana de ${formatLongDrawDate(target.drawDate)} (${target.contest})?\n\nO sistema consultará a ordem oficial, atribuirá prémios apenas a pagamentos confirmados e removerá as participações não vencedoras.`,
    );
    if (!confirmed) return;

    setSyncState("loading");
    setSyncMessage("");
    try {
      const response = await fetch("/api/admin/weekly", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ drawId: target.id }),
      });
      if (response.status === 401) {
        router.replace("/admin/login");
        return;
      }
      const payload = (await response.json()) as {
        results?: Array<{ status: string; message: string }>;
        message?: string;
        error?: string;
      };
      if (!response.ok) {
        throw new Error(payload.error ?? "Não foi possível processar a semana.");
      }
      setSyncMessage(payload.message ?? "Verificação concluída.");
      const hasError = payload.results?.some(
        (item) =>
          item.status !== "processed" &&
          item.status !== "already-processed",
      );
      setSyncState(hasError ? "error" : "ok");
      await Promise.all([
        loadAdminData(),
        loadLatestResult().catch(() => undefined),
      ]);
    } catch (error) {
      setSyncMessage(
        error instanceof Error
          ? error.message
          : "Não foi possível processar a semana.",
      );
      setSyncState("error");
    }
  }

  return (
    <main>
      <div className="demo-strip private-strip">
        <span className="lock-dot" aria-hidden="true">●</span>
        Área privada · sessão protegida
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

      <AdminView
        reservations={reservations}
        pendingFinalizationReservations={pendingFinalizationReservations}
        reservedByNumber={reservedByNumber}
        draw={draw}
        awaitingResults={awaitingResults}
        paidCount={paidCount}
        pendingCount={pendingCount}
        currentPendingCount={currentPendingCount}
        previousPendingCount={previousPendingCount}
        entriesClosed={entriesClosed}
        result={result}
        syncState={syncState}
        syncMessage={syncMessage}
        toggleState={toggleState}
        toggleError={toggleError}
        loadError={loadError}
        reservationsLoading={reservationsLoading}
        onToggleClosed={toggleEntries}
        onSync={syncOfficialResult}
      />

      <footer>
        <div className="brand footer-brand">
          <span className="brand-mark">50</span>
          <span>Sexta<sup>+</sup></span>
        </div>
        <p>Painel reservado ao administrador.</p>
        <p className="footer-small">A sessão termina automaticamente ao fim de oito horas.</p>
      </footer>
    </main>
  );
}

function AdminView(props: AdminProps) {
  const pending = Array.from(
    new Map(
      [
        ...props.pendingFinalizationReservations,
        ...props.reservations.filter((item) => item.status === "pending"),
      ].map((reservation) => [
        reservation.id ?? `${reservation.drawId ?? "current"}-${reservation.number}`,
        reservation,
      ]),
    ).values(),
  );
  const targetDraw = props.awaitingResults[0];
  const targetPending = targetDraw
    ? props.pendingFinalizationReservations.filter(
        (reservation) => reservation.drawId === targetDraw.id,
      )
    : [];
  const date = closeDetails(props.draw?.closesAt);
  const hasCurrentDraw = Boolean(props.draw);
  const priceCents = props.draw?.priceCents;
  const collectedCents =
    typeof priceCents === "number" ? props.paidCount * priceCents : undefined;
  const reservedCents =
    typeof priceCents === "number"
      ? props.reservations.length * priceCents
      : undefined;
  const drawFinalized = props.draw?.status === "resulted" || props.draw?.status === "archived";
  return (
    <div className="admin-shell" id="top">
      <section className="admin-intro">
        <div>
          <div className="eyebrow"><span>●</span> PAINEL DE CONTROLO</div>
          <h1>Olá, administrador.</h1>
          <p>
            {props.reservationsLoading && !hasCurrentDraw
              ? "A carregar os dados reais da semana."
              : props.loadError && !hasCurrentDraw
                ? "Não foi possível confirmar os dados da semana."
                : props.pendingCount === 0
                  ? "Não tens pagamentos por confirmar."
                  : `Tens ${props.pendingCount} pagamento${props.pendingCount === 1 ? "" : "s"} por confirmar${props.previousPendingCount > 0 ? `, incluindo ${props.previousPendingCount} de semanas anteriores` : ""}.`}
          </p>
        </div>
        <div className="admin-close-action">
          <Link className="history-link-button" href="/admin/historico">
            Histórico de vencedores <span>→</span>
          </Link>
          <button
            className={props.entriesClosed ? "primary-button reopen" : "primary-button danger"}
            onClick={props.onToggleClosed}
            disabled={props.toggleState === "loading" || !props.draw || drawFinalized}
          >
            {props.toggleState === "loading"
              ? "A guardar…"
              : !props.draw
                ? props.reservationsLoading
                  ? "A carregar semana…"
                  : "Estado indisponível"
                : drawFinalized
                  ? "Semana finalizada"
                  : props.entriesClosed
                    ? "Reabrir escolhas"
                    : "Encerrar escolhas"}
          </button>
          {props.toggleError && <p className="sync-error">{props.toggleError}</p>}
        </div>
      </section>

      {props.loadError && (
        <p className="admin-load-error" role="alert">
          {props.loadError} O painel mantém os últimos dados carregados.
        </p>
      )}

      <section className="stats-grid">
        <article>
          <span>OCUPAÇÃO</span>
          <strong>
            {hasCurrentDraw ? props.reservations.length : "—"}
            {hasCurrentDraw && <small>/50</small>}
          </strong>
          <div className="mini-track">
            <i
              style={{
                width: hasCurrentDraw
                  ? `${props.reservations.length * 2}%`
                  : "0%",
              }}
            />
          </div>
          <p>
            {hasCurrentDraw
              ? `${50 - props.reservations.length} números livres`
              : "A aguardar dados reais"}
          </p>
        </article>
        <article>
          <span>PAGAMENTOS</span>
          <strong>
            {hasCurrentDraw ? props.paidCount : "—"}
            {hasCurrentDraw && <small> pagos</small>}
          </strong>
          <p className="warning-text">
            {hasCurrentDraw
              ? `● ${props.currentPendingCount} desta semana por confirmar`
              : "● A aguardar dados reais"}
          </p>
          {props.previousPendingCount > 0 && (
            <p>+ {props.previousPendingCount} de semanas anteriores</p>
          )}
        </article>
        <article>
          <span>RECEBIDO</span>
          <strong>{formatMoneyCents(collectedCents)}</strong>
          <p>
            {hasCurrentDraw
              ? `de ${formatMoneyCents(reservedCents)} reservados`
              : "A aguardar dados reais"}
          </p>
        </article>
        <article className="date-stat">
          <span>PRÓXIMO FECHO</span>
          <strong>{date.day} <small>{date.month}</small></strong>
          <p>
            {hasCurrentDraw
              ? `Sexta-feira · ${date.time}`
              : "A aguardar semana"}
          </p>
        </article>
      </section>

      <section className="admin-grid">
        <article className="panel map-panel">
          <div className="panel-head"><div><span>MAPA DOS NÚMEROS</span><h2>Semana {weekNumber(props.draw?.contest)}</h2></div><div className="legend"><span><i className="legend-free" /> Livre</span><span><i className="legend-taken" /> Pago</span><span><i className="legend-pending" /> Pendente</span></div></div>
          <div
            className="admin-number-grid"
            aria-busy={props.reservationsLoading}
          >
            {Array.from({ length: 50 }, (_, index) => index + 1).map((number) => {
              const reservation = props.reservedByNumber.get(number);
              const content = (
                <>
                  <strong>{number}</strong>
                  <small>
                    {reservation
                      ? reservation.name.slice(0, 7)
                      : hasCurrentDraw
                        ? "—"
                        : "…"}
                  </small>
                </>
              );
              return reservation?.id ? (
                <Link
                  key={number}
                  className={`admin-number ${reservation.status}`}
                  href={`/admin/pagamentos/${reservation.id}`}
                  title={`Abrir a ficha de ${reservation.name}`}
                  aria-label={`Abrir a ficha de ${reservation.name}, número ${number}`}
                >
                  {content}
                </Link>
              ) : (
                <div
                  key={number}
                  className={`admin-number ${hasCurrentDraw ? "free" : "loading"}`}
                >
                  {content}
                </div>
              );
            })}
          </div>
        </article>

        <article className="panel payments-panel" id="pagamentos">
          <div className="panel-head"><div><span>AÇÃO NECESSÁRIA</span><h2>Por confirmar</h2></div><b>{props.reservationsLoading && !hasCurrentDraw ? "—" : pending.length}</b></div>
          <div className="payment-list">
            {pending.map((item) => (
              <Link
                className="payment-row"
                href={`/admin/pagamentos/${item.id}`}
                key={item.id ?? item.number}
                aria-label={`Ver pagamento de ${item.name}, número ${item.number}`}
              >
                <span className="payment-number">{item.number}</span>
                <div>
                  <strong>{item.name}</strong>
                  <small>{formatAdminPhone(item.phone)} · {((item.priceCents ?? 250) / 100).toLocaleString("pt-PT", { style: "currency", currency: "EUR" })}</small>
                  {item.drawDate && (
                    <small className="payment-week-badge">
                      {formatLongDrawDate(item.drawDate)}
                      {item.contest ? ` · ${item.contest}` : ""}
                    </small>
                  )}
                </div>
                <span className="payment-open">Ver ficha →</span>
              </Link>
            ))}
            {!props.reservationsLoading && !props.loadError && pending.length === 0 && (
              <div className="payment-empty">
                <span>✓</span>
                <strong>Está tudo confirmado.</strong>
                <small>As novas reservas pendentes aparecem aqui.</small>
              </div>
            )}
            {props.reservationsLoading && (
              <div className="payment-loading"><span className="spinner" /> A carregar pagamentos…</div>
            )}
          </div>
          <p className="panel-tip">Abre a ficha individual e confirma apenas depois de verificares o movimento no MB WAY.</p>
        </article>
      </section>

      <section className="admin-grid lower-grid">
        <article className="panel official-panel">
          <div className="panel-head"><div><span>RESULTADO OFICIAL</span><h2>Jogos Santa Casa</h2></div><span className="verified-dot">{props.result ? "● verificado" : "○ a consultar"}</span></div>
          <div className="official-result-row">
            <div><small>Concurso</small><strong>{props.result?.contest ?? "A aguardar"}</strong><span>{props.result?.date ?? "Fonte oficial"}</span></div>
            <div className="winning-balls small-balls">{props.result?.drawOrder.slice(0, 3).map((number, index) => <span key={number} className={`ball ball-${index + 1}`}><small>{index + 1}.º</small>{number}</span>)}</div>
          </div>
          {targetDraw && (
            <div className="processing-target">
              <span>PRÓXIMA SEMANA A ARQUIVAR</span>
              <strong>{formatLongDrawDate(targetDraw.drawDate)}</strong>
              <small>
                {targetDraw.contest} ·{" "}
                {targetPending.length > 0
                  ? `${targetPending.length} pagamento${targetPending.length === 1 ? "" : "s"} por resolver`
                  : "todos os pagamentos estão decididos"}
              </small>
            </div>
          )}
          <button className="secondary-button" onClick={props.onSync} disabled={props.syncState === "loading"}>
            {props.syncState === "loading"
              ? "A processar…"
              : props.syncState === "ok"
                ? "Verificação concluída ✓"
                : props.syncState === "error"
                  ? "Tentar novamente"
                  : targetDraw && targetPending.length > 0
                    ? `Resolver ${targetPending.length} pagamento${targetPending.length === 1 ? "" : "s"}`
                    : targetDraw
                      ? "Processar e arquivar esta semana"
                    : "Verificar resultado e arquivo"}
            <span>↻</span>
          </button>
          {props.syncMessage && (
            <p className={props.syncState === "error" ? "sync-error" : "sync-success"}>
              {props.syncMessage}
            </p>
          )}
        </article>

        <article className="panel automation-panel">
          <div className="panel-head"><div><span>AUTOMAÇÃO DE SEXTA</span><h2>Depois do sorteio</h2></div></div>
          <ol>
            <li><b>1</b><span><strong>Consultar a ordem de saída</strong><small>Jogos Santa Casa · fonte oficial</small></span><em>automático</em></li>
            <li><b>2</b><span><strong>Atribuir os três prémios</strong><small>1.º, 2.º e 3.º números</small></span><em>automático</em></li>
            <li><b>3</b><span><strong>Preparar mensagens WhatsApp</strong><small>O administrador confirma antes do envio</small></span><em>manual</em></li>
            <li><b>4</b><span><strong>Arquivar a semana</strong><small>Manter vencedores e totais</small></span><em>automático</em></li>
          </ol>
          <p className="automation-note">
            Depois de resolveres todos os pagamentos pendentes, o botão consulta
            a fonte oficial, atribui apenas prémios pagos, limpa os não vencedores
            e guarda a semana no histórico.
          </p>
        </article>
      </section>

      <section className="legal-note">
        <span>!</span>
        <p><strong>Pagamento com confirmação manual.</strong> Este fluxo usa a função “Enviar Dinheiro” da app MB WAY; o site não inicia nem valida a transferência automaticamente. Antes de cobrar participações, confirma o enquadramento legal e fiscal aplicável ao sorteio.</p>
      </section>
    </div>
  );
}
