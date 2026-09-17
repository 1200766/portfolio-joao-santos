import { and, eq, inArray } from "drizzle-orm";
import { getDb } from "../../../../db";
import { draws } from "../../../../db/schema";
import { getOrCreateCurrentDraw } from "../../../../lib/current-draw";
import {
  readAdminCookie,
  verifyAdminSession,
} from "../../../../lib/admin-auth";
import {
  isDatabaseBusyError,
  retryDatabaseBusy,
} from "../../../../lib/database-retry";

async function hasAdminSession(request: Request) {
  return verifyAdminSession(readAdminCookie(request));
}

export async function PATCH(request: Request) {
  if (!(await hasAdminSession(request))) {
    return Response.json({ error: "Sessão inválida." }, { status: 401 });
  }

  try {
    const payload = (await request.json()) as {
      status?: string;
      drawId?: number;
      contest?: string;
    };
    if (payload.status !== "open" && payload.status !== "closed") {
      return Response.json(
        { error: "Estado da semana inválido." },
        { status: 400 },
      );
    }
    const status = payload.status;

    const db = getDb();
    const { draw } = await getOrCreateCurrentDraw();

    if (payload.drawId !== draw.id || payload.contest !== draw.contest) {
      return Response.json(
        { error: "A semana mudou. Atualiza o painel antes de continuar." },
        { status: 409 },
      );
    }

    if (draw.status === "resulted" || draw.status === "archived") {
      return Response.json(
        { error: "Esta semana já não pode ser reaberta." },
        { status: 409 },
      );
    }

    const [updated] = await retryDatabaseBusy(() =>
      db
        .update(draws)
        .set({ status })
        .where(
          and(
            eq(draws.id, draw.id),
            inArray(draws.status, ["open", "closed"]),
          ),
        )
        .returning({
          id: draws.id,
          contest: draws.contest,
          drawDate: draws.drawDate,
          closesAt: draws.closesAt,
          status: draws.status,
          priceCents: draws.ticketPriceCents,
        }),
    );

    if (!updated) {
      return Response.json(
        { error: "O estado da semana mudou. Atualiza a página e tenta novamente." },
        { status: 409 },
      );
    }

    return Response.json(
      { draw: updated },
      { headers: { "Cache-Control": "private, no-store" } },
    );
  } catch (error) {
    console.error("admin draw update failed", error);
    if (isDatabaseBusyError(error)) {
      return Response.json(
        {
          error:
            "O sistema está muito ocupado. O estado não foi alterado; tenta novamente.",
        },
        { status: 503 },
      );
    }
    return Response.json(
      { error: "Não foi possível alterar o estado das escolhas." },
      { status: 500 },
    );
  }
}
