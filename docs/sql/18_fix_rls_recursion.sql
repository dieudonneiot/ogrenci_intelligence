-- Hotfix for "infinite recursion detected in policy" (42P17)
--
-- If you already ran an older version of docs/sql/03_rls_jobs_internships.sql,
-- run this once to remove the recursive policies.

drop policy if exists jobs_select_applicant on public.jobs;
drop policy if exists internships_select_applicant on public.internships;

