-- Talent Mining (company)
-- Provides a secure RPC to query student profiles + OI score + performance signals for hiring decisions.
-- Depends on:
-- - profiles, oi_scores (view), user_badges
-- - case_responses (reaction signal)
-- - focus_checks, focus_responses (speed + reliability signal)
-- - completed_courses, course_quiz_attempts (knowledge signal)
-- - helpers (is_company_staff, is_admin).

-- NOTE: Postgres cannot change a function's OUT/return columns via CREATE OR REPLACE.
-- If you previously deployed an older version of this RPC, you must drop it first.
drop function if exists public.company_list_talent_pool(
  uuid,
  text,
  integer,
  integer,
  text[],
  integer,
  integer
);

create or replace function public.company_list_talent_pool(
  p_company_id uuid,
  p_department text default null,
  p_min_score integer default 0,
  p_max_score integer default 100,
  p_badges text[] default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  user_id uuid,
  full_name text,
  email text,
  avatar_url text,
  department text,
  year integer,
  oi_score integer,
  technical integer,
  social integer,
  field_fit integer,
  consistency integer,
  total_points integer,
  cases_solved integer,
  cases_left integer,
  cases_right integer,
  focus_submitted integer,
  focus_expired integer,
  focus_avg_seconds_to_answer integer,
  nano_courses_completed integer,
  nano_quiz_attempts integer,
  nano_quiz_correct integer,
  nano_quiz_points integer,
  badges text[]
)
language sql
stable
security definer
set search_path = public
as $$
  with badge_agg as (
    select
      ub.user_id,
      array_agg(distinct ub.badge_title order by ub.badge_title) as badges
    from public.user_badges ub
    group by ub.user_id
  ),
  case_agg as (
    select
      cr.user_id,
      count(*)::int as cases_solved,
      count(*) filter (where cr.choice = 'left')::int as cases_left,
      count(*) filter (where cr.choice = 'right')::int as cases_right
    from public.case_responses cr
    group by cr.user_id
  ),
  focus_agg as (
    select
      fc.user_id,
      count(*) filter (where fc.status = 'submitted')::int as focus_submitted,
      count(*) filter (where fc.status = 'expired')::int as focus_expired,
      coalesce(
        round(
          avg(
            extract(
              epoch
              from (
                fr.submitted_at
                - coalesce(fc.started_at, fc.sent_at, fc.created_at)
              )
            )
          )
        )::int,
        0
      ) as focus_avg_seconds_to_answer
    from public.focus_checks fc
    left join public.focus_responses fr on fr.focus_check_id = fc.id
    group by fc.user_id
  ),
  nano_completed as (
    select
      cc.user_id,
      count(*)::int as nano_courses_completed
    from public.completed_courses cc
    group by cc.user_id
  ),
  nano_quiz as (
    select
      a.user_id,
      count(*)::int as nano_quiz_attempts,
      count(*) filter (where a.is_correct)::int as nano_quiz_correct,
      coalesce(sum(a.points_awarded), 0)::int as nano_quiz_points
    from public.course_quiz_attempts a
    group by a.user_id
  )
  select
    p.id as user_id,
    p.full_name,
    p.email,
    p.avatar_url,
    p.department,
    p.year,
    coalesce(s.oi_score, 0) as oi_score,
    coalesce(s.technical, 0) as technical,
    coalesce(s.social, 0) as social,
    coalesce(s.field_fit, 0) as field_fit,
    coalesce(s.consistency, 0) as consistency,
    coalesce(p.total_points, 0) as total_points,
    coalesce(ca.cases_solved, 0) as cases_solved,
    coalesce(ca.cases_left, 0) as cases_left,
    coalesce(ca.cases_right, 0) as cases_right,
    coalesce(fa.focus_submitted, 0) as focus_submitted,
    coalesce(fa.focus_expired, 0) as focus_expired,
    coalesce(fa.focus_avg_seconds_to_answer, 0) as focus_avg_seconds_to_answer,
    coalesce(nc.nano_courses_completed, 0) as nano_courses_completed,
    coalesce(nq.nano_quiz_attempts, 0) as nano_quiz_attempts,
    coalesce(nq.nano_quiz_correct, 0) as nano_quiz_correct,
    coalesce(nq.nano_quiz_points, 0) as nano_quiz_points,
    coalesce(b.badges, '{}'::text[]) as badges
  from public.profiles p
  left join public.oi_scores s on s.user_id = p.id
  left join badge_agg b on b.user_id = p.id
  left join case_agg ca on ca.user_id = p.id
  left join focus_agg fa on fa.user_id = p.id
  left join nano_completed nc on nc.user_id = p.id
  left join nano_quiz nq on nq.user_id = p.id
  where
    (is_company_staff(p_company_id) or is_admin())
    and (p_department is null or (p.department is not null and lower(p.department) = lower(p_department)))
    and coalesce(s.oi_score, 0) between least(p_min_score, p_max_score) and greatest(p_min_score, p_max_score)
    and (
      p_badges is null
      or cardinality(p_badges) = 0
      or (coalesce(b.badges, '{}'::text[]) && p_badges)
    )
  order by coalesce(s.oi_score, 0) desc, p.updated_at desc
  limit greatest(p_limit, 1)
  offset greatest(p_offset, 0);
$$;

grant execute on function public.company_list_talent_pool(uuid, text, integer, integer, text[], integer, integer) to authenticated;
