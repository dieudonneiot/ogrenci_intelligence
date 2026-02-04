-- RPC helpers for secure existence checks

create or replace function public.admin_exists()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (select 1 from public.admins);
$$;

grant execute on function public.admin_exists() to anon, authenticated;

create or replace function public.company_tax_exists(p_tax text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.companies
    where tax_number = nullif(trim(p_tax), '')
  );
$$;

grant execute on function public.company_tax_exists(text) to anon, authenticated;
