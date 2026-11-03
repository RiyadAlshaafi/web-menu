-- New cafes start in Arabic; the owner can still switch to English in settings.
alter table public.restaurants alter column locale set default 'ar';
