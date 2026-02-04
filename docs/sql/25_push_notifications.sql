-- Push notifications (FCM)
-- Stores device tokens and provides secure RPC to create "sent" focus checks by company/admin.
-- Depends on: helpers (is_company_staff, is_admin), notifications table, focus_checks table.

create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text not null default 'unknown',
  device_id text,
  is_active boolean not null default true,
  last_seen_at timestamp with time zone not null default timezone('utc'::text, now()),
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now()),
  unique (user_id, token)
);

create index if not exists push_tokens_user_active_idx on public.push_tokens (user_id, is_active);

alter table public.push_tokens enable row level security;

drop policy if exists push_tokens_select_own on public.push_tokens;
create policy push_tokens_select_own
on public.push_tokens
for select
to authenticated
using (user_id = auth.uid() or is_admin());

drop policy if exists push_tokens_insert_own on public.push_tokens;
create policy push_tokens_insert_own
on public.push_tokens
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists push_tokens_update_own on public.push_tokens;
create policy push_tokens_update_own
on public.push_tokens
for update
to authenticated
using (user_id = auth.uid() or is_admin())
with check (user_id = auth.uid() or is_admin());

drop policy if exists push_tokens_delete_own on public.push_tokens;
create policy push_tokens_delete_own
on public.push_tokens
for delete
to authenticated
using (user_id = auth.uid() or is_admin());

create or replace function public.upsert_my_push_token(
  p_token text,
  p_platform text default 'unknown',
  p_device_id text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if coalesce(trim(p_token), '') = '' then
    raise exception 'token required';
  end if;

  insert into public.push_tokens(user_id, token, platform, device_id, is_active, last_seen_at)
  values (auth.uid(), trim(p_token), coalesce(nullif(trim(p_platform), ''), 'unknown'), nullif(trim(p_device_id), ''), true, timezone('utc'::text, now()))
  on conflict (user_id, token) do update
  set
    platform = excluded.platform,
    device_id = excluded.device_id,
    is_active = true,
    last_seen_at = timezone('utc'::text, now()),
    updated_at = timezone('utc'::text, now());
end;
$$;

grant execute on function public.upsert_my_push_token(text, text, text) to authenticated;

create or replace function public.deactivate_my_push_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  update public.push_tokens
  set is_active = false, updated_at = timezone('utc'::text, now())
  where user_id = auth.uid()
    and token = trim(coalesce(p_token, ''));
end;
$$;

grant execute on function public.deactivate_my_push_token(text) to authenticated;

-- Company/admin creates a focus check and marks it "sent" (to be delivered via Push + in-app notification).
create or replace function public.company_create_focus_check(
  p_user_id uuid,
  p_internship_application_id uuid,
  p_question text default null,
  p_expires_in_seconds integer default 30
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company_id uuid;
  v_expires timestamp with time zone;
  v_question text;
  v_focus_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if not (is_admin() or is_company_staff((select i.company_id from public.internship_applications ia join public.internships i on i.id = ia.internship_id where ia.id = p_internship_application_id))) then
    raise exception 'access denied';
  end if;

  select i.company_id
  into v_company_id
  from public.internship_applications ia
  join public.internships i on i.id = ia.internship_id
  where ia.id = p_internship_application_id
    and ia.user_id = p_user_id
    and ia.status = 'accepted';

  if v_company_id is null then
    raise exception 'invalid internship application';
  end if;

  v_question := coalesce(nullif(trim(p_question), ''), 'How did you solve the error you mentioned in last Tuesday''s report?');
  v_expires := timezone('utc'::text, now()) + make_interval(secs => greatest(coalesce(p_expires_in_seconds, 30), 10));

  insert into public.focus_checks(
    user_id,
    internship_application_id,
    company_id,
    question,
    status,
    sent_at,
    expires_at
  )
  values (
    p_user_id,
    p_internship_application_id,
    v_company_id,
    v_question,
    'sent',
    timezone('utc'::text, now()),
    v_expires
  )
  returning id into v_focus_id;

  insert into public.notifications(user_id, title, message, type, is_read)
  values (
    p_user_id,
    'Instant Focus Check',
    'Tap to answer within 30 seconds.',
    'focus_check',
    false
  );

  return v_focus_id;
end;
$$;

grant execute on function public.company_create_focus_check(uuid, uuid, text, integer) to authenticated;

create or replace function public.start_sent_focus_check(p_focus_check_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_check public.focus_checks%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_check
  from public.focus_checks
  where id = p_focus_check_id;

  if v_check.id is null then
    raise exception 'focus check not found';
  end if;

  if v_check.user_id <> auth.uid() then
    raise exception 'not allowed';
  end if;

  if v_check.status = 'sent' then
    update public.focus_checks
    set status = 'started', started_at = timezone('utc'::text, now())
    where id = v_check.id;
  end if;
end;
$$;

grant execute on function public.start_sent_focus_check(uuid) to authenticated;

