-- RLS policies for profiles and user notification tables

alter table public.profiles enable row level security;

drop policy if exists profiles_select_authenticated on public.profiles;
create policy profiles_select_authenticated
on public.profiles
for select
to authenticated
using (true);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own
on public.profiles
for insert
to authenticated
with check (id = auth.uid());

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own
on public.profiles
for update
to authenticated
using (id = auth.uid() or is_admin())
with check (id = auth.uid() or is_admin());

drop policy if exists profiles_delete_own on public.profiles;
create policy profiles_delete_own
on public.profiles
for delete
to authenticated
using (id = auth.uid() or is_admin());

alter table public.notification_preferences enable row level security;

drop policy if exists notification_prefs_select_own on public.notification_preferences;
create policy notification_prefs_select_own
on public.notification_preferences
for select
to authenticated
using (user_id = auth.uid() or is_admin());

drop policy if exists notification_prefs_insert_own on public.notification_preferences;
create policy notification_prefs_insert_own
on public.notification_preferences
for insert
to authenticated
with check (user_id = auth.uid() or is_admin());

drop policy if exists notification_prefs_update_own on public.notification_preferences;
create policy notification_prefs_update_own
on public.notification_preferences
for update
to authenticated
using (user_id = auth.uid() or is_admin())
with check (user_id = auth.uid() or is_admin());

drop policy if exists notification_prefs_delete_own on public.notification_preferences;
create policy notification_prefs_delete_own
on public.notification_preferences
for delete
to authenticated
using (user_id = auth.uid() or is_admin());

alter table public.notifications enable row level security;

drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own
on public.notifications
for select
to authenticated
using (user_id = auth.uid() or is_admin());

drop policy if exists notifications_insert_admin on public.notifications;
create policy notifications_insert_admin
on public.notifications
for insert
to authenticated
with check (is_admin());

drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own
on public.notifications
for update
to authenticated
using (user_id = auth.uid() or is_admin())
with check (user_id = auth.uid() or is_admin());

drop policy if exists notifications_delete_own on public.notifications;
create policy notifications_delete_own
on public.notifications
for delete
to authenticated
using (user_id = auth.uid() or is_admin());
