import { execFileSync } from "node:child_process";

// Plays the cashier's part in browser tests by changing rows directly in the local database.
export function db(sql: string): string {
  return execFileSync("psql", ["-X", "-q", "-At", "-v", "ON_ERROR_STOP=1", "-d", process.env.E2E_DB ?? "guest_e2e", "-c", sql], {
    encoding: "utf8",
  }).trim();
}

export const SHIM = process.env.E2E_SHIM_URL ?? "http://127.0.0.1:54321";

// Clears orders, calls and carts left by earlier runs, so a run starts at empty tables.
export function resetDemo(): void {
  const cafes = "select id from public.restaurants where name in ('Akakus Café','Offline Café','Square Café')";
  db(`
    set session_replication_role = replica;
    delete from public.order_lines where restaurant_id in (${cafes});
    delete from public.orders where restaurant_id in (${cafes});
    delete from public.staff_calls where restaurant_id in (${cafes});
    delete from public.cart_lines where restaurant_id in (${cafes});
    update public.dining_tables set status = 'free', guests = 0 where restaurant_id in (${cafes});`);
}
