-- RLS policies for courses and enrollments

alter table public.courses enable row level security;

drop policy if exists courses_select_authenticated on public.courses;
create policy courses_select_authenticated
on public.courses
for select
to authenticated
using (true);

drop policy if exists courses_insert_admin on public.courses;
create policy courses_insert_admin
on public.courses
for insert
to authenticated
with check (is_admin());

drop policy if exists courses_update_admin on public.courses;
create policy courses_update_admin
on public.courses
for update
to authenticated
using (is_admin())
with check (is_admin());

drop policy if exists courses_delete_admin on public.courses;
create policy courses_delete_admin
on public.courses
for delete
to authenticated
using (is_admin());

alter table public.course_enrollments enable row level security;

drop policy if exists course_enrollments_select_own on public.course_enrollments;
create policy course_enrollments_select_own
on public.course_enrollments
for select
to authenticated
using (user_id = auth.uid() or is_admin());

drop policy if exists course_enrollments_insert_own on public.course_enrollments;
create policy course_enrollments_insert_own
on public.course_enrollments
for insert
to authenticated
with check (user_id = auth.uid() or is_admin());

drop policy if exists course_enrollments_update_own on public.course_enrollments;
create policy course_enrollments_update_own
on public.course_enrollments
for update
to authenticated
using (user_id = auth.uid() or is_admin())
with check (user_id = auth.uid() or is_admin());

drop policy if exists course_enrollments_delete_own on public.course_enrollments;
create policy course_enrollments_delete_own
on public.course_enrollments
for delete
to authenticated
using (user_id = auth.uid() or is_admin());

alter table public.completed_courses enable row level security;

drop policy if exists completed_courses_select_own on public.completed_courses;
create policy completed_courses_select_own
on public.completed_courses
for select
to authenticated
using (user_id = auth.uid() or is_admin());

drop policy if exists completed_courses_insert_own on public.completed_courses;
create policy completed_courses_insert_own
on public.completed_courses
for insert
to authenticated
with check (user_id = auth.uid() or is_admin());

drop policy if exists completed_courses_delete_own on public.completed_courses;
create policy completed_courses_delete_own
on public.completed_courses
for delete
to authenticated
using (user_id = auth.uid() or is_admin());

alter table public.course_reviews enable row level security;

drop policy if exists course_reviews_select_authenticated on public.course_reviews;
create policy course_reviews_select_authenticated
on public.course_reviews
for select
to authenticated
using (true);

drop policy if exists course_reviews_insert_own on public.course_reviews;
create policy course_reviews_insert_own
on public.course_reviews
for insert
to authenticated
with check (user_id = auth.uid() or is_admin());

drop policy if exists course_reviews_update_own on public.course_reviews;
create policy course_reviews_update_own
on public.course_reviews
for update
to authenticated
using (user_id = auth.uid() or is_admin())
with check (user_id = auth.uid() or is_admin());

drop policy if exists course_reviews_delete_own on public.course_reviews;
create policy course_reviews_delete_own
on public.course_reviews
for delete
to authenticated
using (user_id = auth.uid() or is_admin());
