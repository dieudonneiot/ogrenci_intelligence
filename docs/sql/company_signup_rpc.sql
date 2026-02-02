-- Company signup RPC (Supabase)
-- Creates companies + company_users in a single transaction using auth.uid()
-- Requires metadata to be present on auth.users:
-- user_type=company, company_name, company_sector, company_city, company_tax_number, company_phone, company_address

create or replace function public.create_company_for_current_user()
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid;
  v_company_id uuid;
  v_meta jsonb;
  v_email text;
  v_name text;
  v_sector text;
  v_city text;
  v_tax text;
  v_phone text;
  v_address text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select raw_user_meta_data, email
  into v_meta, v_email
  from auth.users
  where id = v_user_id;

  if v_meta is null or (v_meta->>'user_type') <> 'company' then
    raise exception 'Not a company user';
  end if;

  select company_id
  into v_company_id
  from public.company_users
  where user_id = v_user_id
  limit 1;

  if v_company_id is not null then
    return v_company_id;
  end if;

  v_name := nullif(trim(v_meta->>'company_name'), '');
  v_sector := nullif(trim(v_meta->>'company_sector'), '');
  v_city := nullif(trim(v_meta->>'company_city'), '');
  v_tax := nullif(trim(v_meta->>'company_tax_number'), '');
  v_phone := nullif(trim(v_meta->>'company_phone'), '');
  v_address := nullif(trim(v_meta->>'company_address'), '');

  if v_name is null or v_sector is null or v_city is null or v_tax is null or v_phone is null then
    raise exception 'Missing company metadata';
  end if;

  insert into public.companies (
    name,
    sector,
    tax_number,
    phone,
    city,
    address,
    email,
    verified,
    created_at,
    updated_at
  ) values (
    v_name,
    v_sector,
    v_tax,
    v_phone,
    v_city,
    v_address,
    v_email,
    false,
    timezone('utc', now()),
    timezone('utc', now())
  )
  returning id into v_company_id;

  insert into public.company_users (
    company_id,
    user_id,
    role,
    created_at
  ) values (
    v_company_id,
    v_user_id,
    'owner',
    timezone('utc', now())
  );

  return v_company_id;
end;
$$;

grant execute on function public.create_company_for_current_user() to authenticated;
