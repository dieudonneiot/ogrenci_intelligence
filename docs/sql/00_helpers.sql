-- Helper functions for RLS policies
-- Run this first.

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.admins a
    where a.user_id = auth.uid()
      and a.is_active = true
  );
$$;

create or replace function public.is_company_member(p_company_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.company_users cu
    where cu.company_id = p_company_id
      and cu.user_id = auth.uid()
  );
$$;

create or replace function public.is_company_staff(p_company_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.company_users cu
    where cu.company_id = p_company_id
      and cu.user_id = auth.uid()
      and cu.role in ('owner', 'admin', 'hr')
  );
$$;

grant execute on function public.is_admin() to anon, authenticated;
grant execute on function public.is_company_member(uuid) to anon, authenticated;
grant execute on function public.is_company_staff(uuid) to anon, authenticated;
