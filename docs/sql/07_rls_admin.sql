-- RLS policies for admin tables

alter table public.admins enable row level security;

drop policy if exists admins_select_admin on public.admins;
create policy admins_select_admin
on public.admins
for select
to authenticated
using (is_admin());

drop policy if exists admins_insert_first_or_admin on public.admins;
create policy admins_insert_first_or_admin
on public.admins
for insert
to authenticated
with check (
  user_id = auth.uid()
  and (is_admin() or not exists (select 1 from public.admins))
);

drop policy if exists admins_update_admin on public.admins;
create policy admins_update_admin
on public.admins
for update
to authenticated
using (is_admin())
with check (is_admin());

drop policy if exists admins_delete_admin on public.admins;
create policy admins_delete_admin
on public.admins
for delete
to authenticated
using (is_admin());

alter table public.admin_logs enable row level security;

drop policy if exists admin_logs_select_admin on public.admin_logs;
create policy admin_logs_select_admin
on public.admin_logs
for select
to authenticated
using (is_admin());

drop policy if exists admin_logs_insert_admin on public.admin_logs;
create policy admin_logs_insert_admin
on public.admin_logs
for insert
to authenticated
with check (is_admin());

drop policy if exists admin_logs_update_admin on public.admin_logs;
create policy admin_logs_update_admin
on public.admin_logs
for update
to authenticated
using (is_admin())
with check (is_admin());

drop policy if exists admin_logs_delete_admin on public.admin_logs;
create policy admin_logs_delete_admin
on public.admin_logs
for delete
to authenticated
using (is_admin());

alter table public.admin_setup_logs enable row level security;

drop policy if exists admin_setup_logs_insert_public on public.admin_setup_logs;
create policy admin_setup_logs_insert_public
on public.admin_setup_logs
for insert
to anon, authenticated
with check (true);

drop policy if exists admin_setup_logs_select_admin on public.admin_setup_logs;
create policy admin_setup_logs_select_admin
on public.admin_setup_logs
for select
to authenticated
using (is_admin());
