-- RPC: add activity + points in one transaction

create or replace function public.add_activity_and_points(
  p_user_id uuid,
  p_category text,
  p_action text,
  p_points integer,
  p_description text default null,
  p_metadata jsonb default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_category text;
  v_action text;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_user_id is null then
    raise exception 'User id is required';
  end if;

  if v_uid <> p_user_id and not is_admin() then
    raise exception 'Not authorized';
  end if;

  v_category := nullif(trim(coalesce(p_category, '')),'');
  if v_category is null then
    v_category := 'platform';
  end if;

  v_action := nullif(trim(coalesce(p_action, '')),'');
  if v_action is null then
    v_action := 'activity';
  end if;

  -- Ensure profile exists
  insert into public.profiles (id, total_points)
  values (p_user_id, 0)
  on conflict (id) do nothing;

  insert into public.activity_logs (
    user_id,
    category,
    action,
    points,
    metadata
  ) values (
    p_user_id,
    v_category,
    v_action,
    p_points,
    p_metadata
  );

  insert into public.user_points (
    user_id,
    source,
    description,
    points
  ) values (
    p_user_id,
    v_category,
    p_description,
    p_points
  );

  update public.profiles
  set total_points = coalesce(total_points, 0) + p_points,
      updated_at = timezone('utc', now())
  where id = p_user_id;
end;
$$;

grant execute on function public.add_activity_and_points(uuid, text, text, integer, text, jsonb) to authenticated;
