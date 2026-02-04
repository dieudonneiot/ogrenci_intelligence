-- Talent Mining (company)
-- Provides a secure RPC to query student profiles + OI score + badges (user_badges is "own only" under RLS).
-- Depends on: profiles, oi_scores (view), user_badges, helpers (is_company_staff, is_admin).

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
      array_agg(distinct ub.title order by ub.title) as badges
    from public.user_badges ub
    group by ub.user_id
  )
  select
    p.id as user_id,
    p.full_name,
    p.email,
    p.avatar_url,
    p.department,
    p.year,
    coalesce(s.oi_score, 0) as oi_score,
    coalesce(b.badges, '{}'::text[]) as badges
  from public.profiles p
  left join public.oi_scores s on s.user_id = p.id
  left join badge_agg b on b.user_id = p.id
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

