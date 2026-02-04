-- Excuse / term-freeze requests
-- Spec: student can request a freeze (illness/funeral/etc.), company sees notifications and can approve/reject.
-- Depends on: companies, company_users, internships, internship_applications, helper fns (is_company_staff, is_admin).

create table if not exists public.excuse_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  internship_application_id uuid not null references public.internship_applications(id) on delete cascade,
  reason_type text not null check (reason_type in ('illness','family_emergency','other')),
  details text,
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  reviewer_user_id uuid references auth.users(id) on delete set null,
  reviewer_note text,
  reviewed_at timestamp with time zone,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now())
);

create index if not exists excuse_requests_company_status_idx
on public.excuse_requests (company_id, status);

create index if not exists excuse_requests_user_status_idx
on public.excuse_requests (user_id, status);

alter table public.excuse_requests enable row level security;

drop policy if exists excuse_requests_select_scope on public.excuse_requests;
create policy excuse_requests_select_scope
on public.excuse_requests
for select
to authenticated
using (
  user_id = auth.uid()
  or is_company_staff(company_id)
  or is_admin()
);

drop policy if exists excuse_requests_insert_own on public.excuse_requests;
create policy excuse_requests_insert_own
on public.excuse_requests
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists excuse_requests_update_company on public.excuse_requests;
create policy excuse_requests_update_company
on public.excuse_requests
for update
to authenticated
using (is_company_staff(company_id) or is_admin())
with check (is_company_staff(company_id) or is_admin());

drop policy if exists excuse_requests_delete_admin on public.excuse_requests;
create policy excuse_requests_delete_admin
on public.excuse_requests
for delete
to authenticated
using (is_admin());

create or replace function public.create_excuse_request(
  p_internship_application_id uuid,
  p_reason_type text,
  p_details text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  app_row record;
  company_uuid uuid;
  new_id uuid;
  reason text := lower(coalesce(trim(p_reason_type), ''));
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if reason not in ('illness','family_emergency','other') then
    raise exception 'Invalid reason_type';
  end if;

  select ia.id, ia.user_id, ia.status, i.company_id
  into app_row
  from public.internship_applications ia
  join public.internships i on i.id = ia.internship_id
  where ia.id = p_internship_application_id;

  if app_row.id is null then
    raise exception 'Internship application not found';
  end if;

  if app_row.user_id <> auth.uid() then
    raise exception 'Access denied';
  end if;

  if app_row.status <> 'accepted' then
    raise exception 'Excuse requests require an accepted internship';
  end if;

  company_uuid := app_row.company_id;
  if company_uuid is null then
    raise exception 'Internship has no company_id';
  end if;

  insert into public.excuse_requests (
    user_id, company_id, internship_application_id, reason_type, details, status
  )
  values (
    auth.uid(), company_uuid, p_internship_application_id, reason, nullif(trim(p_details), ''), 'pending'
  )
  returning id into new_id;

  return new_id;
end;
$$;

grant execute on function public.create_excuse_request(uuid, text, text) to authenticated;

create or replace function public.review_excuse_request(
  p_request_id uuid,
  p_new_status text,
  p_reviewer_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  ns text := lower(coalesce(trim(p_new_status), ''));
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if ns not in ('approved','rejected') then
    raise exception 'Invalid status';
  end if;

  select id, company_id, status into r
  from public.excuse_requests
  where id = p_request_id;

  if r.id is null then
    raise exception 'Request not found';
  end if;

  if not (is_company_staff(r.company_id) or is_admin()) then
    raise exception 'Access denied';
  end if;

  if r.status <> 'pending' then
    raise exception 'Only pending requests can be reviewed';
  end if;

  update public.excuse_requests
  set
    status = ns,
    reviewer_user_id = auth.uid(),
    reviewer_note = nullif(trim(p_reviewer_note), ''),
    reviewed_at = timezone('utc'::text, now()),
    updated_at = timezone('utc'::text, now())
  where id = p_request_id;
end;
$$;

grant execute on function public.review_excuse_request(uuid, text, text) to authenticated;

create or replace function public.list_company_excuse_requests(
  p_company_id uuid,
  p_status text default null,
  p_limit integer default 100
)
returns table (
  id uuid,
  user_id uuid,
  internship_application_id uuid,
  reason_type text,
  details text,
  status text,
  reviewer_user_id uuid,
  reviewer_note text,
  reviewed_at timestamp with time zone,
  created_at timestamp with time zone,
  student_name text,
  student_email text,
  internship_title text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    r.id,
    r.user_id,
    r.internship_application_id,
    r.reason_type,
    r.details,
    r.status,
    r.reviewer_user_id,
    r.reviewer_note,
    r.reviewed_at,
    r.created_at,
    coalesce(p.full_name, '') as student_name,
    coalesce(p.email, '') as student_email,
    coalesce(i.title, '') as internship_title
  from public.excuse_requests r
  join public.internship_applications ia on ia.id = r.internship_application_id
  join public.internships i on i.id = ia.internship_id
  left join public.profiles p on p.id = r.user_id
  where
    r.company_id = p_company_id
    and (p_status is null or lower(r.status) = lower(p_status))
    and (is_company_staff(p_company_id) or is_admin())
  order by r.created_at desc
  limit greatest(p_limit, 1);
$$;

grant execute on function public.list_company_excuse_requests(uuid, text, integer) to authenticated;
