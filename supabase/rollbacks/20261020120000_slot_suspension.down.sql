-- Undoes 20261020120000_slot_suspension.sql: every slot is active again and the vendor switch is
-- removed. The cafe lookups keep their (now always true) suspension check, which is harmless;
-- the suspended_at column stays so the migration applies cleanly again.
update public.restaurants set suspended_at = null where suspended_at is not null;
drop function if exists public.vendor_set_suspended(text, uuid, boolean);
