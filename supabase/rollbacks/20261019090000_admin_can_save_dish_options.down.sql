-- Undoes 20261019090000_admin_can_save_dish_options.sql (brings back the broken dish save).

revoke execute on function private.valid_dish_options(jsonb) from anon, authenticated;
