// The caller's IP. Cloudflare sets cf-connecting-ip itself and overwrites any value the visitor
// sent; x-forwarded-for is only a fallback (local runs, tests) because its first hop can be forged.
export function ipFromHeaders(headers: Headers): string {
  const cloudflare = headers.get("cf-connecting-ip")?.trim();
  if (cloudflare) return cloudflare;
  const first = headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  return first || headers.get("x-real-ip")?.trim() || "unknown";
}

export function clientIp(request: Request): string {
  return ipFromHeaders(request.headers);
}
