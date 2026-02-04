-- RLS policies for employer ratings, intern evaluations, and application notes

alter table public.employer_ratings enable row level security;

drop policy if exists employer_ratings_select_scope on public.employer_ratings;
create policy employer_ratings_select_scope
on public.employer_ratings
for select
to authenticated
using (
  employer_id = auth.uid()
  or student_id = auth.uid()
  or is_admin()
);

drop policy if exists employer_ratings_insert_student on public.employer_ratings;
create policy employer_ratings_insert_student
on public.employer_ratings
for insert
to authenticated
with check (student_id = auth.uid() or is_admin());

drop policy if exists employer_ratings_update_student on public.employer_ratings;
create policy employer_ratings_update_student
on public.employer_ratings
for update
to authenticated
using (student_id = auth.uid() or is_admin())
with check (student_id = auth.uid() or is_admin());

drop policy if exists employer_ratings_delete_student on public.employer_ratings;
create policy employer_ratings_delete_student
on public.employer_ratings
for delete
to authenticated
using (student_id = auth.uid() or is_admin());

alter table public.intern_evaluations enable row level security;

drop policy if exists intern_evaluations_select_scope on public.intern_evaluations;
create policy intern_evaluations_select_scope
on public.intern_evaluations
for select
to authenticated
using (
  is_admin()
  or is_company_staff(company_id)
  or exists (
    select 1
    from public.internship_applications ia
    where ia.id = internship_application_id
      and ia.user_id = auth.uid()
  )
);

drop policy if exists intern_evaluations_insert_company on public.intern_evaluations;
create policy intern_evaluations_insert_company
on public.intern_evaluations
for insert
to authenticated
with check (is_company_staff(company_id) or is_admin());

drop policy if exists intern_evaluations_update_company on public.intern_evaluations;
create policy intern_evaluations_update_company
on public.intern_evaluations
for update
to authenticated
using (is_company_staff(company_id) or is_admin())
with check (is_company_staff(company_id) or is_admin());

drop policy if exists intern_evaluations_delete_company on public.intern_evaluations;
create policy intern_evaluations_delete_company
on public.intern_evaluations
for delete
to authenticated
using (is_company_staff(company_id) or is_admin());

alter table public.application_notes enable row level security;

drop policy if exists application_notes_select_company on public.application_notes;
create policy application_notes_select_company
on public.application_notes
for select
to authenticated
using (
  is_admin()
  or exists (
    select 1
    from public.job_applications ja
    join public.jobs j on j.id = ja.job_id
    where application_type = 'job'
      and ja.id = application_id
      and is_company_staff(j.company_id)
  )
  or exists (
    select 1
    from public.internship_applications ia
    join public.internships i on i.id = ia.internship_id
    where application_type = 'internship'
      and ia.id = application_id
      and is_company_staff(i.company_id)
  )
);

drop policy if exists application_notes_insert_company on public.application_notes;
create policy application_notes_insert_company
on public.application_notes
for insert
to authenticated
with check (
  is_admin()
  or (
    exists (
      select 1
      from public.company_users cu
      where cu.id = company_user_id
        and cu.user_id = auth.uid()
    )
    and (
      exists (
        select 1
        from public.job_applications ja
        join public.jobs j on j.id = ja.job_id
        where application_type = 'job'
          and ja.id = application_id
          and is_company_staff(j.company_id)
      )
      or exists (
        select 1
        from public.internship_applications ia
        join public.internships i on i.id = ia.internship_id
        where application_type = 'internship'
          and ia.id = application_id
          and is_company_staff(i.company_id)
      )
    )
  )
);

drop policy if exists application_notes_update_company on public.application_notes;
create policy application_notes_update_company
on public.application_notes
for update
to authenticated
using (
  is_admin()
  or exists (
    select 1
    from public.job_applications ja
    join public.jobs j on j.id = ja.job_id
    where application_type = 'job'
      and ja.id = application_id
      and is_company_staff(j.company_id)
  )
  or exists (
    select 1
    from public.internship_applications ia
    join public.internships i on i.id = ia.internship_id
    where application_type = 'internship'
      and ia.id = application_id
      and is_company_staff(i.company_id)
  )
)
with check (
  is_admin()
  or exists (
    select 1
    from public.job_applications ja
    join public.jobs j on j.id = ja.job_id
    where application_type = 'job'
      and ja.id = application_id
      and is_company_staff(j.company_id)
  )
  or exists (
    select 1
    from public.internship_applications ia
    join public.internships i on i.id = ia.internship_id
    where application_type = 'internship'
      and ia.id = application_id
      and is_company_staff(i.company_id)
  )
);

drop policy if exists application_notes_delete_company on public.application_notes;
create policy application_notes_delete_company
on public.application_notes
for delete
to authenticated
using (
  is_admin()
  or exists (
    select 1
    from public.job_applications ja
    join public.jobs j on j.id = ja.job_id
    where application_type = 'job'
      and ja.id = application_id
      and is_company_staff(j.company_id)
  )
  or exists (
    select 1
    from public.internship_applications ia
    join public.internships i on i.id = ia.internship_id
    where application_type = 'internship'
      and ia.id = application_id
      and is_company_staff(i.company_id)
  )
);
