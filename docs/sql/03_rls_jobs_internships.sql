-- RLS policies for jobs, internships, applications, and views

alter table public.jobs enable row level security;

drop policy if exists jobs_select_public_active on public.jobs;
create policy jobs_select_public_active
on public.jobs
for select
to anon, authenticated
using (is_active = true and (deadline is null or deadline >= current_date));

drop policy if exists jobs_select_applicant on public.jobs;
-- IMPORTANT:
-- Do NOT add a policy that queries `job_applications` here, because
-- `job_applications` policies also query `jobs`, which can cause
-- "infinite recursion detected in policy" errors (42P17) in PostgREST.

drop policy if exists jobs_select_favorited on public.jobs;
create policy jobs_select_favorited
on public.jobs
for select
to authenticated
using (
  exists (
    select 1
    from public.favorites f
    where f.job_id = id
      and f.user_id = auth.uid()
  )
);

drop policy if exists jobs_select_company on public.jobs;
create policy jobs_select_company
on public.jobs
for select
to authenticated
using (is_company_member(company_id) or is_admin());

drop policy if exists jobs_insert_company_staff on public.jobs;
create policy jobs_insert_company_staff
on public.jobs
for insert
to authenticated
with check ((is_company_staff(company_id) and created_by = auth.uid()) or is_admin());

drop policy if exists jobs_update_company_staff on public.jobs;
create policy jobs_update_company_staff
on public.jobs
for update
to authenticated
using (is_company_staff(company_id) or is_admin())
with check (is_company_staff(company_id) or is_admin());

drop policy if exists jobs_delete_company_staff on public.jobs;
create policy jobs_delete_company_staff
on public.jobs
for delete
to authenticated
using (is_company_staff(company_id) or is_admin());

alter table public.internships enable row level security;

drop policy if exists internships_select_public_active on public.internships;
create policy internships_select_public_active
on public.internships
for select
to anon, authenticated
using (is_active = true and (deadline is null or deadline >= current_date));

drop policy if exists internships_select_applicant on public.internships;
-- IMPORTANT:
-- Do NOT add a policy that queries `internship_applications` here, because
-- `internship_applications` policies also query `internships`, which can cause
-- "infinite recursion detected in policy" errors (42P17) in PostgREST.

drop policy if exists internships_select_favorited on public.internships;
create policy internships_select_favorited
on public.internships
for select
to authenticated
using (
  exists (
    select 1
    from public.favorites f
    where f.internship_id = id
      and f.user_id = auth.uid()
  )
);

drop policy if exists internships_select_company on public.internships;
create policy internships_select_company
on public.internships
for select
to authenticated
using (is_company_member(company_id) or is_admin());

drop policy if exists internships_insert_company_staff on public.internships;
create policy internships_insert_company_staff
on public.internships
for insert
to authenticated
with check ((is_company_staff(company_id) and created_by = auth.uid()) or is_admin());

drop policy if exists internships_update_company_staff on public.internships;
create policy internships_update_company_staff
on public.internships
for update
to authenticated
using (is_company_staff(company_id) or is_admin())
with check (is_company_staff(company_id) or is_admin());

drop policy if exists internships_delete_company_staff on public.internships;
create policy internships_delete_company_staff
on public.internships
for delete
to authenticated
using (is_company_staff(company_id) or is_admin());

alter table public.job_applications enable row level security;

drop policy if exists job_applications_select_scope on public.job_applications;
create policy job_applications_select_scope
on public.job_applications
for select
to authenticated
using (
  user_id = auth.uid()
  or is_admin()
  or exists (
    select 1
    from public.jobs j
    where j.id = job_id
      and is_company_staff(j.company_id)
  )
);

drop policy if exists job_applications_insert_own on public.job_applications;
create policy job_applications_insert_own
on public.job_applications
for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.jobs j
    where j.id = job_id
      and j.is_active = true
      and (j.deadline is null or j.deadline >= current_date)
  )
);

drop policy if exists job_applications_update_company on public.job_applications;
create policy job_applications_update_company
on public.job_applications
for update
to authenticated
using (
  is_admin()
  or exists (
    select 1
    from public.jobs j
    where j.id = job_id
      and is_company_staff(j.company_id)
  )
)
with check (
  is_admin()
  or exists (
    select 1
    from public.jobs j
    where j.id = job_id
      and is_company_staff(j.company_id)
  )
);

drop policy if exists job_applications_delete_scope on public.job_applications;
create policy job_applications_delete_scope
on public.job_applications
for delete
to authenticated
using (
  user_id = auth.uid()
  or is_admin()
  or exists (
    select 1
    from public.jobs j
    where j.id = job_id
      and is_company_staff(j.company_id)
  )
);

alter table public.internship_applications enable row level security;

drop policy if exists internship_applications_select_scope on public.internship_applications;
create policy internship_applications_select_scope
on public.internship_applications
for select
to authenticated
using (
  user_id = auth.uid()
  or is_admin()
  or exists (
    select 1
    from public.internships i
    where i.id = internship_id
      and is_company_staff(i.company_id)
  )
);

drop policy if exists internship_applications_insert_own on public.internship_applications;
create policy internship_applications_insert_own
on public.internship_applications
for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.internships i
    where i.id = internship_id
      and i.is_active = true
      and (i.deadline is null or i.deadline >= current_date)
  )
);

drop policy if exists internship_applications_update_company on public.internship_applications;
create policy internship_applications_update_company
on public.internship_applications
for update
to authenticated
using (
  is_admin()
  or exists (
    select 1
    from public.internships i
    where i.id = internship_id
      and is_company_staff(i.company_id)
  )
)
with check (
  is_admin()
  or exists (
    select 1
    from public.internships i
    where i.id = internship_id
      and is_company_staff(i.company_id)
  )
);

drop policy if exists internship_applications_delete_scope on public.internship_applications;
create policy internship_applications_delete_scope
on public.internship_applications
for delete
to authenticated
using (
  user_id = auth.uid()
  or is_admin()
  or exists (
    select 1
    from public.internships i
    where i.id = internship_id
      and is_company_staff(i.company_id)
  )
);

alter table public.job_views enable row level security;

drop policy if exists job_views_insert_public on public.job_views;
create policy job_views_insert_public
on public.job_views
for insert
to anon, authenticated
with check (user_id is null or user_id = auth.uid());

drop policy if exists job_views_select_company on public.job_views;
create policy job_views_select_company
on public.job_views
for select
to authenticated
using (
  is_admin()
  or exists (
    select 1
    from public.jobs j
    where j.id = job_id
      and is_company_staff(j.company_id)
  )
);

drop policy if exists job_views_delete_admin on public.job_views;
create policy job_views_delete_admin
on public.job_views
for delete
to authenticated
using (is_admin());

alter table public.internship_views enable row level security;

drop policy if exists internship_views_insert_public on public.internship_views;
create policy internship_views_insert_public
on public.internship_views
for insert
to anon, authenticated
with check (user_id is null or user_id = auth.uid());

drop policy if exists internship_views_select_company on public.internship_views;
create policy internship_views_select_company
on public.internship_views
for select
to authenticated
using (
  is_admin()
  or exists (
    select 1
    from public.internships i
    where i.id = internship_id
      and is_company_staff(i.company_id)
  )
);

drop policy if exists internship_views_delete_admin on public.internship_views;
create policy internship_views_delete_admin
on public.internship_views
for delete
to authenticated
using (is_admin());
