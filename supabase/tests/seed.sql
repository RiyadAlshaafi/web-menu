-- Test data for tool/test_db.sh: an owner admin for cafe slot 1 (created the
-- way the app does it, through a setup code) and a developer password.

insert into public.restaurant_setup (restaurant_id, code_hash)
values ((select id from public.restaurants where slot = 1), extensions.crypt('SETUPCODE1', extensions.gen_salt('bf')));

insert into auth.users (email, raw_user_meta_data)
values ('owner@example.com', '{"slot": 1, "setup_code": "SETUPCODE1"}');

insert into public.dev_access (password_hash)
values (extensions.crypt('devpw', extensions.gen_salt('bf', 10)));
