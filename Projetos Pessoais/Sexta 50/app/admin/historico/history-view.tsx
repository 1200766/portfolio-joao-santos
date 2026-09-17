"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

type ArchivedPrize = {
  rank: number;
  number: number;
  outcome: "awarded" | "no_paid_reservation";
  name: string | null;
  phone: string | null;
  paidAt: string | null;
  notifiedAt: string | null;
};

type ArchivedWeek = {
  drawId: number;
  contest: string;
  officialContest: string | null;
  drawDate: string;
  drawOrder: number[];
  sourceUrl: string | null;
  archivedAt: string | null;
  reservationCount: number;
  paidCount: number;
  collectedCents: number;
  prizes: ArchivedPrize[];
};

type HistoryPayload = {
  weeks: ArchivedWeek[];
  summary: {
    weeks: number;
    winners: number;
    collectedCents: number;
  };
};

function formatDrawDate(value: string) {
  const date = new Date(`${value}T12:00:00Z`);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("pt-PT", {
    weekday: "long",
    day: "2-digit",
    month: "long",
    year: "numeric",
    timeZone: "Europe/Lisbon",
  }).format(date);
}

function formatMoney(cents: number) {
  return (cents / 100).toLocaleString("pt-PT", {
    style: "currency",
    currency: "EUR",
  });
}

function formatPhone(value: string | null) {
  if (!value) return "";
  const digits = value.replace(/\D/g, "");
  if (digits.length !== 9) return value;
  return `+351 ${digits.slice(0, 3)} ${digits.slice(3, 6)} ${digits.slice(6)}`;
}

function whatsappLink(week: ArchivedWeek, prize: ArchivedPrize) {
  if (!prize.phone || !prize.name) return null;
  const digits = prize.phone.replace(/\D/g, "");
  const message = encodeURIComponent(
    `Olá ${prize.name}! O número ${prize.number} recebeu o ${prize.rank}.º prémio da Sexta 50 no sorteio de ${formatDrawDate(week.drawDate)}.`,
  );
  return `https://wa.me/351${digits}?text=${message}`;
}

export function AdminHistory() {
  const router = useRouter();
  const [payload, setPayload] = useState<HistoryPayload | null>(null);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [retryKey, setRetryKey] = useState(0);

  useEffect(() => {
    let active = true;
    fetch("/api/admin/history", { cache: "no-store" })
      .then(async (response) => {
        if (response.status === 401) {
          router.replace("/admin/login");
          return null;
        }
        const body = (await response.json()) as HistoryPayload & {
          error?: string;
        };
        if (!response.ok) {
          throw new Error(body.error ?? "Não foi possível abrir o histórico.");
        }
        return body;
      })
      .then((body) => {
        if (active && body) setPayload(body);
      })
      .catch((reason: unknown) => {
        if (active) {
          setError(
            reason instanceof Error
              ? reason.message
              : "Não foi possível abrir o histórico.",
          );
        }
      })
      .finally(() => {
        if (active) setLoading(false);
      });

    return () => {
      active = false;
    };
  }, [retryKey, router]);

  const filteredWeeks = useMemo(() => {
    const query = search.trim().toLocaleLowerCase("pt-PT");
    if (!query) return payload?.weeks ?? [];
    return (payload?.weeks ?? []).filter((week) => {
      const searchable = [
        week.contest,
        week.officialContest ?? "",
        week.drawDate,
        ...week.drawOrder.map(String),
        ...week.prizes.flatMap((prize) => [
          prize.name ?? "",
          String(prize.number),
          String(prize.rank),
        ]),
      ]
        .join(" ")
        .toLocaleLowerCase("pt-PT");
      return searchable.includes(query);
    });
  }, [payload?.weeks, search]);

  function retry() {
    setError("");
    setLoading(true);
    setRetryKey((value) => value + 1);
  }

  return (
    <main className="history-page">
      <div className="demo-strip private-strip">
        <span className="lock-dot" aria-hidden="true">●</span>
        Área privada · arquivo real
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

      <div className="history-shell">
        <section className="history-hero">
          <div>
            <div className="eyebrow"><span>●</span> MEMÓRIA DO GRUPO</div>
            <h1>Histórico de vencedores.</h1>
            <p>
              Cada semana arquivada mostra a ordem oficial e apenas atribui
              prémios a pagamentos que confirmaste.
            </p>
          </div>
          <Link className="secondary-button history-back" href="/admin">
            ← Voltar ao painel
          </Link>
        </section>

        {loading && (
          <div className="history-loading">
            <span className="spinner" aria-hidden="true" />
            A organizar o histórico…
          </div>
        )}
        {error && (
          <div className="history-error" role="alert">
            <span>{error}</span>
            <button type="button" onClick={retry}>
              Tentar novamente
            </button>
          </div>
        )}

        {payload && (
          <>
            <section className="history-stats">
              <article><span>SEMANAS</span><strong>{payload.summary.weeks}</strong><small>arquivadas</small></article>
              <article><span>VENCEDORES</span><strong>{payload.summary.winners}</strong><small>com pagamento confirmado</small></article>
              <article><span>RECEBIDO</span><strong>{formatMoney(payload.summary.collectedCents)}</strong><small>nas semanas arquivadas</small></article>
            </section>

            <label className="history-search">
              <span>Pesquisar por nome, número, data ou concurso</span>
              <input
                type="search"
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Pesquisar no histórico"
              />
            </label>

            <section className="history-list" aria-live="polite">
              {filteredWeeks.map((week) => (
                <article className="history-week" key={week.drawId}>
                  <header>
                    <div>
                      <span>SEXTA-FEIRA ARQUIVADA</span>
                      <h2>{formatDrawDate(week.drawDate)}</h2>
                      <p>
                        Concurso oficial {week.officialContest ?? "—"} ·{" "}
                        {week.paidCount} pagamentos confirmados ·{" "}
                        {formatMoney(week.collectedCents)}
                      </p>
                    </div>
                    <div className="history-balls" aria-label="Ordem oficial">
                      {week.drawOrder.slice(0, 3).map((number, index) => (
                        <span className={`ball-${index + 1}`} key={`${number}-${index}`}>
                          <small>{index + 1}.º</small>{number}
                        </span>
                      ))}
                    </div>
                  </header>

                  <div className="history-prizes">
                    {week.prizes.map((prize) => {
                      const whatsapp = whatsappLink(week, prize);
                      return (
                        <div
                          className={`history-prize rank-${prize.rank} ${prize.outcome}`}
                          key={prize.rank}
                        >
                          <span className="history-rank">{prize.rank}.º</span>
                          <strong>{String(prize.number).padStart(2, "0")}</strong>
                          <div>
                            <b>{prize.name ?? "Sem vencedor pago"}</b>
                            <small>
                              {prize.outcome === "awarded"
                                ? formatPhone(prize.phone)
                                : "O número não tinha pagamento confirmado"}
                            </small>
                          </div>
                          {whatsapp ? (
                            <a href={whatsapp} target="_blank" rel="noreferrer">
                              WhatsApp ↗
                            </a>
                          ) : (
                            <span className="no-winner">não atribuído</span>
                          )}
                        </div>
                      );
                    })}
                  </div>

                  {week.sourceUrl && (
                    <a
                      className="history-source"
                      href={week.sourceUrl}
                      target="_blank"
                      rel="noreferrer"
                    >
                      Consultar fonte oficial ↗
                    </a>
                  )}
                </article>
              ))}

              {filteredWeeks.length === 0 && (
                <div className="history-empty">
                  <span>50</span>
                  <h2>
                    {payload.weeks.length === 0
                      ? "Ainda não há semanas arquivadas."
                      : "Não encontrámos resultados para esta pesquisa."}
                  </h2>
                  <p>
                    {payload.weeks.length === 0
                      ? "Depois de processares e arquivares a primeira semana no painel, os vencedores aparecem aqui."
                      : "Experimenta pesquisar por outro nome, número ou concurso."}
                  </p>
                </div>
              )}
            </section>
          </>
        )}
      </div>
    </main>
  );
}
