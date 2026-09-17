import { env } from "cloudflare:workers";

const ADMIN_COOKIE = "sexta50_admin";
const SESSION_TTL_SECONDS = 8 * 60 * 60;
const encoder = new TextEncoder();

function bytesToBase64Url(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64UrlToBytes(value: string) {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(value.length / 4) * 4, "=");
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

async function digest(value: string) {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(value)));
}

function constantTimeEqual(left: Uint8Array, right: Uint8Array) {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) {
    difference |= left[index] ^ right[index];
  }
  return difference === 0;
}

function sessionSecret() {
  const value = runtimeValue("ADMIN_SESSION_SECRET");
  if (!value) throw new Error("ADMIN_SESSION_SECRET is not configured.");
  return value;
}

function runtimeValue(key: string) {
  const workerEnv = env as unknown as Record<string, string | undefined>;
  return workerEnv[key] ?? process.env[key];
}

async function signingKey() {
  return crypto.subtle.importKey(
    "raw",
    encoder.encode(sessionSecret()),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

export async function verifyAdminCredentials(username: string, password: string) {
  const expectedUsername = runtimeValue("ADMIN_USERNAME");
  const expectedPassword = runtimeValue("ADMIN_PASSWORD");
  if (!expectedUsername || !expectedPassword) return false;

  const supplied = await digest(`${username.trim().normalize("NFKC")}\0${password}`);
  const expected = await digest(`${expectedUsername.trim().normalize("NFKC")}\0${expectedPassword}`);
  return constantTimeEqual(supplied, expected);
}

export async function createAdminSession() {
  const payload = bytesToBase64Url(
    encoder.encode(
      JSON.stringify({
        subject: "administrator",
        expiresAt: Math.floor(Date.now() / 1000) + SESSION_TTL_SECONDS,
        nonce: crypto.randomUUID(),
      }),
    ),
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("HMAC", await signingKey(), encoder.encode(payload)),
  );
  return `${payload}.${bytesToBase64Url(signature)}`;
}

export async function verifyAdminSession(value?: string | null) {
  if (!value) return false;
  const [payload, signature] = value.split(".");
  if (!payload || !signature) return false;

  try {
    const validSignature = await crypto.subtle.verify(
      "HMAC",
      await signingKey(),
      base64UrlToBytes(signature),
      encoder.encode(payload),
    );
    if (!validSignature) return false;

    const decoded = new TextDecoder().decode(base64UrlToBytes(payload));
    const session = JSON.parse(decoded) as { subject?: string; expiresAt?: number };
    return session.subject === "administrator" &&
      typeof session.expiresAt === "number" &&
      session.expiresAt > Math.floor(Date.now() / 1000);
  } catch {
    return false;
  }
}

export function readAdminCookie(request: Request) {
  const cookieHeader = request.headers.get("cookie") ?? "";
  for (const item of cookieHeader.split(";")) {
    const [name, ...valueParts] = item.trim().split("=");
    if (name === ADMIN_COOKIE) return decodeURIComponent(valueParts.join("="));
  }
  return null;
}

export function adminCookie(value: string, secure: boolean) {
  return [
    `${ADMIN_COOKIE}=${encodeURIComponent(value)}`,
    "Path=/",
    "HttpOnly",
    "SameSite=Strict",
    `Max-Age=${SESSION_TTL_SECONDS}`,
    secure ? "Secure" : "",
  ].filter(Boolean).join("; ");
}

export function expiredAdminCookie(secure: boolean) {
  return [
    `${ADMIN_COOKIE}=`,
    "Path=/",
    "HttpOnly",
    "SameSite=Strict",
    "Max-Age=0",
    secure ? "Secure" : "",
  ].filter(Boolean).join("; ");
}

export { ADMIN_COOKIE };
