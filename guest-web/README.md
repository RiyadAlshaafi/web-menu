# Tawla guest web app

The guest side of Tawla (QR menu, ordering, live tab, bill) as a Next.js app. Admin and cashier
stay in the Flutter app; both use the same Supabase project.

- Plan and decisions: `../docs/archive/guest-migration/02_PLAN.md`
- The browser only talks to `/api/guest/*`. Those handlers call Supabase with the public anon key,
  one security definer function each (`supabase/migrations/20261014100000_guest_web_rpcs.sql`).
- Live updates: read-only Realtime broadcast pings, loaded after first paint.

## Environment

| Variable | Where | What |
| --- | --- | --- |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | server | API calls (anon or publishable key only; anything else is refused) |
| `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | browser | Realtime pings only |
| `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN` | server | Rate limits (falls back to memory when unset) |

## Commands

```sh
npm ci
npm run typecheck && npm run lint && npm test   # unit and API tests (Vitest)
npm run build && npm start
```

Local backend without a Supabase project (Postgres from `supabase/migrations`, demo cafes,
PostgREST, and a small gateway shim):

```sh
PGHOST=/var/tmp/pg PGPORT=5432 PGUSER=postgres POSTGREST=/path/to/postgrest e2e/local-stack.sh &
node e2e/supabase-shim.mjs &
echo "SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=sb_publishable_local_only" > .env.local
npm run build && npm start   # then open http://localhost:3000/t/demotable0001
```
