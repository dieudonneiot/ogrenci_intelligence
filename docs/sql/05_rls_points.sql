-- RLS policies for points, badges, rewards, and leaderboards

alter table public.activity_logs enable row level security;

drop policy if exists activity_logs_select_own on public.activity_logs;
create policy activity_logs_select_own
on public.activity_logs
for select
to authenticated
using (user_id = auth.uid() or is_admin());

drop policy if exists activity_logs_insert_own on public.activity_logs;
create policy activity_logs_insert_own
on public.activity_logs
for insert
to authenticated
with check (user_id = auth.uid() or is_admin());

drop policy if exists activity_logs_update_own on public.activity_logs;
create policy activity_logs_update_own
on public.activity_logs
for update
to authenticated
using (user_id = auth.uid() or is_admin())
with check (user_id = auth.uid() or is_admin());

drop policy if exists activity_logs_delete_own on public.activity_logs;
create policy activity_logs_delete_own
on public.activity_logs
for delete
to authenticated
using (user_id = auth.uid() or is_admin());

alter table public.user_points enable row level security;

drop policy if exists user_points_select_own on public.user_points;
create policy user_points_select_own
on public.user_points
for select
to authenticated
using (user_id = auth.uid() or is_admin());

drop policy if exists user_points_insert_own on public.user_points;
create policy user_points_insert_own
on public.user_points
for insert
to authenticated
with check (user_id = auth.uid() or is_admin());

drop policy if exists user_points_update_admin on public.user_points;
create policy user_points_update_admin
on public.user_points
for update
to authenticated
using (is_admin())
with check (is_admin());

drop policy if exists user_points_delete_own on public.user_points;
create policy user_points_delete_own
on public.user_points
for delete
to authenticated
using (user_id = auth.uid() or is_admin());

alter table public.user_badges enable row level security;

drop policy if exists user_badges_select_own on public.user_badges;
create policy user_badges_select_own
on public.user_badges
for select
to authenticated
using (user_id = auth.uid() or is_admin());

drop policy if exists user_badges_insert_admin on public.user_badges;
create policy user_badges_insert_admin
on public.user_badges
for insert
to authenticated
with check (is_admin());

drop policy if exists user_badges_update_admin on public.user_badges;
create policy user_badges_update_admin
on public.user_badges
for update
to authenticated
using (is_admin())
with check (is_admin());

drop policy if exists user_badges_delete_admin on public.user_badges;
create policy user_badges_delete_admin
on public.user_badges
for delete
to authenticated
using (is_admin());

alter table public.rewards enable row level security;

drop policy if exists rewards_select_authenticated on public.rewards;
create policy rewards_select_authenticated
on public.rewards
for select
to authenticated
using (true);

drop policy if exists rewards_insert_admin on public.rewards;
create policy rewards_insert_admin
on public.rewards
for insert
to authenticated
with check (is_admin());

drop policy if exists rewards_update_admin on public.rewards;
create policy rewards_update_admin
on public.rewards
for update
to authenticated
using (is_admin())
with check (is_admin());

drop policy if exists rewards_delete_admin on public.rewards;
create policy rewards_delete_admin
on public.rewards
for delete
to authenticated
using (is_admin());

alter table public.leaderboard_snapshots enable row level security;

drop policy if exists leaderboard_snapshots_select_authenticated on public.leaderboard_snapshots;
create policy leaderboard_snapshots_select_authenticated
on public.leaderboard_snapshots
for select
to authenticated
using (true);

drop policy if exists leaderboard_snapshots_insert_admin on public.leaderboard_snapshots;
create policy leaderboard_snapshots_insert_admin
on public.leaderboard_snapshots
for insert
to authenticated
with check (is_admin());

drop policy if exists leaderboard_snapshots_update_admin on public.leaderboard_snapshots;
create policy leaderboard_snapshots_update_admin
on public.leaderboard_snapshots
for update
to authenticated
using (is_admin())
with check (is_admin());

drop policy if exists leaderboard_snapshots_delete_admin on public.leaderboard_snapshots;
create policy leaderboard_snapshots_delete_admin
on public.leaderboard_snapshots
for delete
to authenticated
using (is_admin());
