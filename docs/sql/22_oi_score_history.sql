-- OI Score monthly history (trend + "compared to last month")
-- Depends on: public.oi_profiles (table), public.is_admin() helper.

create table if not exists public.oi_score_history (
  user_id uuid not null references auth.users(id) on delete cascade,
  month date not null,
  oi_score integer not null default 0,
  technical integer not null default 0,
  social integer not null default 0,
  field_fit integer not null default 0,
  consistency integer not null default 0,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now()),
  primary key (user_id, month)
);

alter table public.oi_score_history enable row level security;

drop policy if exists oi_score_history_select_own on public.oi_score_history;
create policy oi_score_history_select_own
on public.oi_score_history
for select
to authenticated
using (user_id = auth.uid() or is_admin());

drop policy if exists oi_score_history_admin_write on public.oi_score_history;
create policy oi_score_history_admin_write
on public.oi_score_history
for all
to authenticated
using (is_admin())
with check (is_admin());

create or replace function public._sync_oi_history_from_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  m date := date_trunc('month', timezone('utc'::text, now()))::date;
  score integer := round(((new.technical + new.social + new.field_fit + new.consistency) / 4.0))::int;
begin
  insert into public.oi_score_history (
    user_id, month, oi_score, technical, social, field_fit, consistency
  )
  values (
    new.user_id, m, score, new.technical, new.social, new.field_fit, new.consistency
  )
  on conflict (user_id, month) do update
  set
    oi_score = excluded.oi_score,
    technical = excluded.technical,
    social = excluded.social,
    field_fit = excluded.field_fit,
    consistency = excluded.consistency,
    updated_at = timezone('utc'::text, now());

  return new;
end;
$$;

drop trigger if exists trg_oi_profiles_history on public.oi_profiles;
create trigger trg_oi_profiles_history
after insert or update on public.oi_profiles
for each row
execute function public._sync_oi_history_from_profile();

-- Backfill (current month only) for existing profiles
insert into public.oi_score_history (user_id, month, oi_score, technical, social, field_fit, consistency)
select
  user_id,
  date_trunc('month', timezone('utc'::text, now()))::date as month,
  round(((technical + social + field_fit + consistency) / 4.0))::int as oi_score,
  technical,
  social,
  field_fit,
  consistency
from public.oi_profiles
on conflict (user_id, month) do nothing;

create or replace function public.get_my_oi_history(limit_count integer default 6)
returns table (
  month date,
  oi_score integer,
  technical integer,
  social integer,
  field_fit integer,
  consistency integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    h.month,
    h.oi_score,
    h.technical,
    h.social,
    h.field_fit,
    h.consistency
  from public.oi_score_history h
  where h.user_id = auth.uid()
  order by h.month desc
  limit greatest(limit_count, 1);
$$;

grant execute on function public.get_my_oi_history(integer) to authenticated;

