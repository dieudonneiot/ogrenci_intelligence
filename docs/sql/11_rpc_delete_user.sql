-- RPC: delete the current user and related data

create or replace function public.delete_user()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid;
  v_admin_id uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Admin cleanup
  select id into v_admin_id
  from public.admins
  where user_id = v_uid
  limit 1;

  if v_admin_id is not null then
    update public.companies
    set approved_by = null
    where approved_by = v_admin_id;

    delete from public.admin_logs where admin_id = v_admin_id;
    delete from public.admins where id = v_admin_id;
  end if;

  -- Chat related
  delete from public.chatbot_feedback where user_id = v_uid;
  delete from public.chat_messages where user_id = v_uid;
  delete from public.chat_sessions where user_id = v_uid;

  -- Preferences and notifications
  delete from public.notification_preferences where user_id = v_uid;
  delete from public.notifications where user_id = v_uid;

  -- Courses and favorites
  delete from public.course_reviews where user_id = v_uid;
  delete from public.course_enrollments where user_id = v_uid;
  delete from public.completed_courses where user_id = v_uid;
  delete from public.favorites where user_id = v_uid;

  -- Applications and views
  delete from public.job_applications where user_id = v_uid;
  delete from public.intern_evaluations
  where internship_application_id in (
    select id from public.internship_applications where user_id = v_uid
  );
  delete from public.internship_applications where user_id = v_uid;
  delete from public.job_views where user_id = v_uid;
  delete from public.internship_views where user_id = v_uid;

  -- Points and badges
  delete from public.activity_logs where user_id = v_uid;
  delete from public.user_points where user_id = v_uid;
  delete from public.user_badges where user_id = v_uid;
  delete from public.leaderboard_snapshots where user_id = v_uid;

  -- Ratings / evaluations
  delete from public.employer_ratings where employer_id = v_uid or student_id = v_uid;
  delete from public.intern_evaluations where evaluated_by = v_uid;

  -- Company notes tied to this company user
  delete from public.application_notes
  where company_user_id in (
    select id from public.company_users where user_id = v_uid
  );

  -- Company membership and invite references
  update public.company_users
  set invited_by = null
  where invited_by = v_uid;

  delete from public.company_users where user_id = v_uid;

  -- Remove created_by references when possible
  update public.jobs set created_by = null where created_by = v_uid;
  update public.internships set created_by = null where created_by = v_uid;
  delete from public.job_templates where created_by = v_uid;

  -- Profile
  delete from public.profiles where id = v_uid;

  -- Finally delete auth user
  delete from auth.users where id = v_uid;
end;
$$;

grant execute on function public.delete_user() to authenticated;
