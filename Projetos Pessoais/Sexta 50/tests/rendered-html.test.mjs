import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("server-renders the Sexta 50 participant experience", async () => {
  const [page, layout, weeklyClub, publicWeek] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/weekly-club.tsx", import.meta.url), "utf8"),
    readFile(new URL("../lib/public-week.ts", import.meta.url), "utf8"),
  ]);

  assert.match(page, /Sexta 50/);
  assert.match(page, /dynamic = "force-dynamic"/);
  assert.match(page, /getPublicWeekSnapshot/);
  assert.match(page, /<WeeklyClub initialSnapshot=/);
  assert.match(layout, /lang="pt-PT"/);
  assert.match(publicWeek, /getOrCreateCurrentDraw/);
  assert.match(publicWeek, /\["paid", "pending"\]/);
  assert.match(weeklyClub, /O teu número\./);
  assert.match(weeklyClub, /Transferência MB WAY/);
  assert.match(weeklyClub, /Área do administrador/);
  assert.match(weeklyClub, /Resultado oficial/);
  assert.match(weeklyClub, /A confirmar ocupação/);
  assert.match(weeklyClub, /Mapa temporariamente indisponível/);
  assert.doesNotMatch(
    `${page}\n${layout}\n${weeklyClub}\n${publicWeek}`,
    /Your site is taking shape|Building your site/,
  );
});

test("ships real result and history flows without demo winners", async () => {
  const [weeklyClub, history, confirmation, schema, processing] =
    await Promise.all([
      readFile(new URL("../app/weekly-club.tsx", import.meta.url), "utf8"),
      readFile(
        new URL("../app/admin/historico/history-view.tsx", import.meta.url),
        "utf8",
      ),
      readFile(
        new URL(
          "../app/confirmacao/[token]/confirmation-area.tsx",
          import.meta.url,
        ),
        "utf8",
      ),
      readFile(new URL("../db/schema.ts", import.meta.url), "utf8"),
      readFile(new URL("../lib/weekly-processing.ts", import.meta.url), "utf8"),
    ]);

  assert.doesNotMatch(
    `${weeklyClub}\n${history}`,
    /initialReservations|fallbackResult|previousWinners|Ex\.: Marta|Boa tarde/,
  );
  assert.match(weeklyClub, /\/api\/results\/latest/);
  assert.match(weeklyClub, /15 \* 60 \* 1000/);
  assert.match(weeklyClub, /\/admin\/historico/);
  assert.match(history, /Pesquisar no histórico/);
  assert.match(history, /processares e arquivares a primeira semana/);
  assert.match(confirmation, /serverVerified/);
  assert.match(confirmation, /formatClosingSchedule/);
  assert.doesNotMatch(confirmation, /Sexta-feira às 19:00/);
  assert.match(schema, /"released"/);
  assert.match(schema, /winnerName/);
  assert.match(processing, /payment_status = 'paid'/);
  assert.match(processing, /status = 'archived'/);
});
