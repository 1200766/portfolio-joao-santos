declare namespace Cloudflare {
  interface Env {
    DB: D1Database;
    ADMIN_USERNAME?: string;
    ADMIN_PASSWORD?: string;
    ADMIN_SESSION_SECRET?: string;
    SEXTA50_TEST_MODE?: string;
    SEXTA50_TEST_RESULT?: string;
  }
}
