// Serves a cafe's archived sales months from the private R2 bucket (written by
// tool/archive_months.sh). GET /api/archive/<YYYY-MM>/<part> with the admin's Supabase sign-in
// (Authorization: Bearer <access token>) returns that file as gzipped JSON.
//
// The Worker holds no database key: it asks Supabase for the month's files with the admin's own
// token, so row-level security on public.archived_months decides which cafe's files exist for
// them. Cashier tokens are never passed on, so only signed-in admins see archives.

export interface ArchiveObject {
  body: ReadableStream | null;
}

export interface ArchiveBucket {
  get(key: string): Promise<ArchiveObject | null>;
}

export interface Env {
  ARCHIVE: ArchiveBucket;
  SUPABASE_URL: string;
  SUPABASE_PUBLISHABLE_KEY: string;
}

type Fetcher = (input: string, init?: RequestInit) => Promise<Response>;

interface ArchiveRow {
  restaurant_id: string;
  object_key: string;
}

const ROUTE = /^\/api\/archive\/(\d{4}-(?:0[1-9]|1[0-2]))\/(\d{1,3})$/;
const USER_TOKEN = /^Bearer [\w-]+\.[\w-]+\.[\w-]+$/;

function problem(status: number, error: string): Response {
  return new Response(JSON.stringify({ error }), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

// The default calls fetch directly: a detached fetch can throw "Illegal invocation" on Workers.
export async function handle(
  request: Request,
  env: Env,
  fetcher: Fetcher = (input, init) => fetch(input, init),
): Promise<Response> {
  const route = ROUTE.exec(new URL(request.url).pathname);
  if (!route) return problem(404, "not found");
  if (request.method !== "GET") return problem(405, "use GET");
  const auth = request.headers.get("Authorization") ?? "";
  if (!USER_TOKEN.test(auth)) return problem(401, "sign in as the cafe admin");
  const [, month, part] = route;

  const origin = new URL(env.SUPABASE_URL).origin;
  const query = `${origin}/rest/v1/archived_months?select=restaurant_id,object_key` +
    `&year_month=eq.${month}&order=archived_at.asc,object_key.asc`;
  const listed = await fetcher(query, {
    headers: { apikey: env.SUPABASE_PUBLISHABLE_KEY, Authorization: auth, Accept: "application/json" },
  });
  if (listed.status === 401 || listed.status === 403) return problem(401, "sign in as the cafe admin");
  if (!listed.ok) return problem(502, "the archive list could not be read");
  const rows = (await listed.json()) as ArchiveRow[];
  const row = Array.isArray(rows) ? rows[Number(part)] : undefined;
  // Files always sit in their own cafe's folder; anything else is never served.
  if (!row || !row.object_key.startsWith(`archive/${row.restaurant_id}/${month}/`)) return problem(404, "not archived");

  const object = await env.ARCHIVE.get(row.object_key);
  if (!object?.body) return problem(404, "not archived");
  return new Response(object.body, {
    headers: {
      "Content-Type": "application/json",
      "Content-Encoding": "gzip",
      "Cache-Control": "private, max-age=86400",
      "X-Archive-Parts": String(rows.length),
    },
    // The file is already gzipped; the runtime must send it as it is.
    encodeBody: "manual",
  } as ResponseInit);
}

export default {
  fetch: (request: Request, env: Env) => handle(request, env),
};
