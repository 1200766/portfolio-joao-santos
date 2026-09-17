import { fetchLatestFridayResult } from "../../../../lib/euromillions";

export async function GET() {
  try {
    const result = await fetchLatestFridayResult();
    return Response.json(result, {
      headers: { "Cache-Control": "public, max-age=900, s-maxage=900" },
    });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Resultado indisponível.";
    return Response.json({ error: message }, { status: 502 });
  }
}
