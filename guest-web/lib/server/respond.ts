import { ERROR_MESSAGE, ERROR_STATUS, type ErrorCode } from "./errors";

export type ApiError = { code: ErrorCode; message: string; items?: string[] };
export type ApiResponse<T> = { ok: true; data: T; error: null } | { ok: false; data: null; error: ApiError };

const NO_STORE = "no-store";

export function ok<T>(data: T, cacheControl: string = NO_STORE): Response {
  const body: ApiResponse<T> = { ok: true, data, error: null };
  return Response.json(body, { status: 200, headers: { "Cache-Control": cacheControl } });
}

export function fail(code: ErrorCode, extra: { items?: string[]; retryAfter?: number } = {}): Response {
  const error: ApiError = { code, message: ERROR_MESSAGE[code] };
  if (extra.items) error.items = extra.items;
  const headers: Record<string, string> = { "Cache-Control": NO_STORE };
  if (extra.retryAfter !== undefined) headers["Retry-After"] = String(extra.retryAfter);
  const body: ApiResponse<never> = { ok: false, data: null, error };
  return Response.json(body, { status: ERROR_STATUS[code], headers });
}
