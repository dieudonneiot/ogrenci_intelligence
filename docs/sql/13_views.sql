-- Views used by the app

create or replace view public.department_leaderboard as
select
  p.id as user_id,
  p.department,
  p.total_points,
  dense_rank() over (
    partition by p.department
    order by p.total_points desc nulls last
  ) as rank_in_department
from public.profiles p
where p.department is not null
  and btrim(p.department) <> '';

grant select on public.department_leaderboard to authenticated;
