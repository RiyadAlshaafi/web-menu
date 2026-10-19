// Entry point of the admin-reset-ticket Edge Function; the logic and its tests live in handler.ts.
import { handle } from "./handler.ts";

Deno.serve((request) => handle(request));
