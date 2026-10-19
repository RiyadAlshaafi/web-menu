// Run: node --experimental-strip-types --test archive-worker/src/index_test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { gzipSync, gunzipSync } from "node:zlib";
import { handle, type Env } from "./index.ts";

const cafeA = "11111111-1111-1111-1111-111111111111";
const cafeB = "22222222-2222-2222-2222-222222222222";
const adminA = "Bearer aaa.bbb.ccc";
const keyA = `archive/${cafeA}/2026-06/20261001T014100Z.json.gz`;
const late = `archive/${cafeA}/2026-06/20261102T014100Z.json.gz`;
const keyB = `archive/${cafeB}/2026-06/20261001T014100Z.json.gz`;
const files = new Map([
  [keyA, gzipSync(JSON.stringify({ year_month: "2026-06", payments: [{ total_due: 10 }] }))],
  [late, gzipSync(JSON.stringify({ year_month: "2026-06", payments: [{ total_due: 3 }] }))],
  [keyB, gzipSync(JSON.stringify({ year_month: "2026-06", payments: [{ total_due: 99 }] }))],
]);

const env: Env = {
  SUPABASE_URL: "https://db.example.co/rest/v1",
  SUPABASE_PUBLISHABLE_KEY: "sb_publishable_test",
  ARCHIVE: {
    async get(key) {
      const bytes = files.get(key);
      return bytes ? { body: new Blob([bytes]).stream() } : null;
    },
  },
};

const seen: { url: string; headers: Headers }[] = [];

/** Stands in for Supabase: row-level security gives admin A only cafe A's rows. */
async function supabase(url: string, init?: RequestInit): Promise<Response> {
  const headers = new Headers(init?.headers);
  seen.push({ url, headers });
  const auth = headers.get("Authorization");
  if (auth === "Bearer expired.token.here") return new Response("{}", { status: 401 });
  if (auth === "Bearer broken.server.now") return new Response("{}", { status: 500 });
  const rows = auth === adminA
    ? [{ restaurant_id: cafeA, object_key: keyA }, { restaurant_id: cafeA, object_key: late }]
    : [];
  return Response.json(rows);
}

const get = (path: string, auth?: string, method = "GET") =>
  handle(new Request(`https://staff.tawla.ly${path}`, { method, headers: auth ? { Authorization: auth } : {} }), env, supabase);

const unzip = async (response: Response) => JSON.parse(gunzipSync(Buffer.from(await response.arrayBuffer())).toString());

test("the cafe admin gets each part of an archived month", async () => {
  const first = await get("/api/archive/2026-06/0", adminA);
  assert.equal(first.status, 200);
  assert.equal(first.headers.get("Content-Encoding"), "gzip");
  assert.equal(first.headers.get("X-Archive-Parts"), "2");
  assert.equal((await unzip(first)).payments[0].total_due, 10);
  assert.equal((await unzip(await get("/api/archive/2026-06/1", adminA))).payments[0].total_due, 3);
});

test("only the admin's token goes to Supabase, never a cashier token", async () => {
  seen.length = 0;
  await handle(new Request("https://staff.tawla.ly/api/archive/2026-06/0", {
    headers: { Authorization: adminA, "x-cashier-token": "till" },
  }), env, supabase);
  assert.equal(seen.length, 1);
  assert.equal(seen[0].headers.get("x-cashier-token"), null);
  assert.equal(seen[0].headers.get("apikey"), "sb_publishable_test");
  assert.ok(seen[0].url.startsWith("https://db.example.co/rest/v1/archived_months?"), seen[0].url);
  assert.ok(seen[0].url.includes("year_month=eq.2026-06"));
});

test("no sign-in, a cashier or another cafe gets nothing", async () => {
  assert.equal((await get("/api/archive/2026-06/0")).status, 401);
  assert.equal((await get("/api/archive/2026-06/0", "Bearer sb_publishable_test")).status, 401);
  assert.equal((await get("/api/archive/2026-06/0", "Bearer other.admin.token")).status, 404);
  assert.equal((await get("/api/archive/2026-06/0", "Bearer expired.token.here")).status, 401);
});

test("bad paths, methods and missing parts are refused", async () => {
  assert.equal((await get("/api/archive/2026-13/0", adminA)).status, 404);
  assert.equal((await get("/api/archive/2026-06/x", adminA)).status, 404);
  assert.equal((await get("/api/archive/2026-06/2", adminA)).status, 404);
  assert.equal((await get("/api/archive/2026-06/0", adminA, "DELETE")).status, 405);
  assert.equal((await get("/api/archive/2026-06/0", "Bearer broken.server.now")).status, 502);
});

test("a file outside the cafe's own folder is never served", async () => {
  const sneaky = async () => Response.json([{ restaurant_id: cafeA, object_key: keyB }]);
  const response = await handle(new Request("https://staff.tawla.ly/api/archive/2026-06/0", {
    headers: { Authorization: adminA },
  }), env, sneaky);
  assert.equal(response.status, 404);
});
