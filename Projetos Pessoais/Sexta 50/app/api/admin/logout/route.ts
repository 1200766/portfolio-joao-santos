import { expiredAdminCookie } from "../../../../lib/admin-auth";

export async function POST(request: Request) {
  const secure = new URL(request.url).protocol === "https:";
  return new Response(null, {
    status: 303,
    headers: {
      Location: new URL("/admin/login", request.url).toString(),
      "Set-Cookie": expiredAdminCookie(secure),
      "Cache-Control": "no-store",
    },
  });
}
