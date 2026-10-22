-- Undoes 20261021100000_table_claims.sql: every phone can order again and the clear-table action is removed.
drop function if exists public.cashier_clear_table(uuid);
drop trigger if exists release_claim_when_free on public.dining_tables;
drop function if exists private.release_claim_when_free();
drop trigger if exists zz_guest_table_claim on public.order_lines;
drop function if exists private.guest_table_claim();
drop function if exists public.guest_claim_table(text, text, double precision, double precision, double precision);
drop function if exists private.set_claim(uuid, uuid, text);
drop function if exists private.claim_holder(uuid);
drop function if exists private.visitor_hash(uuid, text);
drop table if exists public.table_claims;
