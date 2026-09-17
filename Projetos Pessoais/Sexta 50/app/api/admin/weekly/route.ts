import {
  readAdminCookie,
  verifyAdminSession,
} from "../../../../lib/admin-auth";
import { processDueDraws } from "../../../../lib/weekly-processing";

async function hasAdminSession(request: Request) {
  return verifyAdminSession(readAdminCookie(request));
}

export async function POST(request: Request) {
  if (!(await hasAdminSession(request))) {
    return Response.json({ error: "Sessão inválida." }, { status: 401 });
  }

  try {
    const payload = (await request.json().catch(() => ({}))) as {
      drawId?: number;
    };
    const drawId = Number(payload.drawId);
    if (!Number.isInteger(drawId) || drawId < 1) {
      return Response.json(
        { error: "Escolhe uma semana concreta para processar." },
        { status: 400 },
      );
    }

    const results = await processDueDraws({
      force: true,
      drawId,
    });
    if (results.length === 0) {
      return Response.json(
        { error: "A semana indicada não foi encontrada." },
        { status: 404 },
      );
    }
    const processed = results.filter(
      (result) =>
        result.status === "processed" ||
        result.status === "already-processed",
    ).length;
    const message =
      results.length === 0
        ? "Não há semanas por processar."
        : processed > 0
          ? results.map((result) => result.message).join(" ")
          : results[0].message;

    return Response.json(
      { results, message },
      { headers: { "Cache-Control": "private, no-store" } },
    );
  } catch (error) {
    console.error("manual weekly processing failed", error);
    return Response.json(
      { error: "Não foi possível processar a semana." },
      { status: 500 },
    );
  }
}
