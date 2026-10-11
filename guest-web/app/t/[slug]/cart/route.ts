// Old links (/t/<slug>/cart, forwarded from the Flutter guest page) land on the live tab.
export async function GET(request: Request, { params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const url = new URL(request.url);
  const lang = url.searchParams.get("lang");
  const target = new URL(`/t/${encodeURIComponent(slug)}/tab`, url);
  if (lang === "en" || lang === "ar") target.searchParams.set("lang", lang);
  return Response.redirect(target, 308);
}
