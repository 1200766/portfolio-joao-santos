import {
  adminCookie,
  createAdminSession,
  verifyAdminCredentials,
} from "../../../../lib/admin-auth";

export async function POST(request: Request) {
  const form = await request.formData();
  const username = String(form.get("username") ?? "");
  const password = String(form.get("password") ?? "");
  const secure = new URL(request.url).protocol === "https:";

  if (!(await verifyAdminCredentials(username, password))) {
    return new Response(null, {
      status: 303,
      headers: {
        Location: new URL("/admin/login?erro=1", request.url).toString(),
        "Cache-Control": "no-store",
      },
    });
  }

  return new Response(null, {
    status: 303,
    headers: {
      Location: new URL("/admin", request.url).toString(),
      "Set-Cookie": adminCookie(await createAdminSession(), secure),
      "Cache-Control": "no-store",
    },
  });
}
