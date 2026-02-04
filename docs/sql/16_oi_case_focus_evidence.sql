-- OI Score + Case Analysis + Focus Check + Evidence Upload (MVP)
--
-- Notes:
-- - Designed to be idempotent (safe-ish to re-run).
-- - Uses SECURITY DEFINER RPCs to keep critical updates transactional.
-- - Assumes docs/sql/00_helpers.sql has already been applied (is_admin/is_company_member/is_company_staff).

-- Extensions (Supabase usually has these enabled, but keep it safe for new projects)
create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";

-- --------------------------
-- 1) OI profile (dimensions)
-- --------------------------
create table if not exists public.oi_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  technical integer not null default 50 check (technical between 0 and 100),
  social integer not null default 50 check (social between 0 and 100),
  field_fit integer not null default 50 check (field_fit between 0 and 100),
  consistency integer not null default 50 check (consistency between 0 and 100),
  updated_at timestamp with time zone not null default timezone('utc'::text, now())
);

alter table public.oi_profiles enable row level security;

drop policy if exists oi_profiles_select_own on public.oi_profiles;
create policy oi_profiles_select_own
on public.oi_profiles
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists oi_profiles_insert_own on public.oi_profiles;
create policy oi_profiles_insert_own
on public.oi_profiles
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists oi_profiles_update_own on public.oi_profiles;
create policy oi_profiles_update_own
on public.oi_profiles
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create or replace view public.oi_scores as
select
  user_id,
  round(((technical + social + field_fit + consistency) / 4.0))::int as oi_score,
  technical,
  social,
  field_fit,
  consistency,
  updated_at
from public.oi_profiles;

grant select on public.oi_scores to authenticated;

-- --------------------------
-- 2) Case analysis scenarios
-- --------------------------
create table if not exists public.case_scenarios (
  id uuid primary key default gen_random_uuid(),
  prompt text not null,
  left_text text not null,
  right_text text not null,
  left_effect jsonb not null default '{}'::jsonb,
  right_effect jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

alter table public.case_scenarios enable row level security;

drop policy if exists case_scenarios_select_active on public.case_scenarios;
create policy case_scenarios_select_active
on public.case_scenarios
for select
to authenticated
using (is_active = true);

drop policy if exists case_scenarios_admin_write on public.case_scenarios;
create policy case_scenarios_admin_write
on public.case_scenarios
for all
to authenticated
using (is_admin())
with check (is_admin());

create table if not exists public.case_responses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  scenario_id uuid not null references public.case_scenarios(id) on delete cascade,
  choice text not null check (choice in ('left','right')),
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  unique (user_id, scenario_id)
);

alter table public.case_responses enable row level security;

drop policy if exists case_responses_select_own on public.case_responses;
create policy case_responses_select_own
on public.case_responses
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists case_responses_insert_own on public.case_responses;
create policy case_responses_insert_own
on public.case_responses
for insert
to authenticated
with check (user_id = auth.uid());

-- --------------------------
-- 3) Focus check (MVP timer)
-- --------------------------
create table if not exists public.focus_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  internship_application_id uuid not null references public.internship_applications(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  question text not null,
  status text not null default 'started' check (status in ('sent','started','submitted','expired')),
  sent_at timestamp with time zone,
  started_at timestamp with time zone,
  expires_at timestamp with time zone not null,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

alter table public.focus_checks enable row level security;

drop policy if exists focus_checks_select_scope on public.focus_checks;
create policy focus_checks_select_scope
on public.focus_checks
for select
to authenticated
using (
  user_id = auth.uid()
  or is_company_member(company_id)
  or is_admin()
);

create table if not exists public.focus_responses (
  id uuid primary key default gen_random_uuid(),
  focus_check_id uuid not null references public.focus_checks(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  answer text not null,
  submitted_at timestamp with time zone not null default timezone('utc'::text, now())
);

alter table public.focus_responses enable row level security;

drop policy if exists focus_responses_select_scope on public.focus_responses;
create policy focus_responses_select_scope
on public.focus_responses
for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.focus_checks fc
    where fc.id = focus_check_id
      and is_company_member(fc.company_id)
  )
  or is_admin()
);

-- --------------------------
-- 4) Evidence upload + review
-- --------------------------
create table if not exists public.evidence_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  internship_application_id uuid not null references public.internship_applications(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  title text,
  description text,
  file_path text not null,
  mime_type text,
  size_bytes bigint,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now())
);

alter table public.evidence_items enable row level security;

drop policy if exists evidence_items_select_scope on public.evidence_items;
create policy evidence_items_select_scope
on public.evidence_items
for select
to authenticated
using (
  user_id = auth.uid()
  or is_company_member(company_id)
  or is_admin()
);

create table if not exists public.evidence_reviews (
  id uuid primary key default gen_random_uuid(),
  evidence_id uuid not null references public.evidence_items(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  reviewer_user_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('approved','rejected')),
  reason text,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

alter table public.evidence_reviews enable row level security;

drop policy if exists evidence_reviews_select_scope on public.evidence_reviews;
create policy evidence_reviews_select_scope
on public.evidence_reviews
for select
to authenticated
using (
  exists (
    select 1
    from public.evidence_items ei
    where ei.id = evidence_id
      and (
        ei.user_id = auth.uid()
        or is_company_member(ei.company_id)
        or is_admin()
      )
  )
);

-- --------------------------
-- 5) RPCs (transactional MVP)
-- --------------------------
create or replace function public._json_int(p jsonb, k text)
returns integer
language sql
immutable
as $$
  select coalesce(nullif(trim(p->>k), '')::int, 0);
$$;

-- Ensure OI profile exists for current user
create or replace function public.ensure_my_oi_profile()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  insert into public.oi_profiles(user_id)
  values (auth.uid())
  on conflict (user_id) do nothing;
end;
$$;

grant execute on function public.ensure_my_oi_profile() to authenticated;

-- Apply case swipe choice + update OI dimensions
create or replace function public.submit_case_response(
  p_scenario_id uuid,
  p_choice text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  eff jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if p_choice not in ('left','right') then
    raise exception 'invalid choice';
  end if;

  select
    case when p_choice = 'left' then cs.left_effect else cs.right_effect end
  into eff
  from public.case_scenarios cs
  where cs.id = p_scenario_id
    and cs.is_active = true;

  if eff is null then
    raise exception 'scenario not found';
  end if;

  perform public.ensure_my_oi_profile();

  insert into public.case_responses(user_id, scenario_id, choice)
  values (auth.uid(), p_scenario_id, p_choice)
  on conflict (user_id, scenario_id)
  do update set choice = excluded.choice, created_at = timezone('utc'::text, now());

  update public.oi_profiles
  set
    technical = least(100, greatest(0, technical + public._json_int(eff, 'technical'))),
    social = least(100, greatest(0, social + public._json_int(eff, 'social'))),
    field_fit = least(100, greatest(0, field_fit + public._json_int(eff, 'field_fit'))),
    consistency = least(100, greatest(0, consistency + public._json_int(eff, 'consistency'))),
    updated_at = timezone('utc'::text, now())
  where user_id = auth.uid();
end;
$$;

grant execute on function public.submit_case_response(uuid, text) to authenticated;

-- Create (start) a focus check for the current student against an accepted internship application.
create or replace function public.start_focus_check(
  p_internship_application_id uuid
)
returns table (
  focus_check_id uuid,
  question text,
  expires_at timestamp with time zone
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company_id uuid;
  v_question text;
  v_expires timestamp with time zone;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select i.company_id
  into v_company_id
  from public.internship_applications ia
  join public.internships i on i.id = ia.internship_id
  where ia.id = p_internship_application_id
    and ia.user_id = auth.uid()
    and ia.status = 'accepted';

  if v_company_id is null then
    raise exception 'invalid internship application';
  end if;

  v_question := 'How did you solve the error you mentioned in last Tuesday''s report?';
  v_expires := timezone('utc'::text, now()) + interval '30 seconds';

  insert into public.focus_checks(
    user_id,
    internship_application_id,
    company_id,
    question,
    status,
    started_at,
    expires_at
  )
  values (
    auth.uid(),
    p_internship_application_id,
    v_company_id,
    v_question,
    'started',
    timezone('utc'::text, now()),
    v_expires
  )
  returning id, question, expires_at
  into focus_check_id, question, expires_at;

  perform public.ensure_my_oi_profile();
end;
$$;

grant execute on function public.start_focus_check(uuid) to authenticated;

-- Submit focus answer (enforces time window and updates OI consistency)
create or replace function public.submit_focus_answer(
  p_focus_check_id uuid,
  p_answer text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_check public.focus_checks%rowtype;
  v_now timestamp with time zone;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  v_now := timezone('utc'::text, now());

  select *
  into v_check
  from public.focus_checks
  where id = p_focus_check_id;

  if v_check.id is null then
    raise exception 'focus check not found';
  end if;

  if v_check.user_id <> auth.uid() then
    raise exception 'not allowed';
  end if;

  if v_now > v_check.expires_at then
    update public.focus_checks
    set status = 'expired'
    where id = v_check.id;
    raise exception 'expired';
  end if;

  insert into public.focus_responses(focus_check_id, user_id, answer)
  values (v_check.id, auth.uid(), coalesce(p_answer, ''));

  update public.focus_checks
  set status = 'submitted'
  where id = v_check.id;

  perform public.ensure_my_oi_profile();

  update public.oi_profiles
  set
    consistency = least(100, greatest(0, consistency + 2)),
    updated_at = timezone('utc'::text, now())
  where user_id = auth.uid();
end;
$$;

grant execute on function public.submit_focus_answer(uuid, text) to authenticated;

-- Create an evidence item bound to an accepted internship application.
create or replace function public.create_evidence_item(
  p_internship_application_id uuid,
  p_title text,
  p_description text,
  p_file_path text,
  p_mime_type text,
  p_size_bytes bigint
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company_id uuid;
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select i.company_id
  into v_company_id
  from public.internship_applications ia
  join public.internships i on i.id = ia.internship_id
  where ia.id = p_internship_application_id
    and ia.user_id = auth.uid()
    and ia.status = 'accepted';

  if v_company_id is null then
    raise exception 'invalid internship application';
  end if;

  insert into public.evidence_items(
    user_id,
    internship_application_id,
    company_id,
    title,
    description,
    file_path,
    mime_type,
    size_bytes,
    status
  )
  values (
    auth.uid(),
    p_internship_application_id,
    v_company_id,
    nullif(trim(p_title), ''),
    nullif(trim(p_description), ''),
    p_file_path,
    nullif(trim(p_mime_type), ''),
    p_size_bytes,
    'pending'
  )
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.create_evidence_item(uuid, text, text, text, text, bigint) to authenticated;

-- Company-only review (approve/reject) + updates OI dimensions on approval
create or replace function public.review_evidence(
  p_evidence_id uuid,
  p_status text,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.evidence_items%rowtype;
  v_status text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  v_status := lower(trim(coalesce(p_status, '')));
  if v_status not in ('approved','rejected') then
    raise exception 'invalid status';
  end if;

  select *
  into v_item
  from public.evidence_items
  where id = p_evidence_id;

  if v_item.id is null then
    raise exception 'evidence not found';
  end if;

  if not public.is_company_staff(v_item.company_id) then
    raise exception 'not allowed';
  end if;

  update public.evidence_items
  set
    status = v_status,
    updated_at = timezone('utc'::text, now())
  where id = v_item.id;

  insert into public.evidence_reviews(
    evidence_id,
    company_id,
    reviewer_user_id,
    status,
    reason
  )
  values (
    v_item.id,
    v_item.company_id,
    auth.uid(),
    v_status,
    nullif(trim(p_reason), '')
  );

  if v_status = 'approved' then
    insert into public.oi_profiles(user_id) values (v_item.user_id)
    on conflict (user_id) do nothing;

    update public.oi_profiles
    set
      technical = least(100, greatest(0, technical + 5)),
      consistency = least(100, greatest(0, consistency + 2)),
      updated_at = timezone('utc'::text, now())
    where user_id = v_item.user_id;
  end if;
end;
$$;

grant execute on function public.review_evidence(uuid, text, text) to authenticated;

-- --------------------------
-- 6) Minimal seed scenarios
-- --------------------------
insert into public.case_scenarios (prompt, left_text, right_text, left_effect, right_effect, is_active)
select
  'Your manager shouted at you unfairly. What do you do?',
  'I remain silent.',
  'I object in appropriate language.',
  '{"consistency": 1, "social": -1}'::jsonb,
  '{"social": 2, "consistency": 1}'::jsonb,
  true
where not exists (select 1 from public.case_scenarios where prompt ilike 'Your manager shouted%');

insert into public.case_scenarios (prompt, left_text, right_text, left_effect, right_effect, is_active)
select
  'Your teammate couldn''t finish the work. What do you do?',
  'I finish it alone to meet the deadline.',
  'I communicate and split the work to support them.',
  '{"technical": 1, "consistency": 1}'::jsonb,
  '{"social": 2, "field_fit": 1}'::jsonb,
  true
where not exists (select 1 from public.case_scenarios where prompt ilike 'Your teammate couldn%');
