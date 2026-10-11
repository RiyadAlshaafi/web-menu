import { NextResponse, type NextRequest } from "next/server";

// Passes the chosen language (?lang=en|ar) to the root layout, so the first HTML already has
// the right lang and dir attributes for screen readers and right-to-left layout.
export function proxy(request: NextRequest) {
  const lang = request.nextUrl.searchParams.get("lang");
  const headers = new Headers(request.headers);
  headers.delete("x-guest-lang");
  if (lang === "en" || lang === "ar") headers.set("x-guest-lang", lang);
  return NextResponse.next({ request: { headers } });
}

export const config = { matcher: ["/t/:path*"] };
