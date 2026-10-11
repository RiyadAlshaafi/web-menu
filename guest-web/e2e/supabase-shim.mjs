// Stands in for the Supabase API gateway in local runs: /rest/v1/* goes to PostgREST, as on
// Supabase. Also records which RPCs were called, for the browser tests (GET /__calls).
import http from "node:http";

const target = Number(process.env.POSTGREST_PORT ?? 3001);
const port = Number(process.env.SHIM_PORT ?? 54321);
const calls = [];

http
  .createServer((req, res) => {
    if (req.url === "/__calls") {
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify(calls.splice(0)));
      return;
    }
    if (!req.url?.startsWith("/rest/v1/")) {
      res.writeHead(404).end();
      return;
    }
    const path = req.url.slice("/rest/v1".length);
    calls.push({ path, apikey: req.headers.apikey ?? null, authorization: req.headers.authorization ?? null });
    const headers = { ...req.headers, host: `127.0.0.1:${target}` };
    delete headers.apikey;
    const upstream = http.request({ host: "127.0.0.1", port: target, path, method: req.method, headers }, (up) => {
      res.writeHead(up.statusCode ?? 502, up.headers);
      up.pipe(res);
    });
    upstream.on("error", () => res.writeHead(502).end());
    req.pipe(upstream);
  })
  .listen(port, "127.0.0.1", () => console.log(`supabase shim on :${port} -> postgrest :${target}`));
