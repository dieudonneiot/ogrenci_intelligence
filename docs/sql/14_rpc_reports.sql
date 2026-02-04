-- Report helpers: updated_at columns, triggers, and RPCs

-- Add updated_at to applications if missing
alter table public.job_applications
  add column if not exists updated_at timestamp with time zone default timezone('utc'::text, now());

alter table public.internship_applications
  add column if not exists updated_at timestamp with time zone default timezone('utc'::text, now());

-- Simple updated_at trigger
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists set_job_applications_updated_at on public.job_applications;
create trigger set_job_applications_updated_at
before update on public.job_applications
for each row
execute function public.set_updated_at();

drop trigger if exists set_internship_applications_updated_at on public.internship_applications;
create trigger set_internship_applications_updated_at
before update on public.internship_applications
for each row
execute function public.set_updated_at();

-- Company report summary
create or replace function public.get_company_report_summary(
  p_company_id uuid,
  p_start_date date default null
)
returns table (
  total_views integer,
  unique_visitors integer,
  total_applications integer,
  accepted_applications integer,
  rejected_applications integer,
  avg_response_time_hours numeric,
  conversion_rate numeric,
  active_jobs integer,
  active_internships integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_start timestamp;
begin
  if not (is_company_staff(p_company_id) or is_admin()) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  v_start := case when p_start_date is null then null else p_start_date::timestamp end;

  select count(*)::int
  into active_jobs
  from public.jobs
  where company_id = p_company_id
    and is_active = true;

  select count(*)::int
  into active_internships
  from public.internships
  where company_id = p_company_id
    and is_active = true;

  select count(*)::int
  into total_views
  from (
    select jv.id
    from public.job_views jv
    join public.jobs j on j.id = jv.job_id
    where j.company_id = p_company_id
      and (v_start is null or jv.viewed_at >= v_start)
    union all
    select iv.id
    from public.internship_views iv
    join public.internships i on i.id = iv.internship_id
    where i.company_id = p_company_id
      and (v_start is null or iv.viewed_at >= v_start)
  ) v;

  select count(distinct coalesce(x.user_id::text, x.ip_address::text, x.session_id))::int
  into unique_visitors
  from (
    select jv.user_id, jv.ip_address, jv.session_id
    from public.job_views jv
    join public.jobs j on j.id = jv.job_id
    where j.company_id = p_company_id
      and (v_start is null or jv.viewed_at >= v_start)
    union all
    select iv.user_id, iv.ip_address, iv.session_id
    from public.internship_views iv
    join public.internships i on i.id = iv.internship_id
    where i.company_id = p_company_id
      and (v_start is null or iv.viewed_at >= v_start)
  ) x;

  select count(*)::int
  into total_applications
  from (
    select ja.id
    from public.job_applications ja
    join public.jobs j on j.id = ja.job_id
    where j.company_id = p_company_id
      and (v_start is null or ja.applied_at >= v_start)
    union all
    select ia.id
    from public.internship_applications ia
    join public.internships i on i.id = ia.internship_id
    where i.company_id = p_company_id
      and (v_start is null or ia.applied_at >= v_start)
  ) a;

  select count(*)::int
  into accepted_applications
  from (
    select ja.id
    from public.job_applications ja
    join public.jobs j on j.id = ja.job_id
    where j.company_id = p_company_id
      and ja.status = 'accepted'
      and (v_start is null or ja.applied_at >= v_start)
    union all
    select ia.id
    from public.internship_applications ia
    join public.internships i on i.id = ia.internship_id
    where i.company_id = p_company_id
      and ia.status = 'accepted'
      and (v_start is null or ia.applied_at >= v_start)
  ) a;

  select count(*)::int
  into rejected_applications
  from (
    select ja.id
    from public.job_applications ja
    join public.jobs j on j.id = ja.job_id
    where j.company_id = p_company_id
      and ja.status = 'rejected'
      and (v_start is null or ja.applied_at >= v_start)
    union all
    select ia.id
    from public.internship_applications ia
    join public.internships i on i.id = ia.internship_id
    where i.company_id = p_company_id
      and ia.status = 'rejected'
      and (v_start is null or ia.applied_at >= v_start)
  ) a;

  select coalesce(avg(extract(epoch from (updated_at - applied_at)) / 3600.0), 0)
  into avg_response_time_hours
  from (
    select ja.applied_at, ja.updated_at
    from public.job_applications ja
    join public.jobs j on j.id = ja.job_id
    where j.company_id = p_company_id
      and ja.status <> 'pending'
      and ja.updated_at is not null
      and (v_start is null or ja.applied_at >= v_start)
    union all
    select ia.applied_at, ia.updated_at
    from public.internship_applications ia
    join public.internships i on i.id = ia.internship_id
    where i.company_id = p_company_id
      and ia.status <> 'pending'
      and ia.updated_at is not null
      and (v_start is null or ia.applied_at >= v_start)
  ) r;

  conversion_rate := case
    when total_views = 0 then 0
    else (total_applications::numeric / total_views::numeric) * 100
  end;

  return next;
end;
$$;

grant execute on function public.get_company_report_summary(uuid, date) to authenticated;

-- Daily trends for charts
create or replace function public.get_company_report_trends(
  p_company_id uuid,
  p_days integer default 7,
  p_start_date date default null
)
returns table (
  metric_date date,
  views integer,
  applications integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_start date;
begin
  if not (is_company_staff(p_company_id) or is_admin()) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  v_start := coalesce(p_start_date, current_date - (p_days - 1));

  return query
  select d::date as metric_date,
    (
      select count(*)
      from public.job_views jv
      join public.jobs j on j.id = jv.job_id
      where j.company_id = p_company_id
        and jv.viewed_at::date = d
    ) + (
      select count(*)
      from public.internship_views iv
      join public.internships i on i.id = iv.internship_id
      where i.company_id = p_company_id
        and iv.viewed_at::date = d
    ) as views,
    (
      select count(*)
      from public.job_applications ja
      join public.jobs j on j.id = ja.job_id
      where j.company_id = p_company_id
        and ja.applied_at::date = d
    ) + (
      select count(*)
      from public.internship_applications ia
      join public.internships i on i.id = ia.internship_id
      where i.company_id = p_company_id
        and ia.applied_at::date = d
    ) as applications
  from generate_series(v_start, v_start + (p_days - 1), '1 day') as d;
end;
$$;

grant execute on function public.get_company_report_trends(uuid, integer, date) to authenticated;

-- Department distribution
create or replace function public.get_company_report_departments(
  p_company_id uuid,
  p_start_date date default null
)
returns table (
  department text,
  applications integer
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (is_company_staff(p_company_id) or is_admin()) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  return query
  select department, sum(applications)::int
  from (
    select coalesce(j.department, 'Diğer') as department, count(*) as applications
    from public.job_applications ja
    join public.jobs j on j.id = ja.job_id
    where j.company_id = p_company_id
      and (p_start_date is null or ja.applied_at::date >= p_start_date)
    group by 1
    union all
    select coalesce(i.department, 'Diğer') as department, count(*) as applications
    from public.internship_applications ia
    join public.internships i on i.id = ia.internship_id
    where i.company_id = p_company_id
      and (p_start_date is null or ia.applied_at::date >= p_start_date)
    group by 1
  ) x
  group by department
  order by sum(applications) desc;
end;
$$;

grant execute on function public.get_company_report_departments(uuid, date) to authenticated;

-- Funnel counts
create or replace function public.get_company_report_funnel(
  p_company_id uuid,
  p_start_date date default null
)
returns table (
  views integer,
  applications integer,
  accepted integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_start timestamp;
begin
  if not (is_company_staff(p_company_id) or is_admin()) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  v_start := case when p_start_date is null then null else p_start_date::timestamp end;

  select count(*)::int
  into views
  from (
    select jv.id
    from public.job_views jv
    join public.jobs j on j.id = jv.job_id
    where j.company_id = p_company_id
      and (v_start is null or jv.viewed_at >= v_start)
    union all
    select iv.id
    from public.internship_views iv
    join public.internships i on i.id = iv.internship_id
    where i.company_id = p_company_id
      and (v_start is null or iv.viewed_at >= v_start)
  ) v;

  select count(*)::int
  into applications
  from (
    select ja.id
    from public.job_applications ja
    join public.jobs j on j.id = ja.job_id
    where j.company_id = p_company_id
      and (v_start is null or ja.applied_at >= v_start)
    union all
    select ia.id
    from public.internship_applications ia
    join public.internships i on i.id = ia.internship_id
    where i.company_id = p_company_id
      and (v_start is null or ia.applied_at >= v_start)
  ) a;

  select count(*)::int
  into accepted
  from (
    select ja.id
    from public.job_applications ja
    join public.jobs j on j.id = ja.job_id
    where j.company_id = p_company_id
      and ja.status = 'accepted'
      and (v_start is null or ja.applied_at >= v_start)
    union all
    select ia.id
    from public.internship_applications ia
    join public.internships i on i.id = ia.internship_id
    where i.company_id = p_company_id
      and ia.status = 'accepted'
      and (v_start is null or ia.applied_at >= v_start)
  ) a;

  return next;
end;
$$;

grant execute on function public.get_company_report_funnel(uuid, date) to authenticated;
