import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

const base = process.env.SEXTA50_TEST_URL ?? "http://localhost:3000";
const database = path.resolve(process.env.SEXTA50_TEST_DB ?? "");
const temporaryRoot = path.resolve(tmpdir()) + path.sep;

if (
  !process.env.SEXTA50_TEST_DB ||
  !database.startsWith(temporaryRoot) ||
  !database.includes(`${path.sep}sexta50-integration-`) ||
  !database.endsWith(".sqlite") ||
  !existsSync(database)
) {
  throw new Error(
    "O teste de integração requer uma base SQLite descartável criada pelo respetivo runner.",
  );
}
const results = [];
let currentDraw = null;

function sql(statement) {
  return execFileSync("sqlite3", [database, statement]).toString().trim();
}

function check(name, condition, details = "") {
  results.push({ name, ok: Boolean(condition), details });
}

async function jsonResponse(route, options = {}) {
  const response = await fetch(`${base}${route}`, options);
  let payload = {};
  try {
    payload = await response.json();
  } catch {
    // Some redirect/error responses intentionally have no JSON body.
  }
  return { response, payload };
}

async function reserve(number, suffix) {
  return jsonResponse("/api/reservations", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      number,
      name: `Teste fluxo ${suffix}`,
      phone: String(910000000 + suffix).slice(0, 9),
      consent: true,
      drawId: currentDraw?.id,
      contest: currentDraw?.contest,
    }),
  });
}

sql(`
  DELETE FROM prizes
  WHERE draw_id IN (
    SELECT id FROM draws WHERE contest = 'TEST-FINALIZE-2026-W30'
  );
  DELETE FROM reservations
  WHERE display_name LIKE 'Teste fluxo %'
     OR draw_id IN (
       SELECT id FROM draws WHERE contest = 'TEST-FINALIZE-2026-W30'
     );
  DELETE FROM draws WHERE contest = 'TEST-FINALIZE-2026-W30';
`);

const initial = await jsonResponse("/api/reservations");
currentDraw = initial.payload.draw;
check("mapa público responde", initial.response.status === 200);
check("semana atual disponível", Boolean(currentDraw?.id && currentDraw?.contest));

const login = await fetch(`${base}/api/admin/login`, {
  method: "POST",
  redirect: "manual",
  headers: { "Content-Type": "application/x-www-form-urlencoded" },
  body: new URLSearchParams({
    username: "Test",
    password: "test-secret",
  }),
});
const cookie = login.headers.get("set-cookie")?.split(";")[0] ?? "";
check(
  "login do administrador",
  login.status === 303 && cookie.includes("sexta50_admin="),
  String(login.status),
);

async function setDrawStatus(status) {
  return jsonResponse("/api/admin/draw", {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      Cookie: cookie,
    },
    body: JSON.stringify({
      status,
      drawId: currentDraw.id,
      contest: currentDraw.contest,
    }),
  });
}

await setDrawStatus("open");
const activeNumbers = new Set(
  initial.payload.reservations?.map((reservation) => reservation.number) ?? [],
);
const freeNumbers = Array.from({ length: 50 }, (_, index) => index + 1).filter(
  (number) => !activeNumbers.has(number),
);
const [persistentNumber, concurrentNumber, paidNumber] = freeNumbers;

const persistent = await reserve(persistentNumber, 101);
check(
  "primeira reserva é aceite",
  persistent.response.status === 201 &&
    persistent.payload.reservation?.expiresAt === null,
  JSON.stringify(persistent.payload),
);

const duplicate = await reserve(persistentNumber, 102);
check(
  "número bloqueado devolve mensagem amigável",
  duplicate.response.status === 409 &&
    /escolhido/i.test(duplicate.payload.error ?? ""),
  `${duplicate.response.status} ${JSON.stringify(duplicate.payload)}`,
);

const simultaneous = await Promise.all(
  Array.from({ length: 10 }, (_, index) =>
    reserve(concurrentNumber, 120 + index),
  ),
);
const statuses = simultaneous.map(({ response }) => response.status);
check(
  "dez pedidos simultâneos têm um único vencedor e nenhum erro 500",
  statuses.filter((status) => status === 201).length === 1 &&
    statuses.filter((status) => status === 409).length === 9,
  JSON.stringify(statuses),
);
check(
  "todas as recusas concorrentes são amigáveis",
  simultaneous
    .filter(({ response }) => response.status === 409)
    .every(({ payload }) => /escolhido/i.test(payload.error ?? "")),
);

sql(`
  UPDATE reservations
  SET expires_at = '2000-01-01T00:00:00.000Z'
  WHERE display_name = 'Teste fluxo 101'
    AND payment_status = 'pending';
`);
const afterOldDeadline = await jsonResponse("/api/reservations");
check(
  "uma data antiga já não liberta a reserva",
  afterOldDeadline.payload.reservations?.some(
    (reservation) => reservation.number === persistentNumber,
  ),
);
const personalPending = await jsonResponse(
  `/api/reservations/${persistent.payload.token}`,
);
check(
  "área individual continua pendente sem expirar",
  personalPending.payload.reservation?.status === "pending",
  JSON.stringify(personalPending.payload),
);
const serverRenderedMap = await fetch(`${base}/`, { cache: "no-store" });
const serverRenderedHtml = await serverRenderedMap.text();
check(
  "HTML inicial já contém os dados reais, sem esperar pelo browser",
  serverRenderedMap.status === 200 &&
    serverRenderedHtml.includes("Teste fluxo 101"),
);

const adminReservations = await jsonResponse("/api/admin/reservations", {
  headers: { Cookie: cookie },
});
const persistentRow = adminReservations.payload.reservations?.find(
  (reservation) =>
    reservation.number === persistentNumber &&
    reservation.name === "Teste fluxo 101",
);
const released = await jsonResponse(
  `/api/admin/reservations/${persistentRow?.id}`,
  {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      Cookie: cookie,
    },
    body: JSON.stringify({ action: "release" }),
  },
);
check(
  "administrador desbloqueia explicitamente a reserva",
  released.response.status === 200 &&
    released.payload.reservation?.status === "released",
  JSON.stringify(released.payload),
);

const releasedPersonal = await jsonResponse(
  `/api/reservations/${persistent.payload.token}`,
);
check(
  "área individual recebe o estado desbloqueado",
  releasedPersonal.payload.reservation?.status === "released",
);

const confirmReleased = await jsonResponse(
  `/api/admin/reservations/${persistentRow?.id}`,
  {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      Cookie: cookie,
    },
    body: JSON.stringify({ action: "confirm-payment" }),
  },
);
check(
  "uma reserva desbloqueada não pode ser confirmada",
  confirmReleased.response.status === 409,
);

const reused = await reserve(persistentNumber, 103);
check(
  "o número só fica livre depois do desbloqueio",
  reused.response.status === 201,
  JSON.stringify(reused.payload),
);

const pendingPaid = await reserve(paidNumber, 140);
const adminForPaid = await jsonResponse("/api/admin/reservations", {
  headers: { Cookie: cookie },
});
const pendingPaidRow = adminForPaid.payload.reservations?.find(
  (reservation) =>
    reservation.number === paidNumber &&
    reservation.name === "Teste fluxo 140",
);
const paid = await jsonResponse(
  `/api/admin/reservations/${pendingPaidRow?.id}`,
  {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      Cookie: cookie,
    },
    body: JSON.stringify({ action: "confirm-payment" }),
  },
);
check(
  "pagamento confirmado fica elegível",
  pendingPaid.response.status === 201 &&
    paid.response.status === 200 &&
    paid.payload.reservation?.status === "paid",
  JSON.stringify(paid.payload),
);

const duplicatePaid = await reserve(paidNumber, 141);
check(
  "um número pago continua bloqueado",
  duplicatePaid.response.status === 409,
  JSON.stringify(duplicatePaid.payload),
);
const unsafeRefund = await jsonResponse(
  `/api/admin/reservations/${pendingPaidRow?.id}`,
  {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      Cookie: cookie,
    },
    body: JSON.stringify({ action: "refund-and-release" }),
  },
);
check(
  "pagamento confirmado não é desbloqueado sem confirmar a devolução",
  unsafeRefund.response.status === 400,
);
const refunded = await jsonResponse(
  `/api/admin/reservations/${pendingPaidRow?.id}`,
  {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      Cookie: cookie,
    },
    body: JSON.stringify({
      action: "refund-and-release",
      refundConfirmed: true,
    }),
  },
);
check(
  "administrador pode corrigir um pagamento devolvido e desbloquear o número",
  refunded.response.status === 200 &&
    refunded.payload.reservation?.status === "refunded",
  JSON.stringify(refunded.payload),
);
const reusedPaidNumber = await reserve(paidNumber, 142);
const adminForReusedPaid = await jsonResponse("/api/admin/reservations", {
  headers: { Cookie: cookie },
});
const reusedPaidRow = adminForReusedPaid.payload.reservations?.find(
  (reservation) =>
    reservation.number === paidNumber &&
    reservation.name === "Teste fluxo 142",
);
const reconfirmedPaid = await jsonResponse(
  `/api/admin/reservations/${reusedPaidRow?.id}`,
  {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      Cookie: cookie,
    },
    body: JSON.stringify({ action: "confirm-payment" }),
  },
);
check(
  "o número corrigido pode ser escolhido e pago novamente",
  reusedPaidNumber.response.status === 201 &&
    reconfirmedPaid.payload.reservation?.status === "paid",
  JSON.stringify(reconfirmedPaid.payload),
);

const closed = await setDrawStatus("closed");
const adminAfterClose = await jsonResponse("/api/admin/reservations", {
  headers: { Cookie: cookie },
});
check(
  "encerrar escolhas fica persistente",
  closed.payload.draw?.status === "closed" &&
    adminAfterClose.payload.draw?.status === "closed",
);
const blocked = await reserve(freeNumbers[3], 150);
check(
  "semana encerrada recusa novas reservas",
  blocked.response.status === 409 && /encerradas/i.test(blocked.payload.error),
);
await setDrawStatus("open");

const anonymousHistory = await jsonResponse("/api/admin/history");
check(
  "histórico não é público",
  anonymousHistory.response.status === 401,
);
const historyPage = await fetch(`${base}/admin/historico`, {
  redirect: "manual",
  headers: { Cookie: cookie },
});
check("página privada do histórico abre", historyPage.status === 200);

sql(`
  INSERT INTO draws (
    contest,
    draw_date,
    closes_at,
    status,
    ticket_price_cents
  ) VALUES (
    'TEST-FINALIZE-2026-W30',
    '2026-07-24',
    '2026-07-24T18:00:00.000Z',
    'closed',
    250
  );
  INSERT INTO reservations (
    draw_id,
    chosen_number,
    display_name,
    phone,
    payment_status,
    paid_at
  )
  SELECT id, 47, 'Teste fluxo vencedor', '911111111', 'paid',
         '2026-07-24T17:00:00.000Z'
  FROM draws WHERE contest = 'TEST-FINALIZE-2026-W30';
  INSERT INTO reservations (
    draw_id,
    chosen_number,
    display_name,
    phone,
    payment_status
  )
  SELECT id, 30, 'Teste fluxo sem pagamento', '922222222', 'pending'
  FROM draws WHERE contest = 'TEST-FINALIZE-2026-W30';
  INSERT INTO reservations (
    draw_id,
    chosen_number,
    display_name,
    phone,
    payment_status,
    paid_at
  )
  SELECT id, 8, 'Teste fluxo não vencedor', '933333333', 'paid',
         '2026-07-24T17:10:00.000Z'
  FROM draws WHERE contest = 'TEST-FINALIZE-2026-W30';
`);
const archiveDrawId = Number(
  sql(
    "SELECT id FROM draws WHERE contest = 'TEST-FINALIZE-2026-W30' LIMIT 1;",
  ),
);
const missingWeeklyTarget = await jsonResponse("/api/admin/weekly", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    Cookie: cookie,
  },
  body: "{}",
});
check(
  "arquivo semanal exige uma semana concreta",
  missingWeeklyTarget.response.status === 400,
);

const blockedArchive = await jsonResponse("/api/admin/weekly", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    Cookie: cookie,
  },
  body: JSON.stringify({ drawId: archiveDrawId }),
});
check(
  "arquivo é bloqueado enquanto existir um pagamento pendente",
  blockedArchive.response.status === 200 &&
    blockedArchive.payload.results?.[0]?.status === "payments-pending",
  JSON.stringify(blockedArchive.payload),
);
check(
  "tentativa bloqueada não altera nem limpa a semana",
  sql(`
    SELECT status || ':' || COUNT(*)
    FROM draws
    JOIN reservations ON reservations.draw_id = draws.id
    WHERE draws.id = ${archiveDrawId};
  `) === "closed:3",
);

const archivePendingId = Number(
  sql(`
    SELECT id
    FROM reservations
    WHERE draw_id = ${archiveDrawId}
      AND payment_status = 'pending'
    LIMIT 1;
  `),
);
const releasedBeforeArchive = await jsonResponse(
  `/api/admin/reservations/${archivePendingId}`,
  {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      Cookie: cookie,
    },
    body: JSON.stringify({ action: "release" }),
  },
);
check(
  "administrador decide o pagamento pendente antes do arquivo",
  releasedBeforeArchive.response.status === 200 &&
    releasedBeforeArchive.payload.reservation?.status === "released",
  JSON.stringify(releasedBeforeArchive.payload),
);

const processed = await jsonResponse("/api/admin/weekly", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    Cookie: cookie,
  },
  body: JSON.stringify({ drawId: archiveDrawId }),
});
check(
  "resultado oficial processa e arquiva a semana",
  processed.response.status === 200 &&
    processed.payload.results?.[0]?.status === "processed",
  JSON.stringify(processed.payload),
);
check(
  "arquivo tem exatamente três posições",
  Number(
    sql(`SELECT COUNT(*) FROM prizes WHERE draw_id = ${archiveDrawId};`),
  ) === 3,
);
check(
  "só o número pago recebe prémio",
  sql(`
    SELECT group_concat(rank || ':' || outcome, ',')
    FROM prizes
    WHERE draw_id = ${archiveDrawId}
    ORDER BY rank;
  `) ===
    "1:awarded,2:no_paid_reservation,3:no_paid_reservation",
);
check(
  "não vencedores são removidos e vencedor é preservado",
  sql(`
    SELECT group_concat(chosen_number, ',')
    FROM reservations
    WHERE draw_id = ${archiveDrawId};
  `) === "47",
);
check(
  "totais da semana sobrevivem à limpeza",
  sql(`
    SELECT reservation_count || ':' || paid_count || ':' || collected_cents
    FROM draws
    WHERE id = ${archiveDrawId};
  `) === "2:2:500",
);

const processedAgain = await jsonResponse("/api/admin/weekly", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    Cookie: cookie,
  },
  body: JSON.stringify({ drawId: archiveDrawId }),
});
check(
  "processamento repetido é idempotente",
  processedAgain.payload.results?.[0]?.status === "already-processed" &&
    Number(
      sql(`SELECT COUNT(*) FROM prizes WHERE draw_id = ${archiveDrawId};`),
    ) === 3,
  JSON.stringify(processedAgain.payload),
);

const history = await jsonResponse("/api/admin/history", {
  headers: { Cookie: cookie },
});
const archivedWeek = history.payload.weeks?.find(
  (week) => week.drawId === archiveDrawId,
);
check(
  "histórico real mostra o vencedor e as posições sem vencedor",
  history.response.status === 200 &&
    archivedWeek?.prizes?.[0]?.name === "Teste fluxo vencedor" &&
    archivedWeek.prizes.filter((prize) => prize.outcome === "awarded").length ===
      1,
  JSON.stringify(archivedWeek),
);

const activeDuplicates = Number(
  sql(`
    SELECT COUNT(*) FROM (
      SELECT draw_id, chosen_number
      FROM reservations
      WHERE payment_status IN ('pending', 'paid')
      GROUP BY draw_id, chosen_number
      HAVING COUNT(*) > 1
    );
  `),
);
check("não existem números ativos duplicados", activeDuplicates === 0);

for (const result of results) {
  console.log(
    `${result.ok ? "PASS" : "FAIL"}  ${result.name}${
      result.ok || !result.details ? "" : ` — ${result.details}`
    }`,
  );
}

const failed = results.filter((result) => !result.ok);
console.log(`\n${results.length - failed.length}/${results.length} testes passaram`);
if (failed.length) process.exitCode = 1;
