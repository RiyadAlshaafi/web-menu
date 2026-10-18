-- Undoes 20261018120000_void_payment.sql: removes the void RPC and the payment void columns.
-- Voided sales become ordinary paid sales again (the shift totals they lowered stay lowered).

drop function if exists public.void_payment(uuid, text);

alter table public.payments
  drop column if exists void_reason,
  drop column if exists voided_by,
  drop column if exists voided_at;
